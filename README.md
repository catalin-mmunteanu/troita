# Troița

A Romanian Orthodox calendar for daily use: the saint of the day, the fasting
rules and dezlegări, and — in progress — a map of churches, monasteries and
troițe you can favourite and mark as visited.

Android first. Four tabs: **Calendar · Posturi · Hartă · Profil**.

---

## What was removed, and why it matters

The app began as a proximity notifier — geofences around churches, a foreground
service for driving, notifications when you passed one. That scope is gone.
Deleted: `GeofenceManager`, the broadcast receivers, `JourneyForegroundService`,
the proximity engine, the OEM battery-manager workarounds, and the notification
cooldown log.

The consequences are almost entirely good:

- **`ACCESS_BACKGROUND_LOCATION` is gone**, and with it the Play Console
  declaration, the demo video, and a review round-trip measured in weeks.
- No foreground service, no boot receiver, no `RECEIVE_BOOT_COMPLETED`.
- **No exposure to OEM battery managers** — the single largest source of "it
  stopped working after a few days" on Samsung and Xiaomi.
- Kotlin went from ~1,700 lines to ~500. Dart from ~4,800 to ~3,800.

What survives is the part that was always the most valuable: the church dataset,
the seeding pipeline, and the liturgical engine.

## The liturgical engine

`lib/core/liturgical/` — pure functions of a date. No I/O, no state, no data
source. Everything hangs off the Pascha computus in `FeastCalendar`.

- **Four fasting periods**, including Postul Sfinților Apostoli, whose length
  varies with Pascha and **collapses to zero in ten years between 2020 and
  2100**. Hardcoding date ranges would ship that bug.
- **Per-day fast level**: `none · dairy · fish · wineOil · fast · strict`, with
  the real rules — weekends in Postul Mare, fish on Tue/Thu/Sat/Sun before
  20 December, Ajunul Crăciunului strict, Buna Vestire and Florii fish.
- **All five harți weeks**, including the one crossing the year boundary, plus
  Săptămâna Brânzei as its own `dairy` state.
- **Wed/Fri fasting** outside the periods, relaxed when a feast falls on one —
  praznic brings fish, cruce roșie brings oil and wine.
- **Glas** (1–8) and **voscreasna** (1–11), both cycling from Duminica Tomii.

### Verified against a published calendar

`tool/import_calendar_html.py` parses a month of published calendar HTML and
diffs it against the engine. On January 2026 it reports **31/31 days matching**,
and glas/voscreasna exact on all four Sundays.

That exercise found one real bug: 7 January carries a dezlegare la pește that no
period rule produces. It went into the data as a feast-level override, not into
the rules.

```bash
# paste a month's HTML into tool/raw/2026-MM.html, then:
python3 tool/import_calendar_html.py tool/raw/2026-02.html --year 2026 --month 2 --verify
python3 tool/import_calendar_html.py tool/raw/2026-02.html --year 2026 --month 2 > tool/imported/2026-02.json
```

Imported days become `source = 'calendar-ro'`, `verified = 1`, and take
precedence over the hand-written fallback on name and rank. **January is
verified; the other eleven months are not.** Sending them is one command each.

## Calendar data

Every day of the year carries a commemoration — 366 covered, no gaps.

| Source | Days | Trust |
|---|---|---|
| `calendar-ro` (imported from published HTML) | 31 | verified |
| `manual` (`tool/feasts.json`) | 66 | curated, ranks and dezlegări |
| `menologion` (`tool/menologion.py`) | 282 | written from knowledge — **unverified** |

Ranks: 13 praznice, 37 cruce roșie, 23 cruce neagră, the rest ordinary.

## The colour convention

Romanian printed calendars use a colour language people have read their whole
lives, and it is not decorative — **the rank names *are* the colours**. "Cruce
roșie" and "cruce neagră" mean red cross and black cross.

- **Red** `#C1272D` — praznice, cruce roșie, and every Sunday including the `Du`
  column header
- **Black** `#1B1B1B` — cruce neagră and ordinary days
- **Burgundy fill** — today. An app affordance, not a convention; keeping it
  distinct means red means exactly one thing.
- **Serif throughout the calendar**, sans for the chrome around it. Set via
  `fontFamilyFallback: ['serif']`, so it renders correctly before anyone
  installs Fraunces.

## Layout

```
tool/                     data pipeline
  schema.sql              the contract: seed format = on-device store = future API DTO
  build_seed.py           Overpass → clean → merge curated → prepopulated .db
  menologion.py           366-day fallback commemorations
  feasts.json             curated ranks, dezlegări, movable feasts
  import_calendar_html.py published-calendar importer + engine verifier
  engine_port.py          Python mirror of the Dart engine, for verification only

android/…/kotlin/ro/troita/   ~500 lines, four jobs
  data/ChurchStore.kt     installs the seed database out of assets
  notify/Channels.kt      two channels, split by feast rank
  bridge/TroitaBridge.kt  the only Dart↔Kotlin boundary
  util/Geo.kt             haversine

lib/
  core/liturgical/        the engine — pure functions
  core/data/              repository interfaces + SQLite implementations
  core/native/            typed wrapper over the method channel
  app/                    design tokens, app state
  features/               calendar · fasting · map · profile
test/                     46 tests
```

## Setup

This is the hand-written part, not a full Flutter scaffold. Lay it over one:

```bash
flutter create --org ro.troita --platforms=android troita_scaffold
# copy this tree over it, keeping android/gradle*, android/local.properties
# and android/app/src/main/res/mipmap-*/
```

Version set, all four move together:
**Gradle 8.14.3 · AGP 8.11.1 · Kotlin 2.2.20 · JDK 17**

```bash
python3 tool/build_seed.py --offline --out android/app/src/main/assets/seed/churches.db
flutter pub get
flutter test
flutter run
```

Missing on purpose: fonts (`assets/fonts/README.md`), icons
(`assets/icons/README.md`), church photos, a release signing config.

## When the map lands

Two decisions to make first:

**Tile provider.** `flutter_map` with OSM tiles is free but their usage policy
effectively forbids app use at scale. MapTiler or Stadia need an API key.
Google Maps needs a key and a billing account. This is the only part of the app
that would introduce a runtime network dependency.

**Where user data lives.** Favourites and visited marks must **not** go in
`churches.db` — `ChurchStore.copySeed()` overwrites that file wholesale whenever
a new seed ships. They belong in a separate database that re-seeding never
touches. The schema notes this; the code doesn't exist yet.

## Honest status

The architecture is sound — the data contract, the engine, the narrow native
boundary. The product is a good prototype.

Not done: release signing (still the debug key), R8 (disabled), crash reporting,
CI, widget tests, 282 unverified calendar days, 20 unverified churches,
hardcoded Romanian strings, and Material stand-ins for the lucide icons.
