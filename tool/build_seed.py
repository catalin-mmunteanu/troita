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
import json
import math
import os
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

# Default geofence radius by kind, in metres. Tuned so that a pedestrian always
# gets an ENTER and a driver usually does; see README for the speed math.
RADIUS_BY_KIND = {
    "cathedral": 400,
    "monastery": 400,
    "church": 350,
    "chapel": 250,
    "wayside_cross": 200,
}

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
        "geofence_radius_m": None,
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
                "geofence_radius_m": None, "priority": 0, "address": None,
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
        if not r.get("geofence_radius_m"):
            r["geofence_radius_m"] = RADIUS_BY_KIND.get(r["kind"], 350)
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
    "year_built", "history", "photo_ref", "geofence_radius_m", "priority",
    "address", "wikidata", "source", "verified", "updated_at", "deleted",
]

FEAST_COLUMNS = [
    "id", "month_day", "movable_key", "name", "short_name", "rank", "kind",
    "note", "dezlegare", "source", "verified",
]


def load_feasts() -> list[tuple]:
    """Curated commemorations. Fixed feasts key off MM-DD, movable ones off the
    same keys FeastCalendar resolves against Pascha."""
    path = os.path.join(HERE, "feasts.json")
    if not os.path.exists(path):
        return []
    entries = json.load(open(path, encoding="utf-8"))["feasts"]
    rows = []
    for e in entries:
        movable = e.get("movable")
        month_day = e.get("date")
        if not movable and not month_day:
            raise SystemExit(f"feast needs `date` or `movable`: {e.get('name')}")
        ident = f"feast:mov:{movable}" if movable else f"feast:{month_day}"
        rows.append((
            ident, month_day, movable, e["name"], e.get("short"),
            e.get("rank", "simplu"), e.get("kind"), e.get("note"),
            e.get("dezlegare"), "manual", int(e.get("verified", 0)),
        ))
    return rows


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
    feasts = load_feasts()
    if feasts:
        db.executemany(
            f"INSERT OR REPLACE INTO feasts ({','.join(FEAST_COLUMNS)}) "
            f"VALUES ({','.join('?' * len(FEAST_COLUMNS))})",
            feasts,
        )

    meta = {
        "schema_version": "2",
        "seed_version": datetime.now(timezone.utc).strftime("%Y%m%d%H%M"),
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "area": area,
        "bbox": ",".join(str(x) for x in bbox),
        "count": str(len(rows)),
        "feast_count": str(len(feasts)),
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

    print(f"wrote {len(rows)} churches + {len(feasts)} feasts -> {out} "
          f"({os.path.getsize(out) / 1024:.0f} KiB)")


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
