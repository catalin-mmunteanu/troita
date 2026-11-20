#!/usr/bin/env python3
"""Backtest the fasting engine and write the golden test vectors.

    python3 tool/engine_golden.py --backtest     # engine vs published 2026/2027
    python3 tool/engine_golden.py --write        # test/golden/engine-2026-2030.json

The golden file is the contract between the three copies of the engine: the
Dart one in lib/core/liturgical/ (the product), tool/engine_port.py (this
pipeline) and src/lib/liturgical.ts in the troita-web repo. Each row carries
the inputs (date, rank, dezlegare of the day's feasts) and the expected
outputs, so the Dart and TypeScript tests are pure engine tests that need no
database.

The backtest runs the engine with the published per-day values switched off and
compares it with what the published calendar says. It is the measure of how far
a computed year (2028–2030, before the official calendar appears) can be
trusted. Days the published calendar leaves unmarked inside a fast are counted
as unknown, not as "no fast".
"""
from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
from datetime import date, timedelta

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import engine_port as E  # noqa: E402

DB = os.path.join(HERE, "..", "android", "app", "src", "main", "assets", "seed", "churches.db")
GOLDEN = os.path.join(HERE, "..", "test", "golden", "engine-2026-2030.json")
YEARS = range(2026, 2031)

# Published notes that mean ajunare even where no fast icon was scraped.
STRICT_NOTES = ("Numai seara", "Post negru", "pâine și apă")


def load_feasts(db):
    return db.execute(
        "SELECT month_day, movable_key, rank, dezlegare FROM feasts ORDER BY id").fetchall()


def transferred(year: int, md: str) -> date | None:
    """Where a fixed feast is kept that year. Sf. Gheorghe (23 April) moves to
    Bright Monday when it falls from Florii to Pascha (FeastCalendar.transferred
    in Dart, feastDate in the website's calendar.ts)."""
    try:
        d = date(year, int(md[:2]), int(md[3:]))
    except ValueError:            # 29 February in a common year
        return None
    if md == "04-23":
        p = E.pascha(year)
        if p - timedelta(days=7) <= d <= p:
            return p + timedelta(days=1)
    return d


def feasts_on(feasts, d: date):
    """(rank, dezlegare) of the day, the way FeastRepository resolves them:
    highest rank first; the dezlegare of any feast that carries one."""
    hits = []
    for md, mk, rank, dz in feasts:
        if mk:
            off = E.MOVABLE.get(mk)
            if off is not None and E.pascha(d.year) + timedelta(days=off) == d:
                hits.append((rank, dz))
        elif md and transferred(d.year, md) == d:
            hits.append((rank, dz))
    hits.sort(key=lambda h: -E.RANK_WEIGHT.get(h[0], 0))
    rank = hits[0][0] if hits else "simplu"
    dz = next((h[1] for h in hits if h[1] in E.ORDER), None)
    return rank, dz


def days(year: int):
    d = date(year, 1, 1)
    while d.year == year:
        yield d
        d += timedelta(days=1)


def published_level(level, notes):
    if level == "dairy":          # Săptămâna Brânzei: shown as no fast
        return "none"
    if level:
        return level
    if notes and any(s in notes for s in STRICT_NOTES):
        return "strict"
    return None


def backtest(db) -> int:
    feasts = load_feasts(db)
    overrides = {(y, md): (fl, n) for y, md, fl, n in db.execute(
        "SELECT year, month_day, fast_level, notes FROM day_overrides")}
    years = sorted({y for y, _ in overrides})
    total = unknown = 0
    misses = []
    for y in years:
        for d in days(y):
            rank, dz = feasts_on(feasts, d)
            got = E.day_for(d, rank, dz)["fastLevel"]
            fl, notes = overrides.get((y, f"{d.month:02d}-{d.day:02d}"), (None, None))
            want = published_level(fl, notes)
            if want is None:
                if got != "none" and not (notes and "Dezlegare" in notes):
                    unknown += 1
                    continue
                want = "none"
            total += 1
            if got != want:
                misses.append((d, rank, got, want))
    ok = total - len(misses)
    print(f"years {years}: {ok}/{total} days match ({100 * ok / max(total, 1):.1f}%), "
          f"{unknown} unmarked fast days skipped")
    for d, rank, got, want in misses:
        print(f"  {d} {d.strftime('%a')}  {rank:<15} engine {got:<8} published {want}")
    return 0


def write_golden(db) -> int:
    feasts = load_feasts(db)
    rows = []
    for y in YEARS:
        for d in days(y):
            rank, dz = feasts_on(feasts, d)
            out = E.day_for(d, rank, dz)
            rows.append([d.isoformat(), rank, dz, out["fastLevel"], out["period"],
                         out["glas"], out["voscreasna"]])
    payload = {
        "about": "Golden vectors for the fasting engine. Written by tool/engine_golden.py "
                 "from tool/engine_port.py; asserted by test/engine_golden_test.dart and by "
                 "troita-web's npm test. Inputs: date, rank, dezlegare. Outputs: fastLevel, "
                 "period, glas, voscreasna.",
        "columns": ["date", "rank", "dezlegare", "fastLevel", "period", "glas", "voscreasna"],
        "pascha": {str(y): E.pascha(y).isoformat() for y in YEARS},
        "days": rows,
    }
    os.makedirs(os.path.dirname(GOLDEN), exist_ok=True)
    with open(GOLDEN, "w", encoding="utf-8") as f:
        f.write("{\n")
        for k in ("about", "columns", "pascha"):
            f.write(f" {json.dumps(k)}: {json.dumps(payload[k], ensure_ascii=False)},\n")
        f.write(' "days": [\n')
        f.write(",\n".join("  " + json.dumps(r, ensure_ascii=False) for r in rows))
        f.write("\n ]\n}\n")
    print(f"{len(rows)} days -> {os.path.relpath(GOLDEN)}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--db", default=DB)
    ap.add_argument("--backtest", action="store_true")
    ap.add_argument("--write", action="store_true")
    args = ap.parse_args()
    db = sqlite3.connect(args.db)
    if args.backtest:
        backtest(db)
    if args.write:
        write_golden(db)
    if not (args.backtest or args.write):
        ap.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
