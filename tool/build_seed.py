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
    # The whole country, generous enough to include the Danube delta and the
    # western border. Fetched tile by tile, not in one request — see fetch_tiled.
    "romania":         (43.55, 20.20, 48.30, 29.80),
}

# Above this span a single Overpass request is a bad idea: it either times out
# or returns tens of megabytes that a mirror is entitled to refuse mid-transfer.
TILE_THRESHOLD_DEG = 2.0
TILE_DEG = 1.0

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


def fetch_tiled(
    bbox: tuple[float, float, float, float],
    cache_dir: str,
    tile_deg: float = TILE_DEG,
) -> list[dict]:
    """Fetch a large area one tile at a time, caching each tile on disk.

    Country-scale extraction is a long job against a free, donated service, and
    the two things that make it painful are both avoidable. A single request for
    Romania times out; and a failure forty minutes in should not throw away the
    thirty-nine minutes that worked. So each tile is a separate request written
    to its own file, and re-running picks up exactly where it stopped.

    Tiles overlap at their edges — an element on a boundary comes back in both
    neighbours — so results are merged by OSM id before returning.
    """
    os.makedirs(cache_dir, exist_ok=True)
    south, west, north, east = bbox

    tiles: list[tuple[float, float, float, float]] = []
    lat = south
    while lat < north:
        lon = west
        while lon < east:
            tiles.append((lat, lon, min(lat + tile_deg, north), min(lon + tile_deg, east)))
            lon += tile_deg
        lat += tile_deg

    merged: dict[str, dict] = {}
    print(f"  {len(tiles)} tiles of {tile_deg}°", file=sys.stderr)
    for i, tile in enumerate(tiles, 1):
        s, w, n, e = tile
        path = os.path.join(cache_dir, f"{s:.2f}_{w:.2f}.json")
        if os.path.exists(path):
            elements = json.load(open(path, encoding="utf-8"))
        else:
            print(f"  [{i}/{len(tiles)}] {s:.2f},{w:.2f} …", file=sys.stderr)
            elements = fetch(tile)
            json.dump(elements, open(path, "w", encoding="utf-8"))
            # Overpass asks for a gap between queries. Honour it: being rate
            # limited halfway through costs far more than this does.
            time.sleep(3)
        for el in elements:
            merged[f"{el.get('type')}/{el.get('id')}"] = el

    print(f"  {len(merged)} unique elements across all tiles", file=sys.stderr)
    return list(merged.values())


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


# Names that identify nothing. Matched after folding away diacritics and case,
# so "Biserica ortodoxă" and "BISERICĂ" both land here. Anything longer — a
# dedication, a village in the name itself — is left alone.
_GENERIC_NAMES = {
    "biserica", "biserici", "biserica ortodoxa", "biserica ortodoxa romana",
    "biserica de lemn", "capela", "manastire", "manastirea", "schit",
    "troita", "cruce", "catedrala", "paraclis", "biserica noua",
    "biserica veche", "church", "orthodox church",
}


def _is_generic(name: str) -> bool:
    return hram._fold(name) in _GENERIC_NAMES


def _within(el: dict, s: float, w: float, n: float, e: float) -> bool:
    pos = coords(el)
    return pos is not None and s <= pos[0] <= n and w <= pos[1] <= e


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
    locality = tags.get("troita:locality")

    # A quarter of the churches OSM knows about carry no name, and another
    # thousand are called nothing but "Biserică". Both were useless: the first
    # were dropped outright, the second produced screens of identical labels.
    # The settlement they stand in, attached by extract_pbf, is the missing
    # half — "Biserică — Curtici" locates a church, "Biserică" does not.
    #
    # Never a guessed dedication. If OSM does not say which saint a church is
    # named for, neither do we.
    if not name:
        if is_wayside:
            name = f"Troiță — {locality}" if locality else "Troiță"
        elif locality:
            name = f"Biserică — {locality}"
        else:
            return None
    elif locality and _is_generic(name):
        name = f"{name} — {locality}"

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
    "id", "name", "search_fold", "kind", "denomination", "lat", "lon",
    "patron", "feast_day",
    "year_built", "history", "photo_ref", "priority",
    "address", "wikidata", "source", "verified", "updated_at", "deleted",
]


def add_search_fold(rows: list[dict]) -> list[dict]:
    """Precompute the diacritic-free haystack each row is searched against.

    SQLite has no unaccent, so `name LIKE '%voronet%'` cannot match
    "Voroneț" — and nobody types ț or ă on a phone keyboard. Materialising the
    folded text at build time is what makes the obvious query work; doing it at
    read time would mean pulling all thirteen thousand names into Dart on every
    keystroke.

    Name, hram and address all go in, so "Parascheva" finds a church dedicated
    to her and "Curtici" finds the ones in that village.
    """
    for r in rows:
        raw = " ".join(
            p for p in (r.get("name"), r.get("patron"), r.get("address")) if p
        )
        folded = hram._fold(raw)
        # _fold drops everything outside a-z0-9, which empties the field for the
        # couple of dozen Cyrillic names the border margin drags in. Falling
        # back to the lowercased original keeps them findable by someone who
        # can type them, instead of making them unsearchable.
        r["search_fold"] = folded or raw.lower()
    return rows

FEAST_COLUMNS = [
    "id", "month_day", "movable_key", "name", "short_name", "rank", "kind",
    "note", "dezlegare", "source", "verified",
]


# Moveable feasts that open a day's line in the published calendar. On those
# days the line reads "<moveable feast>; <the saints of the date>", and only the
# second half belongs in a table keyed by MM-DD. Matched as prefixes of a
# segment, never anywhere in it: "Sf. Mironosiță Maria a lui Cleopa" is the
# fixed saint of 23 May and must survive, though it contains "Mironosiță".
MOVEABLE_PREFIXES = (
    "Sf. și Marea ", "Sfânta și Marea ", "Sfintele Paști", "Învierea Domnului",
    "A doua zi de Paști", "A treia zi de Paști", "Izvorul Tămăduirii",
    "Înjumătățirea praznicului", "Odovania Înjumătățirii",
    "Odovania praznicului Învierii", "Odovania praznicului Înălțării",
    "Înălțarea Domnului", "Ziua Eroilor", "Pogorârea Duhului Sfânt",
    "Sfânta Treime", "Ziua Sfintei Treimi", "Sfântul Duh", "Ziua Sfântului Duh",
    "Duminica", "Sâmbăta lui Lazăr", "Intrarea Domnului în Ierusalim", "Floriile",
    "Lăsatul secului", "Sâmbăta morților", "Sâmbăta Sf. Teodor",
    "Săptămâna Luminată", "Vinerea Izvorului",
)


def _moveable_window(year: int):
    """From the Triodion's start to the Monday after All Saints: every date in
    it can carry a feast that belongs to Pascha rather than to the date."""
    from engine_port import pascha
    from datetime import timedelta
    p = pascha(year)
    return p - timedelta(days=70), p + timedelta(days=57)


def _strip_moveable(name: str) -> tuple[str, bool]:
    """Drop leading moveable-feast segments. Returns (rest, stripped)."""
    parts = [x.strip() for x in name.split(";")]
    dropped = False
    while parts and parts[0].startswith(MOVEABLE_PREFIXES):
        parts.pop(0)
        dropped = True
    return "; ".join(p for p in parts if p), dropped


MOVEABLE_STRIPPED: list[str] = []


# Every date whose rank could only be read off a Sunday row in the years
# scraped so far. Reported at the end of a build, because each one is a guess
# until a year puts that date on a weekday.
SUNDAY_ONLY_RANKS: list[str] = []


def _settled_rank(entry: dict, curated_row: tuple | None) -> str:
    """The scraped rank, unless it was read off a Sunday and nothing confirms it.

    On a weekday the row class is decisive. On a Sunday it is not, and the
    scraper falls back to treating `†)` as red — right for Sf. Nicolae and the
    Archangels, guesswork for the rest. With only a Sunday reading available:
    an independently curated rank wins; failing that, `†)` keeps its weekday
    meaning, cruce albastră. Nothing is promoted to red without evidence.
    """
    rank = entry.get("rank", "simplu")
    if entry.get("_rank_basis") != "sunday" or rank != "cruce_rosie":
        return rank
    SUNDAY_ONLY_RANKS.append(entry.get("month_day", "?"))
    if curated_row is not None and curated_row[9] in ("manual", "calendar-ro"):
        return curated_row[5]
    return "cruce_albastra"


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
                _settled_rank(entry, None), None,
                "; ".join(entry.get("notes", [])) or None, None, "scraped", 1,
            ))
        else:
            old_row = rows[idx]
            rows[idx] = (
                old_row[0], month_day, None, name, _short(name),
                _settled_rank(entry, old_row), old_row[6],
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
    dest = os.path.join(HERE, "..", "assets", "sinaxar")

    # assets/sinaxar/ is the source of truth; the scraper's per-day folders are
    # only a download cache, and are not committed. Without this fallback a
    # fresh clone would rebuild the seed with no image references at all — the
    # 447 files sitting in assets/ would be invisible to the app, because the
    # map from day to filename used to be read only from the cache.
    if not os.path.isdir(src_root):
        installed: dict[str, list[str]] = {}
        if os.path.isdir(dest):
            for flat in sorted(os.listdir(dest)):
                day, sep, _ = flat.partition("__")
                if sep and len(day) == 5 and day[2] == "-":
                    installed.setdefault(day, []).append(flat)
        print(f"  images: scraper cache absent, read {sum(map(len, installed.values()))} "
              f"from assets/sinaxar/")
        return installed

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
            # The feasts table is keyed by MM-DD and shared by every year, but
            # a rank read off a Sunday row is a reading of that year's weekday:
            # Sundays carry the feast class whether or not the saint is a
            # red-letter one, so the dagger alone decides, and the same saint
            # reads differently on a Monday. Keeping "the last year scraped"
            # let 2026's Sundays leak into every other year. Prefer a weekday
            # reading from any year; among equals, the most recent.
            basis = "sunday" if "saptamana" in (d.get("row_class") or "") else "weekday"

            # A second, stronger preference: a year in which this date is
            # outside the Pascha-dependent window. Inside it the line can start
            # with a moveable feast, and keeping "the last year scraped" stored
            # "Înălțarea Domnului" as a praznic on 21 May — every year — because
            # that is where it fell in 2026. Outside the window the line holds
            # only the saints of the date.
            from datetime import date as _date
            mm, dd = int(d["month_day"][:2]), int(d["month_day"][3:])
            try:
                lo, hi = _moveable_window(year)
                inside = lo <= _date(year, mm, dd) <= hi
            except ValueError:            # 29 February in a common year
                inside = False
            score = (1 if inside else 0, 1 if basis == "sunday" else 0)

            current = published.get(d["month_day"])
            if current is None or score <= current["_score"]:
                published[d["month_day"]] = {
                    **d, "_rank_basis": basis, "_score": score, "_inside": inside}
            override_rows.append((
                year, d["month_day"], d.get("fast"),
                "; ".join(d.get("notes", [])) or None,
                None, None, None, None, None, None,
            ))
    from scrape_calendar import rank_of
    for month_day, entry in published.items():
        if not entry["_inside"]:
            continue
        rest, stripped = _strip_moveable(entry.get("name") or "")
        if not stripped:
            continue
        MOVEABLE_STRIPPED.append(month_day)
        # The row's class and leading dagger described the moveable feast, so
        # the rank is re-read from what remains, as an ordinary weekday line
        # would be. An empty remainder hands the date to the menologion.
        entry["name"] = re.sub(r"^\s*(\(†\)|†\)|†)\s*", "", rest).strip()
        entry["rank"] = rank_of(rest, "normal") if rest else "simplu"
        entry["_rank_basis"] = "weekday"
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
        # The years the published calendar covers. Beyond them the app falls
        # back to the computed engine, and it reads this to say so rather than
        # presenting a computed dezlegare with the same confidence as a
        # published one.
        "published_years": ",".join(
            str(y) for y in sorted({r[0] for r in override_rows})),
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

    # The published calendar is what makes dezlegări right. Say loudly how far
    # it reaches, because the day it runs out nothing breaks — the app quietly
    # falls back to the engine and gets a fifth of the fast days wrong.
    years = sorted({r[0] for r in override_rows})
    if years:
        last = years[-1]
        print(f"    published years  {', '.join(map(str, years))}")
        this_year = datetime.now(timezone.utc).year
        if last <= this_year:
            print(f"WARNING: published calendar ends 31 December {last}. Scrape "
                  f"{last + 1}:  python3 tool/scrape_calendar.py --year "
                  f"{last + 1} --months")
    if MOVEABLE_STRIPPED:
        print(f"    moveable feasts stripped from {len(MOVEABLE_STRIPPED)} fixed dates "
              f"(no year had them outside Pascha's window yet)")
    if SUNDAY_ONLY_RANKS:
        print(f"NOTE: {len(SUNDAY_ONLY_RANKS)} red-cross ranks were read only off a "
              f"Sunday and settled from curated data or downgraded: "
              f"{', '.join(sorted(set(SUNDAY_ONLY_RANKS)))}. Scraping another year "
              f"resolves them.")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--area", default="bucuresti-ilfov", choices=sorted(AREAS))
    ap.add_argument("--bbox", help="south,west,north,east — overrides --area")
    ap.add_argument("--out", default=os.path.join(
        HERE, "..", "android", "app", "src", "main", "assets", "seed", "churches.db"))
    ap.add_argument("--offline", action="store_true", help="skip Overpass, curated rows only")
    ap.add_argument("--elements",
                    help="read an Overpass-shaped elements array from this file "
                         "instead of querying — see extract_pbf.py, which is the "
                         "fast path for anything country-sized")
    ap.add_argument("--all-denominations", action="store_true")
    ap.add_argument("--cache", default=os.path.join(HERE, ".overpass-cache.json"))
    args = ap.parse_args()

    bbox = tuple(float(x) for x in args.bbox.split(",")) if args.bbox else AREAS[args.area]

    rows: list[dict] = []
    if not args.offline:
        span = max(bbox[2] - bbox[0], bbox[3] - bbox[1])
        if args.elements:
            print(f"reading elements from {args.elements}", file=sys.stderr)
            elements = json.load(open(args.elements, encoding="utf-8"))
            # A local extract covers the whole country; the bbox still applies
            # so that --area cluj against a national file does what it says.
            s, w, n, e = bbox
            before = len(elements)
            elements = [el for el in elements if _within(el, s, w, n, e)]
            if len(elements) != before:
                print(f"  {before - len(elements)} outside {bbox}", file=sys.stderr)
        elif span > TILE_THRESHOLD_DEG:
            print(f"querying Overpass for {bbox} in tiles …", file=sys.stderr)
            elements = fetch_tiled(bbox, args.cache + ".tiles")
        elif os.path.exists(args.cache):
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
    #
    # Compared against a spatial bucket rather than against every row kept so
    # far. The exhaustive version is fine for the 20 rows of Bucharest and
    # quadratic everywhere else — at country scale it is some 400 million
    # haversine calls, which does not finish in any useful time. Bucketing by
    # a hundredth of a degree (~1.1 km, comfortably wider than the 80 m radius)
    # and checking only the nine surrounding buckets gives the same answer.
    rows.sort(key=lambda r: (-r["priority"], r["id"]))
    buckets: dict[tuple[int, int], list[dict]] = {}
    kept: list[dict] = []
    for r in rows:
        by, bx = int(r["lat"] * 100), int(r["lon"] * 100)
        near = (
            candidate
            for dy in (-1, 0, 1)
            for dx in (-1, 0, 1)
            for candidate in buckets.get((by + dy, bx + dx), ())
        )
        if any(haversine_m(r["lat"], r["lon"], k["lat"], k["lon"]) < 80
               and (hram._fold(r["name"]) == hram._fold(k["name"])
                    or (_distinctive(r["name"]) and
                        _distinctive(r["name"]) == _distinctive(k["name"])))
               for k in near):
            continue
        kept.append(r)
        buckets.setdefault((by, bx), []).append(r)

    kept = add_search_fold(kept)
    write_sqlite(kept, args.out, bbox, args.bbox or args.area)
    unverified = sum(1 for r in kept if not r["verified"])
    if unverified:
        print(f"NOTE: {unverified}/{len(kept)} rows are unverified — review before shipping.")


if __name__ == "__main__":
    main()
