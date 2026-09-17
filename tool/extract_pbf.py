#!/usr/bin/env python3
"""Extract churches, monasteries and troițe from a Geofabrik .osm.pbf.

Why this exists
---------------
The Overpass path in build_seed.py works, but at country scale it is the wrong
tool. Fifty tiles against a free, shared, donated service ran at roughly three
and a half minutes each — some three hours, most of it spent queueing behind
other people's queries, and every re-run pays it again.

Geofabrik publishes the whole country as one file, rebuilt daily. Downloading
312 MB once and filtering it locally takes a couple of minutes, needs no rate
limiting, no mirrors, no retry logic, and asks nothing of a service funded by
donations. It is also strictly more complete: Overpass timeouts silently return
partial tiles, whereas a local scan either reads the file or fails loudly.

Usage
-----
    pip install osmium
    python3 tool/extract_pbf.py --download
    python3 tool/build_seed.py --area romania --elements tool/.pbf-elements.json

The output is deliberately shaped exactly like an Overpass `elements` array, so
build_seed's normalise(), merge_curated() and dedup all work unchanged — this
script replaces the transport, not the pipeline.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))

PBF_URL = "https://download.geofabrik.de/europe/romania-latest.osm.pbf"
DEFAULT_PBF = os.path.join(HERE, "romania-latest.osm.pbf")
DEFAULT_OUT = os.path.join(HERE, ".pbf-elements.json")


def wanted(tags) -> bool:
    """The same selection the Overpass query made, so results are comparable.

    Takes osmium's TagList directly and never builds a dict. This is called
    once per object in the file — on the order of a hundred million times for
    Romania — so materialising `dict(obj.tags)` here, as the first version did,
    meant allocating a hundred million dictionaries to discard all but a few
    thousand. That alone was the difference between ~0.1M objects/second and
    a couple of million: the scan was spending essentially all its time in
    allocation rather than in matching.

    `amenity` is read first because almost every object fails on it, and a
    TagList lookup is a scan of the object's own tags.
    """
    amenity = tags.get("amenity")
    if amenity == "place_of_worship":
        return tags.get("religion") == "christian"
    if amenity == "monastery":
        return True
    return tags.get("historic") in ("wayside_cross", "wayside_shrine")


# Settlement types worth naming a church after. `hamlet` is included because
# rural Romania is full of them and a church in a cătun is still best described
# by it; `suburb` and `quarter` only matter inside cities, where they are more
# useful than the city name repeated six hundred times.
PLACE_KINDS = ("city", "town", "village", "hamlet", "suburb", "quarter")

# Past this, the nearest settlement is not where the church is. Deliberately
# generous — Romanian villages are far apart and a church can sit well outside
# the built-up area — but not so generous that a monastery alone on a mountain
# gets labelled with a valley village twenty kilometres away.
MAX_LOCALITY_M = 8000

# Cell size for the nearest-settlement lookup, in degrees. 0.1° is about 11 km,
# comfortably wider than MAX_LOCALITY_M, so the nine cells around a church are
# guaranteed to contain every candidate within range.
_CELL = 0.1


def attach_localities(elements: list[dict], places: list[tuple]) -> int:
    """Tag every element with the settlement it sits in, as `troita:locality`.

    A quarter of the churches in the extract have no name at all, and another
    thousand are called nothing more than "Biserică". Both are real places that
    OSM simply has not labelled, and both are useless on a map: dropping them
    loses a quarter of the country's coverage, and keeping them produces a
    screen of identical labels.

    The settlement they stand in is the missing half of the name, and it is in
    the same file. What this cannot do is invent a dedication — a church named
    from its village is "Biserică — Curtici", never a guess at its hram.

    Comparing every church against every settlement would be some 220 million
    distance calculations, so settlements go into a grid and each church only
    looks at the nine cells around it.
    """
    if not places:
        return 0

    grid: dict[tuple[int, int], list[tuple]] = {}
    for lat, lon, name in places:
        grid.setdefault((int(lat / _CELL), int(lon / _CELL)), []).append((lat, lon, name))

    tagged = 0
    for el in elements:
        pos = el.get("center") or el
        lat, lon = pos.get("lat"), pos.get("lon")
        if lat is None or lon is None:
            continue
        cy, cx = int(lat / _CELL), int(lon / _CELL)

        best_name, best_d2 = None, None
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                for plat, plon, pname in grid.get((cy + dy, cx + dx), ()):
                    # Squared degrees, with longitude scaled for latitude — good
                    # enough to rank candidates, and converted only once at the
                    # end. Romania sits near 45°N where cos(lat) ≈ 0.71.
                    dlat = plat - lat
                    dlon = (plon - lon) * 0.71
                    d2 = dlat * dlat + dlon * dlon
                    if best_d2 is None or d2 < best_d2:
                        best_name, best_d2 = pname, d2

        if best_name is None:
            continue
        metres = (best_d2 ** 0.5) * 111_320
        if metres > MAX_LOCALITY_M:
            continue
        el["tags"]["troita:locality"] = best_name
        tagged += 1
    return tagged


def download(dest: str) -> None:
    import urllib.request

    if os.path.exists(dest):
        age_h = (time.time() - os.path.getmtime(dest)) / 3600
        print(f"  {os.path.basename(dest)} already here ({os.path.getsize(dest)/1e6:.0f} MB, "
              f"{age_h:.0f}h old) — delete it to re-download", file=sys.stderr)
        return

    print(f"  downloading {PBF_URL}", file=sys.stderr)
    tmp = dest + ".part"

    def progress(blocks: int, block_size: int, total: int) -> None:
        if total <= 0:
            return
        done = blocks * block_size
        pct = min(100.0, done * 100.0 / total)
        # \r rather than a line each: this prints a few thousand times.
        sys.stderr.write(f"\r  {pct:5.1f}%  {done/1e6:6.0f} / {total/1e6:.0f} MB")
        sys.stderr.flush()

    urllib.request.urlretrieve(PBF_URL, tmp, reporthook=progress)
    sys.stderr.write("\n")
    # Rename only on success, so an interrupted download is never mistaken for
    # a complete file on the next run.
    os.replace(tmp, dest)


def _extract_filtered(osmium, pbf: str, index: str, elements: list[dict]) -> list[dict]:
    """pyosmium 4's FileProcessor, with the filtering pushed down into C++."""
    started = time.time()
    seen = skipped = 0

    places: list[tuple] = []

    processor = (
        osmium.FileProcessor(pbf)
        # Way geometries need every node's location, so the cache must see the
        # nodes; the filters below only decide what reaches Python.
        .with_locations(index)
        .with_filter(osmium.filter.EmptyTagFilter())
        # `place` rides along so settlements come out of the same pass — a
        # second scan for them would double the runtime for nothing.
        .with_filter(osmium.filter.KeyFilter("amenity", "historic", "place"))
    )

    for obj in processor:
        seen += 1
        if seen % 20_000 == 0:
            rate = seen / max(time.time() - started, 0.001)
            sys.stderr.write(
                f"\r  {seen:>8,} tagged objects  "
                f"{rate/1000:.0f}k/s  found {len(elements)}"
            )
            sys.stderr.flush()

        if obj.tags.get("place") in PLACE_KINDS:
            name = obj.tags.get("name") or obj.tags.get("name:ro")
            where = getattr(obj, "location", None)
            if name and where is not None:
                places.append((where.lat, where.lon, name))
            continue

        if not wanted(obj.tags):
            continue

        location = getattr(obj, "location", None)
        if location is not None:
            elements.append({
                "type": "node",
                "id": obj.id,
                "lat": location.lat,
                "lon": location.lon,
                "tags": dict(obj.tags),
            })
            continue

        nodes = getattr(obj, "nodes", None)
        if nodes is None:
            continue  # a relation; see the note at the end of extract()
        try:
            points = [(n.lat, n.lon) for n in nodes if n.location.valid()]
        except osmium.InvalidLocationError:
            points = []
        if not points:
            skipped += 1
            continue
        elements.append({
            "type": "way",
            "id": obj.id,
            "center": {
                "lat": sum(p[0] for p in points) / len(points),
                "lon": sum(p[1] for p in points) / len(points),
            },
            "tags": dict(obj.tags),
        })

    sys.stderr.write("\r" + " " * 70 + "\r")
    print(f"  {seen:,} tagged objects reached Python "
          f"in {time.time()-started:.0f}s", file=sys.stderr)
    if skipped:
        print(f"  {skipped} ways had no resolvable location", file=sys.stderr)

    print(f"  {len(places)} settlements collected", file=sys.stderr)
    tagged = attach_localities(elements, places)
    print(f"  {tagged} of {len(elements)} placed in a settlement", file=sys.stderr)
    return elements


def extract(pbf: str, index: str = "flex_mem") -> list[dict]:
    try:
        import osmium
    except ImportError:
        raise SystemExit(
            "pyosmium is not installed.\n"
            "  pip install osmium"
        )

    elements: list[dict] = []

    class Handler(osmium.SimpleHandler):
        def __init__(self) -> None:
            super().__init__()
            self.nodes = 0
            self.ways = 0
            self.skipped_ways = 0
            self.seen = 0
            self.started = time.time()

        def _tick(self) -> None:
            """Progress, because the alternative is a silent ten minutes.

            Romania is on the order of a hundred million nodes and the handler
            is called for every one of them, so this must stay cheap: a counter
            and a modulo, printing a few dozen times over the whole run.
            """
            self.seen += 1
            if self.seen % 2_000_000:
                return
            rate = self.seen / max(time.time() - self.started, 0.001)
            sys.stderr.write(
                f"\r  {self.seen/1e6:5.0f}M objects  "
                f"{rate/1e6:.1f}M/s  "
                f"found {self.nodes + self.ways}"
            )
            sys.stderr.flush()

        def node(self, n) -> None:
            self._tick()
            # The dict is built only for the handful that match.
            if not wanted(n.tags):
                return
            self.nodes += 1
            elements.append({
                "type": "node",
                "id": n.id,
                "lat": n.location.lat,
                "lon": n.location.lon,
                "tags": dict(n.tags),
            })

        def way(self, w) -> None:
            self._tick()
            if not wanted(w.tags):
                return
            tags = dict(w.tags)
            # A church mapped as a building is a closed way; its position is the
            # average of its corners, which is what Overpass's `out center`
            # gives too. Not a true centroid, but for a building footprint the
            # difference is under a metre.
            try:
                lats = [n.lat for n in w.nodes if n.location.valid()]
                lons = [n.lon for n in w.nodes if n.location.valid()]
            except osmium.InvalidLocationError:
                lats, lons = [], []
            if not lats:
                self.skipped_ways += 1
                return
            self.ways += 1
            elements.append({
                "type": "way",
                "id": w.id,
                "center": {"lat": sum(lats) / len(lats), "lon": sum(lons) / len(lons)},
                "tags": tags,
            })

    # Fast path: let C++ throw away the objects we will never want, so the
    # Python callback is entered a few hundred thousand times instead of a
    # hundred million.
    #
    # This is the whole ball game. Most objects in an OSM extract are untagged
    # nodes — pure geometry making up the shape of ways — and in pyosmium's own
    # example they are 85% of the file. Every one of them was crossing the
    # C++/Python boundary to be tested by a Python function and discarded,
    # which is why the first version ran at 0.1M objects/second. EmptyTagFilter
    # and KeyFilter drop them inside the reader, before Python is involved.
    if hasattr(osmium, "FileProcessor") and hasattr(osmium, "filter"):
        return _extract_filtered(osmium, pbf, index, elements)

    handler = Handler()
    # locations=True makes pyosmium resolve every way's node coordinates, which
    # is the only way to get a position for a church mapped as a building.
    #
    # flex_mem holds the node index in RAM — roughly 1 GB for Romania. That is
    # the fast choice and the right default, but on a machine short of memory
    # it turns into swapping, which is far slower than the disk-backed index it
    # was meant to beat. Hence --low-memory.
    handler.apply_file(pbf, locations=True, idx=index)
    sys.stderr.write("\n")

    print(f"  nodes: {handler.nodes}   ways: {handler.ways}", file=sys.stderr)
    if handler.skipped_ways:
        print(f"  {handler.skipped_ways} ways had no resolvable location",
              file=sys.stderr)
    # Relations are not read. A place of worship mapped as a multipolygon
    # relation is rare — a few dozen nationally — and assembling their geometry
    # needs a second pass through an area handler for a fraction of a percent
    # of the rows. Worth revisiting only if a notable monastery turns up missing.
    return elements


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pbf", default=DEFAULT_PBF)
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--download", action="store_true",
                    help=f"fetch {os.path.basename(PBF_URL)} first (312 MB)")
    ap.add_argument("--low-memory", action="store_true",
                    help="keep the node index on disk instead of in ~1 GB of "
                         "RAM — slower, but the right choice if the machine "
                         "would otherwise swap")
    args = ap.parse_args()

    if args.download:
        download(args.pbf)

    if not os.path.exists(args.pbf):
        raise SystemExit(
            f"{args.pbf} not found.\n"
            f"  python3 {os.path.basename(__file__)} --download\n"
            f"  or download {PBF_URL} by hand and pass --pbf"
        )

    started = time.time()
    index = "flex_mem"
    scratch = os.path.join(HERE, ".node-index.dat")
    if args.low_memory:
        index = f"sparse_file_array,{scratch}"

    print(f"scanning {os.path.basename(args.pbf)} "
          f"({os.path.getsize(args.pbf)/1e6:.0f} MB) — "
          f"one pass, no network, expect a few minutes", file=sys.stderr)
    try:
        elements = extract(args.pbf, index)
    finally:
        if args.low_memory and os.path.exists(scratch):
            os.remove(scratch)

    with open(args.out, "w", encoding="utf-8") as fh:
        json.dump(elements, fh, ensure_ascii=False)

    print(f"wrote -> {args.out}", file=sys.stderr)
    print(f"  {len(elements)} elements in {time.time()-started:.0f}s "
          f"({os.path.getsize(args.out)/1e6:.1f} MB)", file=sys.stderr)
    print(f"\nNext: python3 build_seed.py --area romania --elements {args.out}")


if __name__ == "__main__":
    main()
