# -*- coding: utf-8 -*-
"""Python mirror of lib/core/liturgical/ — used to verify the engine against
published calendars and to write the golden test vectors that the Dart engine
and the website's TypeScript port are both tested against.

Keep the three in step. The golden file (test/golden/engine-2026-2030.json) is
what keeps them honest: if one of them changes a rule and the others don't,
its tests fail.

Fast levels, from most to least permissive: none, fish, wineOil, fast, strict.
There is no dairy level: Săptămâna Brânzei is shown as a week without fast.
"""
from datetime import date, timedelta

RANK_WEIGHT = {'praznic': 3, 'cruce_rosie': 2, 'cruce_albastra': 1, 'simplu': 0}
ORDER = ['none', 'fish', 'wineOil', 'fast', 'strict']
CROSS = ('cruce_albastra', 'cruce_rosie')

# Days from Pascha. Same keys as FeastCalendar._movable in Dart.
MOVABLE = {
    'lazarus_saturday': -8, 'palm_sunday': -7, 'theodore_saturday': -43,
    'pascha': 0, 'bright_friday': 5, 'ascension': 39, 'pentecost': 49,
    'pentecost_monday': 50, 'all_saints': 56, 'orthodoxy_sunday': -42,
    'thomas_sunday': 7, 'myrrhbearers': 14, 'romanian_saints': 63,
}

# Shorter than this, the Apostles' fast starts on the Tuesday after Rusalii.
MIN_APOSTLES_DAYS = 7


def looser(a, b):
    return a if ORDER.index(a) <= ORDER.index(b) else b


def stricter(a, b):
    return a if ORDER.index(a) >= ORDER.index(b) else b


def pascha(y):
    a, b, c = y % 4, y % 7, y % 19
    d = (19 * c + 15) % 30
    e = (2 * a + 4 * b - d + 34) % 7
    m = (d + e + 114) // 31
    dd = ((d + e + 114) % 31) + 1
    return date(y, m, dd) + timedelta(days=13 if y < 2100 else 14)


def _off(d, n):
    return d + timedelta(days=n)


def postul_apostolilor(y):
    """(start, end) or None. In late-Pascha years the Monday after All Saints
    leaves less than a week before 28 June; the fast then starts on the Tuesday
    after Rusalii (2027: 22–28 June, as published)."""
    p = pascha(y)
    start, end = _off(p, 57), date(y, 6, 28)
    if (end - start).days + 1 < MIN_APOSTLES_DAYS:
        start = _off(p, 51)
    return (start, end) if start <= end else None


def great_fasts(y):
    p = pascha(y)
    out = [('postulMare', _off(p, -48), _off(p, -1)),
           ('postulAdormirii', date(y, 8, 1), date(y, 8, 14)),
           ('postulCraciunului', date(y, 11, 15), date(y, 12, 24))]
    ap = postul_apostolilor(y)
    if ap:
        out.append(('postulApostolilor', ap[0], ap[1]))
    return sorted(out, key=lambda t: t[1])


def harti(y):
    p = pascha(y)
    after_rusalii_end = _off(p, 56)
    ap = postul_apostolilor(y)
    if ap and ap[0] <= after_rusalii_end:
        after_rusalii_end = _off(ap[0], -1)
    return [(date(y, 12, 25), date(y + 1, 1, 4)),
            (_off(p, -69), _off(p, -64)),
            (p, _off(p, 6)),
            (_off(p, 50), after_rusalii_end)]


def branza(y):
    p = pascha(y)
    return (_off(p, -55), _off(p, -49))


def _level_in_great_fast(d, kind, rank):
    p = pascha(d.year)
    wd = d.weekday()            # 0 = Monday … 6 = Sunday
    weekend = wd >= 5
    wed_fri = wd in (2, 4)
    tue_thu = wd in (1, 3)
    cross = rank in CROSS

    if kind == 'postulMare':
        if d in (_off(p, -48), _off(p, -47)):
            return 'strict', 'Primele zile ale Postului Mare.'
        if d == _off(p, -2):
            return 'strict', 'Vinerea Mare.'
        if _off(p, -6) <= d <= _off(p, -4):
            return 'strict', 'Săptămâna Patimilor.'
        if (d.month, d.day) == (3, 25):
            return 'fish', 'Buna Vestire.'
        if d == _off(p, -7):
            return 'fish', 'Duminica Floriilor.'
        if d == _off(p, -8):
            return 'wineOil', 'Sâmbăta lui Lazăr — dezlegare la icre.'
        if d == _off(p, -3):
            return 'wineOil', 'Joia Mare.'
        if d == _off(p, -17):
            return 'wineOil', 'Joia Canonului cel Mare.'
        if (d.month, d.day) in ((3, 24), (3, 26)) and not weekend and not wed_fri:
            return 'wineOil', None
        if cross and not weekend:
            return 'wineOil', None
        return ('wineOil' if weekend else 'fast'), None

    if kind == 'postulAdormirii':
        if (d.month, d.day) == (8, 6):
            return 'fish', 'Schimbarea la Față.'
        return ('wineOil' if weekend else 'fast'), None

    if kind == 'postulApostolilor':
        if wed_fri:
            if rank == 'praznic':
                return 'fish', None
            return ('wineOil' if cross else 'fast'), None
        if cross or rank == 'praznic':
            return 'fish', None
        return ('wineOil' if tue_thu else 'fish'), None

    if kind == 'postulCraciunului':
        if (d.month, d.day) == (12, 24):
            return 'strict', 'Ajunul Nașterii Domnului.'
        if (d.month, d.day) == (11, 21):
            return 'fish', 'Intrarea în Biserică a Maicii Domnului.'
        if (d.month, d.day) == (11, 30):
            return 'fish', 'Sfântul Apostol Andrei.'
        if (d.month, d.day) == (12, 6):
            return 'fish', 'Sfântul Ierarh Nicolae.'
        if (d.month == 11 and d.day < 21) or (d.month == 12 and d.day > 20):
            return ('wineOil' if weekend else 'fast'), None
        if weekend:
            return 'fish', None
        if wed_fri:
            return ('wineOil' if cross else 'fast'), None
        if cross:
            return 'fish', None
        return ('wineOil' if tue_thu else 'fast'), None

    return 'fast', None


def _level_outside_fasts(d, rank):
    if d.weekday() not in (2, 4):
        return 'none'
    p = pascha(d.year)
    if _off(p, 8) <= d <= _off(p, 48):
        return 'fish'
    return {'praznic': 'fish', 'cruce_rosie': 'wineOil'}.get(rank, 'fast')


def _fixed(d):
    """Fixed days that override whatever the surrounding rule produced."""
    md = (d.month, d.day)
    if md == (1, 5):
        return 'strict', 'Ajunul Bobotezei.'
    if md == (1, 6):
        return 'none', 'Botezul Domnului.'
    if md == (8, 29):
        return 'wineOil', 'Tăierea Capului Sfântului Ioan Botezătorul.'
    if md == (9, 14):
        return 'wineOil', 'Înălțarea Sfintei Cruci.'
    return None


def day_for(d, rank='simplu', dezlegare=None):
    """dict(fastLevel, period, note, glas, voscreasna) for date [d]."""
    level, note, period = None, None, None

    for yy in (d.year - 1, d.year):
        for s, e in harti(yy):
            if s <= d <= e:
                period, level = 'harti', 'none'
    if level is None:
        bs, be = branza(d.year)
        if bs <= d <= be:
            period, level = 'saptamanaBranzei', 'none'
    if level is None:
        for kind, s, e in great_fasts(d.year):
            if s <= d <= e:
                period = kind
                level, note = _level_in_great_fast(d, kind, rank)
                break
    if level is None:
        level = _level_outside_fasts(d, rank)

    if dezlegare in ORDER and level != 'none':
        level = looser(level, dezlegare)

    fixed = _fixed(d)
    if fixed:
        level = stricter(level, 'strict') if fixed[0] == 'strict' else fixed[0]
        note = fixed[1]

    return {'fastLevel': level, 'period': period, 'note': note,
            'glas': glas_for(d), 'voscreasna': voscreasna_for(d)}


def fast_level_for(year, month, day, rank='simplu', dezlegare=None):
    return day_for(date(year, month, day), rank, dezlegare)['fastLevel']


def _weeks_since_thomas(d):
    anchor = pascha(d.year) + timedelta(days=7)
    if d < anchor:
        anchor = pascha(d.year - 1) + timedelta(days=7)
    weeks = (d - anchor).days // 7
    return weeks if weeks >= 0 else None


def glas_for(d):
    w = _weeks_since_thomas(d)
    return (w % 8) + 1 if w is not None else None


def voscreasna_for(d):
    w = _weeks_since_thomas(d)
    return ((w + 4) % 11) + 1 if w is not None else None


# --------------------------------------------------------------- weddings
#
# When the Church does not celebrate the Taina Cununiei. Checked against the
# published 2027 calendar ("Nu se fac nunți"): 363 of 365 days identical, and
# the two others are errors in the source (a note lost on 24 Dec, page script
# in the note of 30 Sep). Same rules in liturgical_calendar.dart (cununie) and
# troita-web's liturgical.ts (cununie). A civil wedding is not affected.

# Fixed feasts whose eve and day have no weddings, as (month, day).
_NO_WEDDING_DAYS = {
    (2, 1), (2, 2),      # Întâmpinarea Domnului
    (3, 24), (3, 25),    # Buna Vestire
    (8, 15),             # Adormirea (its eve is in the Dormition fast)
    (8, 29),             # Tăierea capului Sf. Ioan
    (9, 7), (9, 8),      # Nașterea Maicii Domnului
    (9, 14),             # Înălțarea Sfintei Cruci
    (11, 20), (11, 21),  # Intrarea în Biserică (inside the Nativity fast)
}

WEDDING_REASONS = ('post', 'saptamanaBranzei', 'craciunBoboteaza',
                   'saptamanaLuminata', 'praznic', 'miercuriVineri')


def cununie(d):
    """None when weddings are celebrated that day, else the reason they are not."""
    y = d.year
    p = pascha(y)
    for _, s, e in great_fasts(y):
        if s <= d <= e:
            return 'post'
    bs, be = branza(y)
    if bs <= d <= be:
        return 'saptamanaBranzei'
    if d <= date(y, 1, 6) or d >= date(y, 12, 25):
        return 'craciunBoboteaza'
    if p <= d <= _off(p, 6):
        return 'saptamanaLuminata'
    if (d.month, d.day) in _NO_WEDDING_DAYS:
        return 'praznic'
    # Înălțarea and Rusaliile with their eves, and the Monday of Rusalii.
    if d in (_off(p, 38), _off(p, 39), _off(p, 48), _off(p, 49), _off(p, 50)):
        return 'praznic'
    if d.weekday() in (2, 4):
        in_harti = any(s <= d <= e for yy in (y - 1, y) for s, e in harti(yy))
        if not in_harti:
            return 'miercuriVineri'
    return None
