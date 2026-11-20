#!/usr/bin/env python3
"""Checks assets/data/name_days.json before it ships to the app and the site.

    python3 tool/check_name_days.py

- every fixed feast has a real MM-DD date, every movable one a known key;
- no duplicate feast ids, no name listed twice in the same feast;
- diacritics are the comma-below ș ț, never the cedilla ş ţ;
- every "primary" date is a feast that actually lists the name;
- every note belongs to a name that exists;
- sources are 'dgep' (with a sourceUrl) or 'calendar'.
"""
import json
import os
import sys
from datetime import date

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import engine_port as E  # noqa: E402

PATH = os.path.join(HERE, "..", "assets", "data", "name_days.json")


def main() -> int:
    doc = json.load(open(PATH, encoding="utf-8"))
    problems = []
    ids = set()
    by_name: dict[str, set[str]] = {}
    for f in doc["feasts"]:
        fid = f["id"]
        if fid in ids:
            problems.append(f"duplicate feast {fid}")
        ids.add(fid)
        if "date" in f:
            m, d = map(int, f["date"].split("-"))
            try:
                date(2028, m, d)  # a leap year, so 02-29 is allowed
            except ValueError:
                problems.append(f"{fid}: no such date")
            if fid != f["date"]:
                problems.append(f"{fid}: id and date differ")
        elif f.get("movable") not in E.MOVABLE:
            problems.append(f"{fid}: unknown movable key {f.get('movable')}")
        if f["source"] not in ("dgep", "calendar"):
            problems.append(f"{fid}: unknown source {f['source']}")
        if f["source"] == "dgep" and not f.get("sourceUrl"):
            problems.append(f"{fid}: dgep feast without sourceUrl")
        for gender in ("m", "f"):
            names = f[gender]
            if len(names) != len(set(names)):
                problems.append(f"{fid}: a name is listed twice ({gender})")
            for n in names:
                if any(c in n for c in "şţŞŢ"):
                    problems.append(f"{fid}: cedilla in {n!r}, use ș ț")
                by_name.setdefault(n, set()).add(fid)
    for name, fid in doc.get("primary", {}).items():
        if fid not in by_name.get(name, set()):
            problems.append(f"primary {name} -> {fid}, but that feast does not list it")
    for name in doc.get("notes", {}):
        if name not in by_name:
            problems.append(f"note for unknown name {name}")
    multi = sum(1 for v in by_name.values() if len(v) > 1)
    if problems:
        print("name_days.json:\n  " + "\n  ".join(problems))
        return 1
    print(f"name_days.json: {len(doc['feasts'])} feasts, {len(by_name)} names, "
          f"{multi} on more than one day. OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
