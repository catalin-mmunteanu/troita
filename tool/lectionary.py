#!/usr/bin/env python3
"""Apostolul și Evanghelia de la Liturghie, pentru fiecare zi (2026-2030).

    python3 tool/lectionary.py           # writes assets/data/lecturi.json
    python3 tool/lectionary.py --check   # fails if the file is stale or the BOR Sundays drift

The pericope tables (tool/lectionary_tables.json) come from orthocal (MIT,
Brian Glass): the Byzantine-Greek lectionary. The rules below place them on
the Romanian calendar:

- Weekdays: the movable cycle by distance from Pascha, with the Lukan jump
  (Luke begins on the Monday after the Sunday after the Elevation of the
  Cross) and, after Theophany, the jump into the next Paschal cycle. The
  Apostol keeps its own continuous course.
- Sundays: each one is "Duminica a N-a după Rusalii" and reads both the
  Apostol and the Gospel of that numbered Sunday. N follows the Greek
  numbering: the October-December windows (Oct 11-17 the Sower, Oct 30-Nov 5
  the rich man and Lazarus, Nov 24-30 the rich young ruler, Dec 1-3, Dec 4-10,
  Dec 11-17) and, between Theophany and the Triodion, the Lukan Sundays left
  unread, then Matthew 16 and the Canaanite woman. In the Greek usage the
  Apostol stays on its own course; in the Romanian calendar it goes with the
  Gospel. Checked against every Sunday of the published BOR calendar
  2026-2027 (tool/scraped): every reading matches once ROMANIAN_BOUNDS
  fixes four verse boundaries, except 5 errors of the source
  (BOR_SOURCE_ERRORS).
- The Sundays around the great feasts (before and after the Elevation,
  the Forefathers, before and after Nativity, before and after Theophany)
  have their own readings.
- Fixed feasts of rank praznic or cruce roșie (test/golden) read their own
  pericopes when the tables have them. On a Sunday this holds for the Lord's
  and the Theotokos' feasts and for saints outside the Paschal cycle (BOR:
  Arhanghelii 8 Nov 2026, Sf. Nicolae 6 Dec 2026), not for 29 August.
  Romanian saints the Greek tables lack (Sf. Parascheva, Sf. Dimitrie
  Basarabov) keep the readings of the day.
- No Liturgy, so no readings: Great Lent Monday-Friday (Buna Vestire
  excepted), Wednesday and Friday of the Cheese Week, Holy Friday.
"""
import datetime as dt
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
sys.path.insert(0, HERE)
import engine_port as EP  # noqa: E402

OUT = os.path.join(ROOT, "assets", "data", "lecturi.json")
TABLES = json.load(open(os.path.join(HERE, "lectionary_tables.json"), encoding="utf-8"))
GOLD = {r[0]: r for r in json.load(open(os.path.join(ROOT, "test", "golden", "engine-2026-2030.json")))["days"]}
# Pericope boundaries that differ in the Romanian usage, as printed in the BOR
# calendar 2026-2027 (Greek table range -> Romanian range).
ROMANIAN_BOUNDS = {
    ("Mc", 9, 17, 9, 31): ("Mc", 9, 17, 9, 32),    # Duminica a IV-a din Post
    ("In", 7, 37, 7, 52): ("In", 7, 37, 7, 53),    # Rusaliile
    ("Mt", 21, 33, 21, 42): ("Mt", 21, 33, 21, 44),  # a XIII-a după Rusalii; Sf. Ștefan
    ("Mt", 22, 2, 22, 14): ("Mt", 22, 1, 22, 14),   # a XIV-a după Rusalii
}
for _table in TABLES["movable"], TABLES["fixed"]:
    for _key, _pericopes in _table.items():
        _table[_key] = [[list(ROMANIAN_BOUNDS.get(tuple(r), r)) for r in per] for per in _pericopes]
BIBLE = json.load(open(os.path.join(ROOT, "assets", "data", "biblia_nt.json"), encoding="utf-8"))
BOOK_NAME = {b["id"]: b["name"] for b in BIBLE["books"]}
BOOK_NAME["Fa"] = "Faptele Apostolilor"
YEARS = range(2026, 2031)
ONE = dt.timedelta(days=1)


def mov(p, kind):
    return TABLES["movable"].get(f"{p}/{kind}")


def fix(d, kind):
    return TABLES["fixed"].get(f"{d.month:02d}-{d.day:02d}/{kind}")


def wd(d):
    return (d.weekday() + 1) % 7  # 0 = Sunday ... 6 = Saturday


def sun_after(d): return d + dt.timedelta(days=(7 - wd(d)) or 7)
def sun_before(d): return d - dt.timedelta(days=wd(d) or 7)
def sat_after(d): return d + dt.timedelta(days=(6 - wd(d)) % 7 or 7)
def sat_before(d): return d - dt.timedelta(days=(wd(d) + 1) % 7 or 7)


LUKAN_WINDOWS = ((10, 11, 10, 17, 4), (10, 30, 11, 5, 5), (11, 24, 11, 30, 13),
                 (12, 1, 12, 3, 14), (12, 4, 12, 10, 10), (12, 11, 12, 17, 11))
# Only Sf. Andrei (cruce roșie) claims a Lukan Sunday in the Romanian calendar;
# Sf. Luca and Sf. Matei do not (BOR 2026: 18 Oct is the 20th Sunday, Nain).
LUKAN_OVERRIDE = ((11, 30),)
INTERP = ((None, 12), (None, 15), (None, 14), ("matthew", 16), ("matthew", 15))
GREAT_FIXED = {(1, 1), (1, 6), (2, 2), (3, 25), (8, 6), (8, 15), (9, 8), (9, 14), (11, 21), (12, 25)}
# Floating feasts (orthocal FloatIndex).
F_SAT_BEFORE_ELEV, F_SUN_BEFORE_ELEV, F_SAT_AFTER_ELEV, F_SUN_AFTER_ELEV = 1006, 1007, 1008, 1009
F_FOREFATHERS, F_SAT_BEFORE_NAT, F_SUN_BEFORE_NAT, F_EVE_NAT, F_SUN_BEFORE_NAT_EVE = 1010, 1011, 1012, 1014, 1016
F_SAT_AFTER_NAT, F_SUN_AFTER_NAT, F_SAT_BEFORE_THEO, F_SUN_BEFORE_THEO = 1019, 1021, 1022, 1024
F_EVE_THEO, F_SUN_BEFORE_THEO_EVE, F_SAT_AFTER_THEO, F_SUN_AFTER_THEO = 1026, 1028, 1029, 1030
F_ANNUNCIATION, F_LEAVETAKING_THEO = 1037, 1038


class Year:
    """From one Zacchaeus Sunday (Pascha - 77) to the next."""

    def __init__(self, y):
        self.y = y
        self.P, self.NP = EP.pascha(y), EP.pascha(y + 1)
        self.elev = dt.date(y, 9, 14)
        self.sun_after_elev = sun_after(self.elev)
        self.sun_before_elev = sun_before(self.elev)
        self.luke_monday = self.sun_after_elev + ONE
        self.jump = (49 + 1 + 7 * 17) - self.pd(self.luke_monday)
        self.first_sun_luke = self.sun_after_elev + 7 * ONE
        self.nat = dt.date(y, 12, 25)
        self.forefathers = self.nat - dt.timedelta(days=14 - ((7 - wd(self.nat)) % 7))
        self.theo = dt.date(y + 1, 1, 6)
        self.sun_after_theo = sun_after(self.theo)
        self.sat_before_theo = sat_before(self.theo)
        self.triodion = self.NP - dt.timedelta(days=70)
        self._luke = self._interp = None

    def pd(self, d):
        return (d - self.P).days

    def lukan_numbers(self):
        if self._luke is None:
            at = lambda m, d: dt.date(self.y, m, d)  # noqa: E731
            windows = [(at(a, b), at(c, e), n) for a, b, c, e, n in LUKAN_WINDOWS]
            reserved = {n for *_, n in windows}
            overrides = {at(m, d) for m, d in LUKAN_OVERRIDE}
            out, seq, d = {}, 1, self.first_sun_luke
            while d <= self.forefathers:
                n = next((n for s, e, n in windows if s <= d <= e), None)
                if n is None:
                    while seq in reserved:
                        seq += 1
                    n, seq = seq, seq + 1
                out[d] = None if d in overrides else n
                d += 7 * ONE
            self._luke = out
        return self._luke

    def interpolation(self):
        """Sundays between Theophany and the Triodion -> (book, n)."""
        if self._interp is None:
            n = (self.triodion - self.sun_after_theo).days // 7
            lead = []
            if wd(self.theo + 8 * ONE) == 0:
                n, lead = n - 1, [("float", F_SUN_AFTER_THEO)]
            used = {v for v in self.lukan_numbers().values() if v}
            pool = [e for e in INTERP if e[0] == "matthew" or e[1] not in used]
            chosen = sorted(pool[:max(n - 2, 0)], key=lambda e: (e[0] == "matthew", e[1]))
            out, d = {}, self.sun_after_theo + 7 * ONE
            for e in lead + chosen:
                out[d], d = e, d + 7 * ONE
            self._interp = (out, n >= 4)
        return self._interp


_years = {}


def year_of(d):
    y = d.year if (d - EP.pascha(d.year)).days >= -77 else d.year - 1
    if y not in _years:
        _years[y] = Year(y)
    return _years[y]


def roman(n):
    out = ""
    for v, s in ((40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")):
        while n >= v:
            out, n = out + s, n - v
    return out


def nth_sunday(n):
    return "Duminica I după Rusalii" if n == 1 else f"Duminica a {roman(n)}-a după Rusalii"


def pair(p):
    # The 28th and 29th Sundays swap Epistles: the Forefathers read Col 3,
    # 4-11 (their own), the ten lepers Col 1, 12-18.
    return mov(245 if p == 252 else p, "E"), mov(p, "G")


def flt(i):
    return mov(i, "E"), mov(i, "G")


def rank(d):
    r = GOLD.get(d.isoformat())
    return r[1] if r else None


def feast(d):
    if (d.month, d.day) == (3, 25):
        return flt(F_ANNUNCIATION)
    if rank(d) in ("praznic", "cruce_rosie") and (fix(d, "G") or fix(d, "E")):
        return fix(d, "E"), fix(d, "G")
    return None


def sunday(d, Y):
    p = Y.pd(d)
    if -70 <= p <= 56:
        return pair(p), None
    if d == Y.sun_before_elev:
        return flt(F_SUN_BEFORE_ELEV), "Duminica dinaintea Înălțării Sfintei Cruci"
    if d == Y.sun_after_elev:
        return flt(F_SUN_AFTER_ELEV), "Duminica după Înălțarea Sfintei Cruci"
    if d == Y.forefathers:
        return flt(F_FOREFATHERS), "Duminica Sfinților Strămoși după trup ai Domnului"
    if Y.nat - 7 * ONE < d < Y.nat:
        return flt(F_SUN_BEFORE_NAT_EVE if d == Y.nat - ONE else F_SUN_BEFORE_NAT), "Duminica dinaintea Nașterii Domnului"
    if Y.nat < d < Y.theo - ONE and d.year == Y.y:
        return flt(F_SUN_AFTER_NAT), "Duminica după Nașterea Domnului"
    if Y.theo - 7 * ONE <= d < Y.theo:
        return flt(F_SUN_BEFORE_THEO_EVE if d == Y.theo - ONE else F_SUN_BEFORE_THEO), "Duminica dinaintea Botezului Domnului"
    if d == Y.sun_after_theo:
        return flt(F_SUN_AFTER_THEO), "Duminica după Botezul Domnului"
    if d < Y.first_sun_luke:
        n = (p - 49) // 7
        return pair(49 + 7 * n), nth_sunday(n)
    if d <= Y.forefathers:
        L = Y.lukan_numbers().get(d)
        return (pair(168 + 7 * L), nth_sunday(17 + L)) if L else (None, None)
    interp, _ = Y.interpolation()
    if d in interp:
        book, n = interp[d]
        if book == "float":
            return flt(n), "Odovania Botezului Domnului"
        return (pair(49 + 7 * n), nth_sunday(n)) if book == "matthew" else (pair(168 + 7 * n), nth_sunday(17 + n))
    return None, None


def weekday(d, Y):
    p = Y.pd(d)
    if wd(d) == 6 and d == sat_after(Y.elev):
        return flt(F_SAT_AFTER_ELEV)
    if d == sat_before(Y.elev):
        return flt(F_SAT_BEFORE_ELEV)
    if d == Y.nat - ONE:
        return flt(F_EVE_NAT)
    if wd(d) == 6 and Y.nat - 7 * ONE < d < Y.nat - ONE:
        return flt(F_SAT_BEFORE_NAT)
    if wd(d) == 6 and Y.nat < d and d.year == Y.y and d < sat_before(Y.theo):
        return flt(F_SAT_AFTER_NAT)
    if wd(d) == 6 and d == Y.sat_before_theo and d < Y.theo - ONE and d.year == Y.y + 1:
        return flt(F_SAT_BEFORE_THEO)
    if d == Y.theo - ONE:
        return flt(F_EVE_THEO)
    if d == sat_after(Y.theo):
        return flt(F_SAT_AFTER_THEO)
    if d == Y.theo + 8 * ONE:
        return flt(F_LEAVETAKING_THEO)
    ep = p if p < 49 + 32 * 7 else (d - Y.NP).days
    if d > Y.sat_before_theo:
        gp = (d - Y.NP).days
    elif d >= Y.luke_monday:
        gp = p + Y.jump
    else:
        gp = p
    return mov(ep, "E"), mov(gp, "G")


def readings(d):
    """-> (apostol, evanghelie, title, why_none); each reading a list of pericopes."""
    Y = year_of(d)
    p = Y.pd(d)
    if -48 <= p <= -9 and 1 <= wd(d) <= 5 and (d.month, d.day) != (3, 25):
        return None, None, None, "Postul Mare: zi fără Liturghie"
    if p in (-53, -51):
        return None, None, None, "Săptămâna Brânzei: zi fără Liturghie"
    if p == -2:
        return None, None, None, "Vinerea Mare: zi fără Liturghie"
    f = feast(d)
    if wd(d) == 0:
        md = (d.month, d.day)
        if f and (md in GREAT_FIXED or (not -70 <= p <= 56 and md != (8, 29))):
            return f[0], f[1], None, None
        if p == -77:  # Zacchaeus, or the Canaanite woman after a long winter
            _, canaanite = year_of(d - 7 * ONE).interpolation()
            if canaanite:
                return mov(168, "E"), mov(168, "G"), nth_sunday(17), None
            return mov(-77, "E"), mov(-77, "G"), "Duminica lui Zaheu", None
        res, title = sunday(d, Y)
        if not res:
            return None, None, None, "fără lectură în tabele"
        return res[0], res[1], title, None
    if f:
        return f[0], f[1], None, None
    E, G = weekday(d, Y)
    return E, G, None, None


def cite(pericope):
    """[[book, c1, v1, c2, v2], ...] -> 'Luca 8, 41-56; 9, 1'."""
    out, book, ch = [], None, None
    for b, c1, v1, c2, v2 in pericope:
        rng = f"{v1}" if (c1, v1) == (c2, v2) else (f"{v1}-{v2}" if c1 == c2 else f"{v1} - {c2}, {v2}")
        if b != book:
            out.append(f"{BOOK_NAME[b]} {c1}, {rng}")
        elif c1 != ch:
            out.append(f"{c1}, {rng}")
        else:
            out[-1] += f", {rng}"
        book, ch = b, c2
    return "; ".join(out)


def build():
    days = {}
    d = dt.date(YEARS[0], 1, 1)
    while d.year in YEARS:
        E, G, title, why = readings(d)
        if why or not G:
            days[d.isoformat()] = {"none": why or "fără Evanghelie în tabele"}
        else:
            day = {"ev": G[0], "evCite": cite(G[0])}
            if E:
                day["ap"], day["apCite"] = E[0], cite(E[0])
            if title:
                day["title"] = title
            days[d.isoformat()] = day
        d += ONE
    return {
        "about": "Apostolul și Evanghelia de la Liturghie, pe zile. Generat de tool/lectionary.py; textul în assets/data/biblia_nt.json. Rânduiala: tabelele orthocal (MIT), puse pe calendarul BOR și verificate pe duminicile calendarului publicat 2026-2027.",
        "years": [YEARS[0], YEARS[-1]],
        "days": days,
    }


# --- check against the published BOR Sundays ----------------------------------------

RO_BOOK = {"matei": "Mt", "marcu": "Mc", "luca": "Lc", "ioan": "In", "fapte": "Fa", "romani": "Rom",
           "i corinteni": "1Co", "ii corinteni": "2Co", "galateni": "Gal", "efeseni": "Ef", "filipeni": "Flp",
           "coloseni": "Col", "i tesaloniceni": "1Tes", "ii tesaloniceni": "2Tes", "i timotei": "1Tim",
           "ii timotei": "2Tim", "tit": "Tit", "filimon": "Flm", "evrei": "Evr", "iacob": "Iac", "iacov": "Iac",
           "i petru": "1Pt", "ii petru": "2Pt", "i ioan": "1In", "iuda": "Iuda"}
# Where the published calendar is wrong: 11 Oct 2026 repeats the next Sunday's
# readings under its own (correct) title; All Saints is printed "Matei X, 32-35";
# 29 Aug 2027 has the feast's Gospel in the Apostol field.
BOR_SOURCE_ERRORS = {("2026-10-11", "E"), ("2026-10-11", "G"), ("2026-06-07", "G"), ("2027-06-27", "G"),
                     ("2027-08-29", "E")}


def _roman(s):
    v = {"I": 1, "V": 5, "X": 10, "L": 50}
    return sum(-v[c] if i + 1 < len(s) and v[s[i + 1]] > v[c] else v[c] for i, c in enumerate(s))


def _parse_ro(c):
    m = re.match(r"^((?:I{1,3}\s+)?[A-Za-zăâîșț ]+?)\s+([IVXL]+)\s*,\s*(\d+)(?:\s*-\s*(\d+))?", c or "")
    if not m or m.group(1).strip().lower() not in RO_BOOK:
        return None
    return RO_BOOK[m.group(1).strip().lower()], _roman(m.group(2)), int(m.group(3)), int(m.group(4) or m.group(3))


def check_bor():
    """The first range of each BOR Sunday reading must lie inside ours."""
    import glob
    bad, n = [], 0
    for f in sorted(glob.glob(os.path.join(HERE, "scraped", "month-20*.json"))):
        y, m = map(int, os.path.basename(f)[6:13].split("-"))
        last = (dt.date(y + (m == 12), m % 12 + 1, 1) - ONE).day
        suns = [dt.date(y, m, x) for x in range(1, last + 1) if wd(dt.date(y, m, x)) == 0]
        for d, s in zip(suns, json.load(open(f, encoding="utf-8"))["sundays"]):
            E, G, _, _ = readings(d)
            for kind, ours, theirs in (("E", E, s.get("apostol")), ("G", G, s.get("evanghelie"))):
                t = _parse_ro(theirs)
                if not t or (d.isoformat(), kind) in BOR_SOURCE_ERRORS:
                    continue
                n += 1
                b, c, v1, v2 = t
                inside = any(pb == b and (pc1, pv1) <= (c, v1) and (c, v2) <= (pc2, pv2)
                             for per in (ours or []) for pb, pc1, pv1, pc2, pv2 in per)
                if not inside:
                    bad.append(f"{d} {kind}: BOR {theirs}, ours {[cite(x) for x in ours or []]}")
    return n, bad


def main():
    doc = build()
    text = json.dumps(doc, ensure_ascii=False, separators=(",", ":")) + "\n"
    n, bad = check_bor()
    if bad:
        print("lectionary: BOR Sundays differ:\n  " + "\n  ".join(bad))
        return 1
    if "--check" in sys.argv:
        if not os.path.exists(OUT) or open(OUT, encoding="utf-8").read() != text:
            print("lectionary: assets/data/lecturi.json is stale; run python3 tool/lectionary.py")
            return 1
    else:
        open(OUT, "w", encoding="utf-8").write(text)
    none = sum(1 for v in doc["days"].values() if "none" in v)
    print(f"lectionary: {len(doc['days'])} days, {none} without Liturgy readings; "
          f"BOR Sundays {n}/{n} match. OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
