#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build the prepopulated Troița seed database.

    python3 build_seed.py --area bucuresti-ilfov \
        --out ../android/app/src/main/assets/seed/churches.db

    python3 build_seed.py --offline --out /tmp/churches.db     # curated only, no network

The same script becomes the server-side seeder later: swap `write_sqlite` for a
COPY into PostGIS. The row shape is identical, so nothing downstream changes.
"""
from __future__ import annotations

import argparse
import glob
import json
import math
import os
import re
import shutil
import sqlite3
import sys
import time
from datetime import datetime, timezone

import hram

HERE = os.path.dirname(os.path.abspath(__file__))

AREAS = {
    # name: (south, west, north, east)
    "bucuresti-ilfov": (44.30, 25.85, 44.75, 26.40),
    "bucuresti":       (44.33, 25.96, 44.55, 26.23),
    "cluj":            (46.35, 22.85, 47.35, 24.25),
}

MIRRORS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass.osm.ch/api/interpreter",
]

# Orthodox churches, plus the roadside crosses and shrines the app is named after.
QUERY = """
[out:json][timeout:180];
(
  nwr["amenity"="place_of_worship"]["religion"="christian"]({s},{w},{n},{e});
  nwr["historic"="wayside_cross"]({s},{w},{n},{e});
  nwr["historic"="wayside_shrine"]({s},{w},{n},{e});
  nwr["amenity"="monastery"]({s},{w},{n},{e});
);
out center tags;
"""

KEEP_DENOMINATIONS = {
    "romanian_orthodox", "orthodox", "eastern_orthodox",
    "serbian_orthodox", "russian_orthodox", "greek_orthodox",
    "old_believers", "greek_catholic", "romanian_greek_catholic",
}


# --------------------------------------------------------------------------- #
# fetch
# --------------------------------------------------------------------------- #
def fetch(bbox: tuple[float, float, float, float]) -> list[dict]:
    import requests

    s, w, n, e = bbox
    q = QUERY.format(s=s, w=w, n=n, e=e)
    last = None
    for url in MIRRORS:
        for attempt in range(3):
            try:
                print(f"  -> {url} (attempt {attempt + 1})", file=sys.stderr)
                r = requests.post(url, data={"data": q}, timeout=300)
                if r.status_code == 429 or r.status_code == 504:
                    time.sleep(15 * (attempt + 1))
                    continue
                r.raise_for_status()
                return r.json().get("elements", [])
            except Exception as exc:  # noqa: BLE001
                last = exc
                time.sleep(5 * (attempt + 1))
    raise SystemExit(f"all Overpass mirrors failed: {last}")


# --------------------------------------------------------------------------- #
# normalise
# --------------------------------------------------------------------------- #
def coords(el: dict) -> tuple[float, float] | None:
    if "lat" in el and "lon" in el:
        return float(el["lat"]), float(el["lon"])
    c = el.get("center")
    if c:
        return float(c["lat"]), float(c["lon"])
    return None


def normalise(el: dict, keep_all_denominations: bool) -> dict | None:
    tags = el.get("tags") or {}
    pos = coords(el)
    if not pos:
        return None
    lat, lon = pos

    is_wayside = tags.get("historic") in ("wayside_cross", "wayside_shrine")
    denom = (tags.get("denomination") or "").lower()

    if not is_wayside and not keep_all_denominations:
        # Keep untagged denominations: in Romania an untagged christian place of
        # worship is overwhelmingly likely to be Orthodox. Drop known non-Eastern.
        if denom and denom not in KEEP_DENOMINATIONS:
            return None

    name = hram.clean_name(tags.get("name") or tags.get("name:ro") or "")
    if not name:
        if is_wayside:
            name = "Troiță"
        else:
            return None

    kind = hram.guess_kind(tags)
    patron, feast = hram.infer(
        name, tags.get("church:patron") or tags.get("patron_saint") or tags.get("saint_name")
    )

    year = None
    for key in ("start_date", "building:start_date", "year_of_construction"):
        raw = tags.get(key)
        if raw:
            digits = "".join(ch for ch in str(raw)[:4] if ch.isdigit())
            if len(digits) == 4:
                year = int(digits)
                break

    addr = " ".join(
        p for p in (
            tags.get("addr:street"), tags.get("addr:housenumber"),
            tags.get("addr:city") or tags.get("addr:place"),
        ) if p
    ) or None

    return {
        "id": f"osm:{el['type']}/{el['id']}",
        "name": name,
        "kind": kind,
        "denomination": denom or ("romanian_orthodox" if not is_wayside else None),
        "lat": round(lat, 6),
        "lon": round(lon, 6),
        "patron": patron,
        "feast_day": feast,
        "year_built": year,
        "history": None,
        "photo_ref": None,
        "priority": 0,
        "address": addr,
        "wikidata": tags.get("wikidata"),
        "source": "osm",
        "verified": 0,
        "updated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "deleted": 0,
    }


def haversine_m(a_lat, a_lon, b_lat, b_lon) -> float:
    r = 6371008.8
    p1, p2 = math.radians(a_lat), math.radians(b_lat)
    dp = p2 - p1
    dl = math.radians(b_lon - a_lon)
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


# Tokens that carry no identifying information — every second church in Romania
# is a "Biserica Sfantul ...", so matching on these grabs the neighbour.
GENERIC_TOKENS = {
    "biserica", "bisericii", "manastirea", "manastire", "catedrala", "schitul",
    "paraclisul", "capela", "troita", "sfantul", "sfanta", "sfintii", "sfintele",
    "mucenic", "mucenita", "ierarh", "cuvios", "cuvioasa", "apostol", "mare",
    "domnului", "maicii", "noua", "vechi", "veche"
}


def _distinctive(name: str) -> set[str]:
    return {t for t in hram._fold(name).split() if len(t) > 3 and t not in GENERIC_TOKENS}


def merge_curated(rows: list[dict], curated: dict) -> list[dict]:
    """Overlay human-curated data onto OSM rows; append rows OSM doesn't have."""
    radius = curated.get("match_radius_m", 250)
    by_id = {r["id"]: r for r in rows}
    used: set[str] = set()
    # Only ever match against rows that came from Overpass. Matching against
    # rows we appended ourselves earlier in this loop makes curated entries
    # cannibalise each other.
    osm_rows = [r for r in rows if r["source"] == "osm"]
    appended: list[dict] = []

    for entry in curated["entries"]:
        target = None
        if entry.get("match") and entry["match"] in by_id:
            target = by_id[entry["match"]]
        else:
            want = _distinctive(entry["name"])
            best, best_d = None, radius + 1
            for r in osm_rows:
                if r["id"] in used:
                    continue
                d = haversine_m(entry["lat"], entry["lon"], r["lat"], r["lon"])
                if d > radius or d >= best_d:
                    continue
                have = _distinctive(r["name"])
                # Distinctive-token overlap, or near-identical coordinates.
                if (want & have) or d < 40:
                    best, best_d = r, d
            target = best

        payload = {k: v for k, v in entry.items() if not k.startswith("_") and k != "match"}
        if target is not None:
            used.add(target["id"])
            for k, v in payload.items():
                if v is not None:
                    target[k] = v
            target["source"] = "manual"
        else:
            slug = hram._fold(entry["name"]).replace(" ", "-")
            new = {
                "id": f"troita:{slug}", "history": None, "photo_ref": None,
                "priority": 0, "address": None,
                "wikidata": None, "denomination": "romanian_orthodox",
                "patron": None, "feast_day": None, "year_built": None,
                "kind": "church", "source": "manual", "verified": 0,
                "updated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "deleted": 0,
            }
            new.update(payload)
            appended.append(new)
    return rows + appended


def apply_defaults(rows: list[dict]) -> list[dict]:
    for r in rows:
        if not r.get("photo_ref"):
            slug = hram._fold(r["name"]).replace(" ", "-")[:48]
            r["photo_ref"] = f"asset://churches/{slug}.jpg"
        if not r.get("priority"):
            # Monasteries and cathedrals win a contested geofence slot; a named
            # church beats an unnamed troiță.
            base = {"cathedral": 60, "monastery": 55, "church": 30,
                    "chapel": 20, "wayside_cross": 10}.get(r["kind"], 20)
            if r.get("history"):
                base += 15
            if r.get("year_built") and r["year_built"] < 1800:
                base += 10
            r["priority"] = base
    return rows


COLUMNS = [
    "id", "name", "kind", "denomination", "lat", "lon", "patron", "feast_day",
    "year_built", "history", "photo_ref", "priority",
    "address", "wikidata", "source", "verified", "updated_at", "deleted",
]

FEAST_COLUMNS = [
    "id", "month_day", "movable_key", "name", "short_name", "rank", "kind",
    "note", "dezlegare", "source", "verified",
]


def load_feasts(published: dict[str, dict] | None = None) -> list[tuple]:
    """Curated commemorations. Fixed feasts key off MM-DD, movable ones off the
    same keys FeastCalendar resolves against Pascha."""
    path = os.path.join(HERE, "feasts.json")
    if not os.path.exists(path):
        return []
    entries = json.load(open(path, encoding="utf-8"))["feasts"]
    rows = []
    covered: set[str] = set()
    for e in entries:
        movable = e.get("movable")
        month_day = e.get("date")
        if not movable and not month_day:
            raise SystemExit(f"feast needs `date` or `movable`: {e.get('name')}")
        ident = f"feast:mov:{movable}" if movable else f"feast:{month_day}"
        if month_day:
            covered.add(month_day)
        rows.append((
            ident, month_day, movable, e["name"], e.get("short"),
            e.get("rank", "simplu"), e.get("kind"), e.get("note"),
            e.get("dezlegare"), "manual", int(e.get("verified", 0)),
        ))

    # Days transcribed from a published calendar via import_calendar_html.py.
    # These are trustworthy — name and rank come from the source, so they are
    # marked verified and win over the hand-written fallback below.
    imported: dict[str, dict] = {}
    for path in sorted(glob.glob(os.path.join(HERE, "imported", "*.json"))):
        payload = json.load(open(path, encoding="utf-8"))
        for entry in payload.get("days", []):
            imported[entry["month_day"]] = entry

    # Published data beats hand-written data on name and rank — those are the
    # fields the source is authoritative for. Curated rows keep the things the
    # source does not express: the dezlegare override, the short name we chose
    # for the grid, and the `kind` used for styling Romanian saints.
    by_day = {r[1]: i for i, r in enumerate(rows) if r[1]}

    for month_day, entry in sorted(imported.items()):
        rank = entry.get("rank", "simplu")
        name = entry["name"]
        kind = "romanesc" if entry.get("romanian") else None
        note = "; ".join(entry.get("notes", [])) or None
        dezlegare = entry.get("fast") if entry.get("fast") in (
            "fish", "wineOil", "none") else None

        existing = by_day.get(month_day)
        if existing is not None:
            old_row = rows[existing]
            rows[existing] = (
                old_row[0], month_day, None,
                name,                         # published name wins
                old_row[4] or _short(name),   # keep our short label
                rank,                         # published rank wins
                old_row[6] or kind,
                old_row[7] or note,
                old_row[8] or dezlegare,      # keep our dezlegare override
                "calendar-ro", 1,
            )
            continue

        covered.add(month_day)
        rows.append((
            f"feast:{month_day}", month_day, None, name, _short(name),
            rank, kind, note, dezlegare, "calendar-ro", 1,
        ))

    # The scraped calendar is authoritative for name and rank — it is a
    # published source and the menologion is my best recollection. Applied last
    # so it wins over both the curated file and the fallback.
    for month_day, entry in sorted((published or {}).items()):
        idx = next((i for i, r in enumerate(rows) if r[1] == month_day), None)
        name = entry.get("name") or ""
        if not name:
            continue
        if idx is None:
            covered.add(month_day)
            rows.append((
                f"feast:{month_day}", month_day, None, name, _short(name),
                entry.get("rank", "simplu"), None,
                "; ".join(entry.get("notes", [])) or None, None, "scraped", 1,
            ))
        else:
            old_row = rows[idx]
            rows[idx] = (
                old_row[0], month_day, None, name, _short(name),
                entry.get("rank", "simplu"), old_row[6],
                old_row[7] or ("; ".join(entry.get("notes", [])) or None),
                old_row[8], "scraped", 1,
            )

    # Everything still uncovered falls back to the hand-written menologion. An
    # Orthodox calendar has an entry for all 365 days — a blank day is a
    # missing row, not an ordinary one.
    from menologion import MENOLOGION
    for month_day, name in sorted(MENOLOGION.items()):
        if month_day in covered:
            continue
        rows.append((
            f"feast:{month_day}", month_day, None, name, _short(name),
            "simplu", None, None, None, "menologion", 0,
        ))
    return rows


def _short(name: str) -> str:
    """First commemoration only, for the places that show a single line."""
    head = name.split(";")[0].strip()
    return head if len(head) <= 42 else head[:39].rstrip(" ,") + "…"


SINAXAR_COLUMNS = ["month_day", "text", "sections", "images", "source_url", "attribution"]
OVERRIDE_COLUMNS = [
    "year", "month_day", "fast_level", "notes", "glas", "voscreasna",
    "sunday_title", "sunday_subtitle", "apostol", "evanghelie",
]


def install_images() -> dict[str, list[str]]:
    """Copy scraped saint images into assets/ and return the flattened names.

    Flattened deliberately. Flutter's `assets:` declarations do not recurse, so
    293 per-day folders would mean 293 lines in pubspec.yaml — one directory and
    a `MM-DD__` prefix means one line and no maintenance.
    """
    src_root = os.path.join(HERE, "scraped", "images")
    if not os.path.isdir(src_root):
        return {}

    dest = os.path.join(HERE, "..", "assets", "sinaxar")
    os.makedirs(dest, exist_ok=True)

    installed: dict[str, list[str]] = {}
    copied = skipped = 0
    for day in sorted(os.listdir(src_root)):
        day_dir = os.path.join(src_root, day)
        if not os.path.isdir(day_dir):
            continue
        names = []
        for name in sorted(os.listdir(day_dir)):
            flat = f"{day}__{name}"
            target = os.path.join(dest, flat)
            source = os.path.join(day_dir, name)
            if not os.path.exists(target) or \
                    os.path.getsize(target) != os.path.getsize(source):
                shutil.copy2(source, target)
                copied += 1
            else:
                skipped += 1
            names.append(flat)
        if names:
            installed[day] = names

    total = sum(os.path.getsize(os.path.join(dest, f)) for f in os.listdir(dest))
    print(f"  images: {copied} copied, {skipped} already current, "
          f"{total / 1024 / 1024:.1f} MiB in assets/sinaxar/")
    return installed


def load_scraped() -> tuple[list[tuple], list[tuple], dict[str, dict]]:
    """Read tool/scraped/ if the scraper has been run.

    Returns (sinaxar rows, day_override rows, per-day published facts). The
    third is used to overwrite feast names and ranks, because the published
    calendar is authoritative and the hand-written menologion is not.
    """
    scraped = os.path.join(HERE, "scraped")
    if not os.path.isdir(scraped):
        return [], [], {}

    # --- sinaxar text ---------------------------------------------------
    sinaxar_rows: list[tuple] = []
    sinaxar_path = os.path.join(scraped, "sinaxar.json")
    images_map = install_images()

    if os.path.exists(sinaxar_path):
        for key, entry in sorted(json.load(open(sinaxar_path, encoding="utf-8")).items()):
            sinaxar_rows.append((
                key,
                entry.get("text", ""),
                json.dumps(entry.get("sections", []), ensure_ascii=False),
                json.dumps(images_map.get(key, []), ensure_ascii=False),
                entry.get("url"),
                entry.get("attribution", "calendar-ortodox.ro"),
            ))

    # --- month pages: dezlegări, ranks, pericopes ------------------------
    override_rows: list[tuple] = []
    published: dict[str, dict] = {}
    for path in sorted(glob.glob(os.path.join(scraped, "month-*.json"))):
        year = int(re.search(r"month-(\d{4})-", path).group(1))
        payload = json.load(open(path, encoding="utf-8"))
        for d in payload.get("days", []):
            published[d["month_day"]] = d
            override_rows.append((
                year, d["month_day"], d.get("fast"),
                "; ".join(d.get("notes", [])) or None,
                None, None, None, None, None, None,
            ))
    return sinaxar_rows, override_rows, published


def write_sqlite(rows: list[dict], out: str, bbox, area: str) -> None:
    os.makedirs(os.path.dirname(os.path.abspath(out)) or ".", exist_ok=True)
    if os.path.exists(out):
        os.remove(out)
    db = sqlite3.connect(out)
    db.executescript(open(os.path.join(HERE, "schema.sql"), encoding="utf-8").read())
    db.executemany(
        f"INSERT OR REPLACE INTO churches ({','.join(COLUMNS)}) "
        f"VALUES ({','.join('?' * len(COLUMNS))})",
        [tuple(r.get(c) for c in COLUMNS) for r in rows],
    )
    sinaxar_rows, override_rows, published = load_scraped()

    feasts = load_feasts(published)
    if feasts:
        db.executemany(
            f"INSERT OR REPLACE INTO feasts ({','.join(FEAST_COLUMNS)}) "
            f"VALUES ({','.join('?' * len(FEAST_COLUMNS))})",
            feasts,
        )

    if sinaxar_rows:
        db.executemany(
            f"INSERT OR REPLACE INTO sinaxar ({','.join(SINAXAR_COLUMNS)}) "
            f"VALUES ({','.join('?' * len(SINAXAR_COLUMNS))})",
            sinaxar_rows,
        )
    if override_rows:
        db.executemany(
            f"INSERT OR REPLACE INTO day_overrides ({','.join(OVERRIDE_COLUMNS)}) "
            f"VALUES ({','.join('?' * len(OVERRIDE_COLUMNS))})",
            override_rows,
        )

    meta = {
        "schema_version": "3",
        "seed_version": datetime.now(timezone.utc).strftime("%Y%m%d%H%M"),
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "area": area,
        "bbox": ",".join(str(x) for x in bbox),
        "count": str(len(rows)),
        "feast_count": str(len(feasts)),
        "sinaxar_count": str(len(sinaxar_rows)),
        "override_count": str(len(override_rows)),
        "attribution": "© OpenStreetMap contributors, ODbL 1.0",
    }
    db.executemany("INSERT OR REPLACE INTO meta (key,value) VALUES (?,?)", list(meta.items()))
    db.commit()
    db.execute("VACUUM")
    db.close()

    # Version marker sits next to the .db in assets. ChurchStore compares it
    # against the copy it installed and re-seeds when they differ, so shipping
    # new church data is just "rebuild the asset and release".
    with open(os.path.join(os.path.dirname(os.path.abspath(out)), "version.txt"),
              "w", encoding="utf-8") as fh:
        fh.write(meta["seed_version"] + "\n")

    print(f"wrote -> {out} ({os.path.getsize(out) / 1024:.0f} KiB)")
    for label, count in (
        ("churches", len(rows)),
        ("feasts", len(feasts)),
        ("sinaxar days", len(sinaxar_rows)),
        ("day overrides", len(override_rows)),
    ):
        flag = "   <-- EMPTY" if count == 0 else ""
        print(f"    {label:<16} {count}{flag}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--area", default="bucuresti-ilfov", choices=sorted(AREAS))
    ap.add_argument("--bbox", help="south,west,north,east — overrides --area")
    ap.add_argument("--out", default=os.path.join(
        HERE, "..", "android", "app", "src", "main", "assets", "seed", "churches.db"))
    ap.add_argument("--offline", action="store_true", help="skip Overpass, curated rows only")
    ap.add_argument("--all-denominations", action="store_true")
    ap.add_argument("--cache", default=os.path.join(HERE, ".overpass-cache.json"))
    args = ap.parse_args()

    bbox = tuple(float(x) for x in args.bbox.split(",")) if args.bbox else AREAS[args.area]

    rows: list[dict] = []
    if not args.offline:
        if os.path.exists(args.cache):
            print("using cached Overpass response", file=sys.stderr)
            elements = json.load(open(args.cache, encoding="utf-8"))
        else:
            print(f"querying Overpass for {bbox} …", file=sys.stderr)
            elements = fetch(bbox)
            json.dump(elements, open(args.cache, "w", encoding="utf-8"))
        print(f"  {len(elements)} raw elements", file=sys.stderr)
        for el in elements:
            row = normalise(el, args.all_denominations)
            if row:
                rows.append(row)
        print(f"  {len(rows)} after filtering", file=sys.stderr)

    curated = json.load(open(os.path.join(HERE, "curated.json"), encoding="utf-8"))
    rows = merge_curated(rows, curated)
    rows = apply_defaults(rows)

    # Deduplicate: same name within 80 m is the same building mapped twice
    # (node + way). Keep the richer row.
    rows.sort(key=lambda r: (-r["priority"], r["id"]))
    kept: list[dict] = []
    for r in rows:
        if any(haversine_m(r["lat"], r["lon"], k["lat"], k["lon"]) < 80
               and (hram._fold(r["name"]) == hram._fold(k["name"])
                    or (_distinctive(r["name"]) and
                        _distinctive(r["name"]) == _distinctive(k["name"])))
               for k in kept):
            continue
        kept.append(r)

    write_sqlite(kept, args.out, bbox, args.bbox or args.area)
    unverified = sum(1 for r in kept if not r["verified"])
    if unverified:
        print(f"NOTE: {unverified}/{len(kept)} rows are unverified — review before shipping.")


if __name__ == "__main__":
    main()
