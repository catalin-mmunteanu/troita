#!/usr/bin/env python3
"""Refresh every piece of data the app ships, in one command.

    python3 tool/update_data.py                 # this year and next, everything
    python3 tool/update_data.py --skip-osm      # calendar only, keep the churches
    python3 tool/update_data.py --years 2027    # a specific year

Runs, in order:

  1. scrape_calendar.py --months --fresh   for this year and next
  2. scrape_calendar.py --sinaxar --images only if the sinaxar is missing
  3. extract_pbf.py --download             a fresh Geofabrik extract, clipped
  4. build_seed.py --area romania          the database the APK ships

Built to run unattended (the GitHub Action calls exactly this), which shapes
three decisions:

* **It can only make the data better.** The previous database is kept, and the
  new one must pass a set of checks — no fewer published years, no missing
  sinaxar days, no collapse in the number of churches — or the old file is put
  back and the run fails. A night when Geofabrik is down or the calendar site
  changes its markup produces a red run, not a release with twenty churches.

* **It only reports a change when the content changed.** The seed carries a
  build timestamp, so a rebuild always differs byte for byte; compared that way
  the job would open a pull request every month. Content is hashed instead, and
  when it matches, the old file is restored so git sees nothing.

* **Each step is the existing script, run as a subprocess.** Nothing is
  duplicated here, and every step can still be run by hand.

Writes a Markdown summary (--summary) that the workflow uses as the pull
request description.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import shutil
import sqlite3
import subprocess
import sys
import time
from datetime import datetime, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
SEED = os.path.join(HERE, "..", "android", "app", "src", "main", "assets", "seed")
DB = os.path.join(SEED, "churches.db")
VERSION = os.path.join(SEED, "version.txt")
PBF = os.path.join(HERE, "romania-latest.osm.pbf")
ELEMENTS = os.path.join(HERE, ".pbf-elements.json")

# Geofabrik rebuilds daily; anything older than this is re-downloaded. Long
# enough that a developer re-running the script does not pull 330 MB twice.
PBF_MAX_AGE_DAYS = 20

# A rebuild may lose some churches — OSM deletes duplicates, merges buildings —
# but losing more than this fraction means something broke upstream.
MAX_CHURCH_LOSS = 0.10


def run(step: str, args: list[str]) -> bool:
    """Run one pipeline script; report, never raise."""
    print(f"\n=== {step}", flush=True)
    started = time.time()
    result = subprocess.run([sys.executable, *args], cwd=HERE)
    ok = result.returncode == 0
    print(f"=== {step}: {'ok' if ok else f'FAILED ({result.returncode})'} "
          f"in {time.time() - started:.0f}s", flush=True)
    return ok


def snapshot(path: str) -> dict:
    """What the database contains, for comparing two builds."""
    if not os.path.exists(path):
        return {}
    db = sqlite3.connect(path)
    try:
        q = lambda sql: db.execute(sql).fetchall()  # noqa: E731
        digest = hashlib.sha256()
        # Every table the app reads, in a stable order. Left out on purpose,
        # because they change on every build without the data changing: the
        # `meta` table (build timestamp) and `churches.updated_at`, which
        # build_seed stamps with the time of the run. Hashing those made two
        # builds from identical inputs look different, and the job would have
        # opened a pull request every month with nothing in it.
        volatile = {"updated_at"}
        for table, order in (("churches", "id"), ("feasts", "id"),
                             ("sinaxar", "month_day"),
                             ("day_overrides", "year, month_day")):
            cols = [c[1] for c in q(f"PRAGMA table_info({table})")
                    if c[1] not in volatile]
            for row in q(f"SELECT {', '.join(cols)} FROM {table} ORDER BY {order}"):
                digest.update(repr(row).encode("utf-8"))
        meta = dict(q("SELECT key, value FROM meta"))
        return {
            "hash": digest.hexdigest(),
            "churches": q("SELECT COUNT(*) FROM churches WHERE deleted = 0")[0][0],
            "kinds": dict(q("SELECT kind, COUNT(*) FROM churches "
                            "WHERE deleted = 0 GROUP BY kind")),
            "feasts": q("SELECT COUNT(*) FROM feasts")[0][0],
            "sinaxar": q("SELECT COUNT(*) FROM sinaxar")[0][0],
            "years": sorted(int(y) for y in
                            (meta.get("published_years") or "").split(",") if y),
            "version": meta.get("seed_version", "?"),
        }
    finally:
        db.close()


def check(before: dict, after: dict) -> list[str]:
    """Reasons the new database must not replace the old one. Empty = fine."""
    problems: list[str] = []
    if not after:
        return ["the build produced no database"]
    if after["sinaxar"] < max(before.get("sinaxar", 0), 365):
        problems.append(f"sinaxar has {after['sinaxar']} days "
                        f"(was {before.get('sinaxar', 0)})")
    lost = set(before.get("years", [])) - set(after["years"])
    if lost:
        problems.append(f"published years disappeared: {sorted(lost)}")
    if before.get("churches") and \
            after["churches"] < before["churches"] * (1 - MAX_CHURCH_LOSS):
        problems.append(f"churches fell from {before['churches']} to "
                        f"{after['churches']}")
    if after["feasts"] < 300:
        problems.append(f"only {after['feasts']} feasts")
    return problems


def summary(before: dict, after: dict, steps: dict[str, bool],
            problems: list[str], changed: bool) -> str:
    def delta(key: str) -> str:
        a, b = before.get(key, 0), after.get(key, 0)
        return f"{b}" if a == b else f"{a} → {b}"

    lines = ["## Actualizare date Troița", ""]
    if problems:
        lines += ["**Build respins** — baza veche a fost păstrată.", ""]
        lines += [f"- {p}" for p in problems]
        lines.append("")
    elif not changed:
        lines += ["Nicio schimbare de conținut față de baza actuală.", ""]

    lines += [
        "| | |", "|---|---|",
        f"| Biserici și troițe | {delta('churches')} |",
        f"| Pomeniri | {delta('feasts')} |",
        f"| Zile de sinaxar | {delta('sinaxar')} |",
        f"| Ani cu calendar publicat | "
        f"{', '.join(map(str, after.get('years') or before.get('years', [])))} |",
        "",
        "Pași: " + " · ".join(f"{k} {'✓' if v else '✗'}" for k, v in steps.items()),
    ]

    this_year = datetime.now(timezone.utc).year
    years = after.get("years") or before.get("years") or []
    if not years or max(years) <= this_year:
        lines += ["", f"⚠️ Calendarul pentru {this_year + 1} nu este publicat încă. "
                  "Job-ul îl va prelua automat când apare."]
    if after.get("kinds"):
        lines += ["", "Pe tipuri: " + ", ".join(
            f"{k} {v}" for k, v in sorted(after["kinds"].items(), key=lambda x: -x[1]))]
    return "\n".join(lines) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    now = datetime.now(timezone.utc)
    ap.add_argument("--years", type=int, nargs="*",
                    default=[now.year, now.year + 1],
                    help="calendar years to scrape (default: this year and next)")
    ap.add_argument("--skip-osm", action="store_true",
                    help="keep the current church data; refresh the calendar only")
    ap.add_argument("--skip-calendar", action="store_true",
                    help="keep the current calendar; refresh the churches only")
    ap.add_argument("--summary", help="write a Markdown summary here")
    args = ap.parse_args()

    before = snapshot(DB)
    backup_db = DB + ".previous"
    backup_version = VERSION + ".previous"
    if os.path.exists(DB):
        shutil.copy2(DB, backup_db)
    if os.path.exists(VERSION):
        shutil.copy2(VERSION, backup_version)

    steps: dict[str, bool] = {}

    # 1–2. Calendar. A failed or unpublished year is not fatal: the scraper
    # never overwrites good months, so the build continues with what exists.
    if not args.skip_calendar:
        for year in args.years:
            steps[f"calendar {year}"] = run(
                f"calendar {year}",
                ["scrape_calendar.py", "--year", str(year), "--months", "--fresh"])
        if not os.path.exists(os.path.join(HERE, "scraped", "sinaxar.json")):
            steps["sinaxar"] = run("sinaxar", ["scrape_calendar.py", "--sinaxar", "--images"])

    # 3. Churches. Without a usable extract the build is not attempted at all:
    # build_seed without elements falls back to the twenty curated rows, and
    # that must never be mistaken for an update.
    if not args.skip_osm:
        if os.path.exists(PBF) and \
                time.time() - os.path.getmtime(PBF) > PBF_MAX_AGE_DAYS * 86400:
            os.remove(PBF)
        steps["OSM"] = run("OSM extract", ["extract_pbf.py", "--download"])
    if not os.path.exists(ELEMENTS):
        steps["OSM"] = False
        print(f"\nNo {os.path.basename(ELEMENTS)} — cannot build without church "
              f"data. Run without --skip-osm once.", file=sys.stderr)
        problems = ["no church data to build from"]
        _write_summary(args.summary, summary(before, before, steps, problems, False))
        return 2

    # 4. Build.
    steps["build"] = run("build seed", [
        "build_seed.py", "--area", "romania", "--elements", ELEMENTS])
    after = snapshot(DB) if steps["build"] else {}

    problems = check(before, after) if steps["build"] else ["build_seed failed"]
    changed = bool(after) and after.get("hash") != before.get("hash")

    if problems or not changed:
        # Put the previous files back: either the new build is worse, or it is
        # identical in content and only the timestamp moved.
        if os.path.exists(backup_db):
            shutil.copy2(backup_db, DB)
        if os.path.exists(backup_version):
            shutil.copy2(backup_version, VERSION)

    for path in (backup_db, backup_version):
        if os.path.exists(path):
            os.remove(path)

    text = summary(before, after or before, steps, problems, changed)
    _write_summary(args.summary, text)
    print("\n" + text)

    if problems:
        return 1
    print("CHANGED" if changed else "UNCHANGED")
    return 0


def _write_summary(path: str | None, text: str) -> None:
    if path:
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text)


if __name__ == "__main__":
    sys.exit(main())
