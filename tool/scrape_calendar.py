#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Scrape the Romanian Orthodox calendar into structured JSON.

Two sources, because they carry different things:

  resurse-ortodoxe.ro/calendar-ortodox-<luna>-<an>_text
      Year-specific: rank daggers, dezlegări, fasting-period markers, Sunday
      pericopes with glas and voscreasnă, moon phases, and the fasting icon
      filenames (post-N.png) that the app should mirror.

  calendar-ortodox.ro/luna/<luna>/<luna><DD>.htm
      Fixed-date: the full sinaxar text for each day, plus saint images. This
      is the upstream — resurse-ortodoxe.ro republishes it with attribution —
      so we go to the origin. 365 pages, not year-specific, fetched once.

Run it:
    python3 scrape_calendar.py --year 2026 --all
    python3 scrape_calendar.py --year 2026 --months          # month pages only
    python3 scrape_calendar.py --sinaxar                     # day pages only
    python3 scrape_calendar.py --icons                       # fasting icons

Everything is cached on disk and resumable. Re-running skips what it already
has, so an interrupted run costs nothing.
"""
from __future__ import annotations

import argparse
import html
import json
import os
import re
import sys
import time
from urllib.parse import urljoin

import requests

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, ".scrape-cache")
OUT = os.path.join(HERE, "scraped")

# User-Agent sent with every request.
#
# NO personal data here by default. A User-Agent goes into the access log of
# every server contacted, where you neither control it nor can delete it — so
# an email address in this string is published to third parties, permanently,
# every time the scraper runs.
#
# Some site operators do prefer a contact address so they can reach you instead
# of silently blocking. If you want to provide one, set it yourself:
#
#     TROITA_SCRAPER_CONTACT="you@example.com" python3 scrape_calendar.py --all
#
# That is your decision to make deliberately, not a default.
# _CONTACT = os.environ.get("TROITA_SCRAPER_CONTACT", "").strip()
UA = "Scoala/0.1 (Orthodox calendar; facultate)"

DELAY = 1.5  # seconds between requests

MONTHS = [
    "ianuarie", "februarie", "martie", "aprilie", "mai", "iunie",
    "iulie", "august", "septembrie", "octombrie", "noiembrie", "decembrie",
]
DAYS_IN = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]  # Feb 29 included

FAST_FROM_COMMENT = {
    "post negru": "strict",
    "post": "fast",
    "harți": "none",
    "harti": "none",
    "dezlegare la pește": "fish",
    "dezlegare la peste": "fish",
    "dezlegare la ulei și vin": "wineOil",
    "dezlegare la ulei si vin": "wineOil",
    "dezlegare la untdelemn și vin": "wineOil",
    "dezlegare la vin și untdelemn": "wineOil",
    "dezlegare la lactate": "dairy",
}


# --------------------------------------------------------------------- fetch
def fetch(url: str, *, binary: bool = False) -> bytes | str | None:
    """Cached GET. Returns None on failure rather than raising, so one dead
    page cannot abort a 365-page run."""
    key = re.sub(r"[^A-Za-z0-9._-]", "_", url)[-180:]
    path = os.path.join(CACHE, key)
    os.makedirs(CACHE, exist_ok=True)

    if os.path.exists(path):
        raw = open(path, "rb").read()
        return raw if binary else decode(raw)

    for attempt in range(3):
        try:
            r = requests.get(url, headers={"User-Agent": UA}, timeout=45)
            if r.status_code == 404:
                print(f"    404 {url}", file=sys.stderr)
                return None
            r.raise_for_status()
            open(path, "wb").write(r.content)
            time.sleep(DELAY)
            return r.content if binary else decode(r.content)
        except Exception as exc:  # noqa: BLE001
            print(f"    retry {attempt + 1}: {exc}", file=sys.stderr)
            time.sleep(3 * (attempt + 1))
    return None


def decode(raw: bytes) -> str:
    """calendar-ortodox.ro serves Central-European bytes with no charset, which
    is why the diacritics arrive as replacement characters if you trust the
    header. Try the encodings that actually occur, most likely first."""
    for enc in ("utf-8", "cp1250", "iso-8859-2", "cp1252"):
        try:
            text = raw.decode(enc)
            # A good decode has Romanian diacritics and no replacement chars.
            if "�" not in text:
                return text
        except UnicodeDecodeError:
            continue
    return raw.decode("utf-8", errors="replace")


def strip_tags(fragment: str) -> str:
    text = re.sub(r"<br\s*/?>", "\n", fragment)
    text = re.sub(r"</p\s*>", "\n\n", text)
    text = re.sub(r"<[^>]+>", "", text)
    text = html.unescape(text)
    text = re.sub(r"[ \t]+", " ", text)
    return re.sub(r"\n{3,}", "\n\n", text).strip()


# --------------------------------------------------------------- month pages
COMMENT_RE = re.compile(r"\(([^()]{2,80})\)")
ICON_RE = re.compile(r'src=["\']([^"\']*(?:post|luna)-\d+\.png)')
ANCHOR_RE = re.compile(r"<a[^>]*sinaxar[^>]*>(.*?)</a>", re.S | re.I)
ROM_RE = re.compile(r"<span class=['\"]rom['\"]>(.*?)</span>", re.S)


def rank_of(name: str, row_class: str = "") -> str:
    """Rank from the row class first, the dagger second.

    The daggers alone are misleading. `†)` appears on 61 days of 2026, but only
    28 of them are red-letter feasts — and those 28 are exactly the days the
    markup flags with class="sarbatoare": Sf. Vasile, Boboteaza, Trei Ierarhi,
    Buna Vestire, Sf. Gheorghe, Sf. Ilie, Adormirea, Sf. Parascheva, Sf.
    Dimitrie, Sf. Andrei, Crăciunul. That is the cruce roșie list.

    A `†)` on an ordinary row means cruce albastră (printed black by some
    publishers): an important saint, but not a day of obligatory rest. Reading
    it as red made 15–18 September look like four consecutive red-letter days,
    which no calendar shows.

    Sundays carry class="sarbatoare saptamana" whether or not the commemoration
    is a feast, so the class cannot be trusted there and the dagger decides.
    """
    text = name.lstrip()
    if text.startswith("(†)"):
        return "praznic"

    has_dagger = text.startswith("†")
    is_sunday = "saptamana" in row_class
    is_feast_row = row_class.strip() == "sarbatoare"

    if is_feast_row:
        return "cruce_rosie"
    if is_sunday:
        if text.startswith("†)"):
            return "cruce_rosie"
        return "cruce_albastra" if has_dagger else "simplu"
    return "cruce_albastra" if has_dagger else "simplu"


def scrape_month(year: int, month: int) -> dict:
    """Parse one month page.

    The markup does not close its <td> or <tr> tags — `<td class="ziua">1` with
    nothing after it. A regex that expects `</td>` matches zero rows and fails
    silently, which is exactly what happened the first time. So: split on the
    opening tags and never require a closing one.
    """
    url = (f"https://www.resurse-ortodoxe.ro/"
           f"calendar-ortodox-{MONTHS[month - 1]}-{year}_text")
    print(f"  {MONTHS[month - 1]} {year}", file=sys.stderr)
    page = fetch(url)
    if page is None:
        return {"days": [], "sundays": []}

    days, sundays = [], []

    for chunk in re.split(r"<tr\b", page)[1:]:
        klass = re.match(r'[^>]*class=[\'"]([^\'"]*)[\'"]', chunk)
        klass = klass.group(1) if klass else ""

        cells = [re.sub(r"^[^>]*>", "", c)
                 for c in re.split(r"<td\b", chunk)[1:]]

        # Sunday rows span all three columns and carry the pericopes.
        if "duminica" in klass and cells:
            text = strip_tags(cells[0])
            glas = re.search(r"glas (\d+)", text)
            voscr = re.search(r"voscr\.? (\d+)", text)
            ap = re.search(r"Ap\.\s*([^;]+);", text)
            ev = re.search(r"Ev\.\s*([^;]+);", text)
            title = re.match(r"(Duminica[^(;]*)", text)
            sub = re.search(r"\(([^)]+)\)", text)
            sundays.append({
                "title": title.group(1).strip() if title else None,
                "subtitle": sub.group(1).strip() if sub else None,
                "apostol": ap.group(1).strip() if ap else None,
                "evanghelie": ev.group(1).strip() if ev else None,
                "glas": int(glas.group(1)) if glas else None,
                "voscreasna": int(voscr.group(1)) if voscr else None,
            })
            continue

        if len(cells) < 3:
            continue
        day, weekday = strip_tags(cells[0]), strip_tags(cells[1])
        if not re.fullmatch(r"\d{1,2}", day):
            continue
        if not re.fullmatch(r"[LMJVSD]", weekday):
            continue

        body = cells[2]
        anchor = ANCHOR_RE.search(body)
        raw_name = strip_tags(anchor.group(1)) if anchor else strip_tags(body)

        # Comments sit after the link: (Post), (Dezlegare la pește), (Harți).
        tail = body[anchor.end():] if anchor else body
        fast, notes = None, []
        for c in COMMENT_RE.findall(strip_tags(tail)):
            key = c.lower().strip()
            if key in FAST_FROM_COMMENT:
                fast = FAST_FROM_COMMENT[key]
            else:
                notes.append(c.strip())

        days.append({
            "month_day": f"{month:02d}-{int(day):02d}",
            "weekday": weekday,
            "row_class": klass,
            "name": re.sub(r"^\s*(\(†\)|†\)|†)\s*", "", raw_name).strip(),
            "rank": rank_of(raw_name, klass),
            "fast": fast,
            "notes": notes,
            "romanian": [strip_tags(r) for r in ROM_RE.findall(body)],
            "icons": [i.split("/")[-1] for i in ICON_RE.findall(body)],
        })

    return {"days": days, "sundays": sundays}


# ----------------------------------------------------------- sinaxar (upstream)

# The "Sinaxar <d> <Luna>" heading that separates the site chrome from the
# actual life of the saint. Anchored to its own line, because in the body text
# the same words can appear inside a sentence.
SINAXAR_HEAD_RE = re.compile(r"^[ \t]*Sinaxar\s+\d{1,2}\s+\w+[ \t]*$", re.M)

# Longest run of site chrome measured across all 366 pages is well under this;
# a heading found later than this is almost certainly a false positive inside
# the text, so we leave the page alone rather than truncate a saint's life.
_MAX_CHROME = 2000


def trim_sinaxar(text: str) -> str:
    """Drop the site chrome that precedes the sinaxar proper.

    Every page on calendar-ortodox.ro opens with the same block: a page title,
    two banner lines, a twelve-month menu and a 1..31 day strip — around 590
    characters, on 290 of the 366 pages. It has to go before the day page can
    show anything, and it cannot be cut from the HTML: the heading is broken
    across tags there, which is why the original attempt at this silently
    matched nothing and the junk shipped.

    On the stripped text the heading is contiguous and, across all 366 pages,
    unique and always within the first 1500 characters — so this cut is safe.
    Pages with no heading (January, mostly) already start at the sinaxar and
    are returned unchanged.
    """
    match = SINAXAR_HEAD_RE.search(text)
    if not match or match.start() > _MAX_CHROME:
        return text.strip()
    return text[match.end():].strip()


def scrape_sinaxar(month: int, day: int) -> dict | None:
    luna = MONTHS[month - 1]
    url = f"http://calendar-ortodox.ro/luna/{luna}/{luna}{day:02d}.htm"
    page = fetch(url)
    if page is None:
        return None

    # The body sits between the "Sinaxar <d> <Luna>" heading and the closing
    # doxology, which every page ends with.
    start = re.search(r"Sinaxar\s+\d{1,2}\s+\w+", page)
    body = page[start.end():] if start else page
    end = re.search(r"Cu ale lor sfinte rug[^<]*Amin\.", body)
    if end:
        body = body[:end.end()]

    images = [urljoin(url, src) for src in IMG_RE.findall(body)
              if re.search(r"\.(jpe?g|png|gif)$", src, re.I)
              and "sigla" not in src and "trafic" not in src]

    text = trim_sinaxar(strip_tags(body))
    # Each commemoration begins "Tot în această zi, pomenirea ..."
    parts = re.split(r"(?=Tot în aceast[ăa] zi)", text)

    return {
        "month_day": f"{month:02d}-{day:02d}",
        "url": url,
        "text": text,
        "sections": [p.strip() for p in parts if p.strip()],
        "images": images,
        "attribution": "calendar-ortodox.ro",
    }


def download_images(sinaxar: dict[str, dict]) -> dict[str, list[str]]:
    """Fetch the saint images referenced by the sinaxar pages.

    Stored under scraped/images/<MM-DD>/ using the upstream filename, which is
    already descriptive (0806_teodor-stratilat.jpg). Returns a map of day to
    local filenames so build_seed can record them without re-deriving paths.
    """
    root = os.path.join(OUT, "images")
    os.makedirs(root, exist_ok=True)
    saved: dict[str, list[str]] = {}
    total_bytes = 0

    for key in sorted(sinaxar):
        entry = sinaxar[key]
        names: list[str] = []
        for url in entry.get("images", []):
            name = os.path.basename(url.split("?")[0])
            if not name or len(name) > 120:
                continue
            day_dir = os.path.join(root, key)
            os.makedirs(day_dir, exist_ok=True)
            path = os.path.join(day_dir, name)
            if os.path.exists(path):
                names.append(name)
                total_bytes += os.path.getsize(path)
                continue
            data = fetch(url, binary=True)
            if not data or len(data) < 512:
                continue
            open(path, "wb").write(data)
            names.append(name)
            total_bytes += len(data)
            print(f"  {key}/{name} ({len(data) // 1024} KiB)", file=sys.stderr)
        if names:
            saved[key] = names

    print(f"  {sum(len(v) for v in saved.values())} images, "
          f"{total_bytes / 1024 / 1024:.1f} MiB total", file=sys.stderr)
    json.dump(saved, open(os.path.join(OUT, "images.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=2)
    return saved


def scrape_icons() -> list[str]:
    """The fasting markers. post-N.png is the icon set the app should mirror —
    a fish for dezlegare la pește, and so on."""
    os.makedirs(os.path.join(OUT, "icons"), exist_ok=True)
    saved = []
    for family, count in (("post", 8), ("luna", 4)):
        for n in range(0, count + 1):
            name = f"{family}-{n}.png"
            url = f"https://www.resurse-ortodoxe.ro/calendarul-zilei/imagini/{name}"
            data = fetch(url, binary=True)
            if not data or len(data) < 64:
                continue
            path = os.path.join(OUT, "icons", name)
            open(path, "wb").write(data)
            saved.append(name)
            print(f"  {name} ({len(data)} bytes)", file=sys.stderr)
    return saved


# ---------------------------------------------------------------------- main
def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--year", type=int, default=2026)
    ap.add_argument("--months", action="store_true")
    ap.add_argument("--sinaxar", action="store_true")
    ap.add_argument("--icons", action="store_true")
    ap.add_argument("--images", action="store_true",
                    help="download the saint images the sinaxar pages reference")
    ap.add_argument("--all", action="store_true")
    args = ap.parse_args()

    if not (args.months or args.sinaxar or args.icons or args.images or args.all):
        ap.error("pick at least one of --months / --sinaxar / --icons / "
                 "--images / --all")

    os.makedirs(OUT, exist_ok=True)

    if args.months or args.all:
        print("Month pages (ranks, dezlegări, pericopes)…", file=sys.stderr)
        for month in range(1, 13):
            data = scrape_month(args.year, month)
            path = os.path.join(OUT, f"month-{args.year}-{month:02d}.json")
            json.dump(data, open(path, "w", encoding="utf-8"),
                      ensure_ascii=False, indent=2)
            print(f"    {len(data['days'])} days, {len(data['sundays'])} sundays",
                  file=sys.stderr)

    if args.sinaxar or args.all:
        print("Sinaxar pages (366)…", file=sys.stderr)
        out: dict[str, dict] = {}
        path = os.path.join(OUT, "sinaxar.json")
        if os.path.exists(path):
            out = json.load(open(path, encoding="utf-8"))
        for month in range(1, 13):
            for day in range(1, DAYS_IN[month - 1] + 1):
                key = f"{month:02d}-{day:02d}"
                if key in out:
                    continue
                entry = scrape_sinaxar(month, day)
                if entry:
                    out[key] = entry
                    print(f"  {key}  {len(entry['text'])} chars, "
                          f"{len(entry['images'])} images", file=sys.stderr)
                # Save as we go — a 366-page run should survive being killed.
                json.dump(out, open(path, "w", encoding="utf-8"),
                          ensure_ascii=False, indent=2)
        print(f"  {len(out)}/366 days", file=sys.stderr)

    if args.images or args.all:
        print("Saint images…", file=sys.stderr)
        path = os.path.join(OUT, "sinaxar.json")
        if os.path.exists(path):
            download_images(json.load(open(path, encoding="utf-8")))
        else:
            print("  no sinaxar.json yet — run --sinaxar first", file=sys.stderr)

    if args.icons or args.all:
        print("Fasting icons…", file=sys.stderr)
        saved = scrape_icons()
        print(f"  {len(saved)} icons -> {OUT}/icons/", file=sys.stderr)

    print("\nDone. Next: python3 build_seed.py --offline "
          "--out ../android/app/src/main/assets/seed/churches.db", file=sys.stderr)


if __name__ == "__main__":
    main()
