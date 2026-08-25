# -*- coding: utf-8 -*-
"""Parse a month of the published Romanian calendar HTML into structured data.

The markup encodes more than it looks. Rank lives in the dagger prefix, not in
the row class:

    (†) ...   praznic împărătesc        e.g. Botezul Domnului
    †) ...    cruce roșie               e.g. Sf. Cuv. Antonie cel Mare
    † ...     cruce neagră              e.g. Soborul Sf. Ioan Botezătorul
    (none)    simplu

Other signals:
    <span class="rom">   a Romanian saint — worth styling differently
    <i>...</i>           înainte-prăznuire / odovanie
    <span class="comentariu">(Post)</span>   the day's fasting note
    <tr class="duminica">                    Sunday: title, pericopes, glas, voscreasnă

Usage:
    python3 import_calendar_html.py raw/2026-01.html --year 2026 --month 1
    python3 import_calendar_html.py raw/2026-01.html --year 2026 --month 1 --verify
    python3 import_calendar_html.py raw/*.html --emit-menologion > menologion_new.py
"""
from __future__ import annotations

import argparse
import glob
import html
import json
import re
import sys

ROW_RE = re.compile(
    r'<tr class="(?P<cls>[^"]*)">\s*'
    r'<td class="ziua">(?P<day>\d+)\s*</td>\s*'
    r'<td class="sapt">(?P<wd>\w)\s*</td>\s*'
    r'<td>(?P<body>.*?)</td>\s*</tr>',
    re.S,
)
SUNDAY_RE = re.compile(
    r'<tr class="duminica">\s*<td colspan="3">(?P<body>.*?)</td>\s*</tr>', re.S
)
COMMENT_RE = re.compile(r'<span class="comentariu">\((?P<text>[^)]*)\)</span>')
ROM_RE = re.compile(r'<span class="rom">(?P<text>.*?)</span>', re.S)
ITALIC_RE = re.compile(r'<i>(?P<text>.*?)</i>', re.S)
TAG_RE = re.compile(r'<[^>]+>')

FAST_FROM_COMMENT = {
    'post negru': 'strict',
    'post': 'fast',
    'harți': 'none',
    'harti': 'none',
    'dezlegare la pește': 'fish',
    'dezlegare la peste': 'fish',
    'dezlegare la ulei și vin': 'wineOil',
    'dezlegare la ulei si vin': 'wineOil',
    'dezlegare la untdelemn și vin': 'wineOil',
    'dezlegare la vin și untdelemn': 'wineOil',
}


def clean(fragment: str) -> str:
    text = TAG_RE.sub('', fragment)
    text = html.unescape(text)
    return re.sub(r'\s+', ' ', text).strip().strip(';').strip()


def rank_of(name: str) -> str:
    """Rank from the dagger prefix. Order matters — (†) before †) before †."""
    stripped = name.lstrip()
    if stripped.startswith('(†)'):
        return 'praznic'
    if stripped.startswith('†)'):
        return 'cruce_rosie'
    if stripped.startswith('†'):
        return 'cruce_neagra'
    return 'simplu'


def strip_daggers(name: str) -> str:
    return re.sub(r'^\s*(\(†\)|†\)|†)\s*', '', name).strip()


def parse_month(source: str, year: int, month: int) -> list[dict]:
    days: list[dict] = []

    for m in ROW_RE.finditer(source):
        body = m.group('body')
        comments = [c.group('text').strip() for c in COMMENT_RE.finditer(body)]
        romanian = [clean(r.group('text')) for r in ROM_RE.finditer(body)]
        prefeast = [clean(i.group('text')) for i in ITALIC_RE.finditer(body)]

        # The commemoration text is the <a class="sinaxar"> content.
        anchor = re.search(r'<a class="sinaxar".*?>(.*?)</a>', body, re.S)
        raw_name = clean(anchor.group(1)) if anchor else clean(body)

        fast = None
        notes = []
        for c in comments:
            key = c.lower().strip()
            if key in FAST_FROM_COMMENT:
                fast = FAST_FROM_COMMENT[key]
            else:
                notes.append(c)

        days.append({
            'month_day': f'{month:02d}-{int(m.group("day")):02d}',
            'weekday': m.group('wd'),
            'row_class': m.group('cls'),
            'name': strip_daggers(raw_name),
            'rank': rank_of(raw_name),
            'romanian': romanian,
            'prefeast': prefeast,
            'fast': fast,
            'notes': notes,
        })

    # Sunday rows sit between day rows and carry the pericopes and the tone.
    sundays: list[dict] = []
    for m in SUNDAY_RE.finditer(source):
        body = m.group('body')
        title = re.search(r'<span class="title">(.*?)</span>', body, re.S)
        subtitle = re.search(r'<span class="subtitle">(.*?)</span>', body, re.S)
        tail = clean(re.sub(r'<span class="(title|subtitle)">.*?</span>', '', body, flags=re.S))
        glas = re.search(r'glas (\d+)', tail)
        voscr = re.search(r'voscr\.? (\d+)', tail)
        apostol = re.search(r'Ap\.\s*([^;]+);', tail)
        evanghelie = re.search(r'Ev\.\s*([^;]+);', tail)
        sundays.append({
            'title': clean(title.group(1)) if title else None,
            'subtitle': clean(subtitle.group(1)).strip('()') if subtitle else None,
            'apostol': apostol.group(1).strip() if apostol else None,
            'evanghelie': evanghelie.group(1).strip() if evanghelie else None,
            'glas': int(glas.group(1)) if glas else None,
            'voscreasna': int(voscr.group(1)) if voscr else None,
        })

    return [{'days': days, 'sundays': sundays}]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument('files', nargs='+')
    ap.add_argument('--year', type=int, required=True)
    ap.add_argument('--month', type=int)
    ap.add_argument('--verify', action='store_true',
                    help='diff the parsed fasting notes against our engine')
    ap.add_argument('--emit-menologion', action='store_true')
    args = ap.parse_args()

    all_days: list[dict] = []
    all_sundays: list[dict] = []
    for pattern in args.files:
        for path in sorted(glob.glob(pattern)):
            month = args.month
            if month is None:
                found = re.search(r'(\d{4})-(\d{2})', path)
                month = int(found.group(2)) if found else None
            if month is None:
                raise SystemExit(f'cannot infer month for {path}; pass --month')
            parsed = parse_month(open(path, encoding='utf-8').read(), args.year, month)[0]
            all_days += parsed['days']
            all_sundays += parsed['sundays']

    if args.emit_menologion:
        for d in all_days:
            print(f'    "{d["month_day"]}": "{d["name"]}",')
        return

    if args.verify:
        verify(all_days, all_sundays, args.year)
        return

    json.dump({'days': all_days, 'sundays': all_sundays},
              sys.stdout, ensure_ascii=False, indent=2)


def verify(days: list[dict], sundays: list[dict], year: int) -> None:
    """Compare the published fasting notes and tones against our own engine."""
    sys.path.insert(0, '.')
    from engine_port import fast_level_for, glas_for, voscreasna_for  # noqa

    # Feast-specific dezlegări live in the data, not the rules — load them so
    # the diff reflects what the app will actually show.
    overrides: dict[str, str] = {}
    try:
        curated = json.load(open('feasts.json', encoding='utf-8'))['feasts']
        for f in curated:
            if f.get('date') and f.get('dezlegare'):
                overrides[f['date']] = f['dezlegare']
    except OSError:
        pass

    ok = mismatch = unstated = 0
    print(f'{"zi":8} {"publicat":12} {"calculat":12}  stare')
    print('-' * 52)
    for d in days:
        month, day = (int(x) for x in d['month_day'].split('-'))
        ours = fast_level_for(year, month, day, d['rank'])
        override = overrides.get(d['month_day'])
        if override and ours not in ('none', 'strict'):
            order = ['none', 'dairy', 'fish', 'wineOil', 'fast', 'strict']
            ours = min(ours, override, key=order.index)
        theirs = d['fast']
        if theirs is None:
            # No note means no fast on that day in this calendar's convention.
            theirs = 'none' if ours == 'none' else None
        if theirs is None:
            unstated += 1
            state = 'nespecificat'
        elif theirs == ours:
            ok += 1
            state = 'OK'
        else:
            mismatch += 1
            state = '<-- DIFERIT'
        if state != 'OK':
            print(f'{d["month_day"]:8} {str(theirs):12} {ours:12}  {state}')
    print('-' * 52)
    print(f'potrivite: {ok}   diferite: {mismatch}   nespecificate: {unstated}')

    print()
    print('Duminici — glas și voscreasnă:')
    for s in sundays:
        if s['glas'] is None:
            continue
        print(f'  {s["title"]}: publicat glas {s["glas"]}, voscr. {s["voscreasna"]}')


if __name__ == '__main__':
    main()
