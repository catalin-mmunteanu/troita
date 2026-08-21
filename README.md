# Troița

Notifies you — a short vibration, optionally a bell — when you pass an Orthodox
church or roadside troiță, and tells you the hram, the year, and the story of
the place.

MVP: Android only, Bucharest + Ilfov, no backend.

---

## The one decision that shapes everything

**Dart is never on the background path.**

The usual Flutter approach to background geofencing is to wake a Dart isolate
from a callback dispatcher. That means spinning up a `FlutterEngine` and
re-registering plugins before you can do anything — several hundred
milliseconds of cold start, and a whole category of OEM-specific failures, in
the exact situation that matters most: the process is dead and the user is
driving past a church right now.

So the split is:

| | Owner |
|---|---|
| Geofence registration, transition handling, church lookup, notification | Kotlin, no Flutter APIs |
| UI, settings, permissions, seed installation | Dart |
| Church data | One SQLite file both sides open |

`TroitaBridge` is the only place they meet, and it carries control-plane calls
only. If the Flutter engine is dead, notifications still work, because nothing
on that path needs Dart.

## The second decision: two modes, not one

OS geofences are the wrong tool at driving speed. An `ENTER` transition is only
detected when a location fix happens to land inside the circle, and Play
services' reporting latency runs from tens of seconds to a couple of minutes.
Here is how long you are actually inside a geofence:

| radius | 50 km/h | 90 km/h | 130 km/h |
|---|---|---|---|
| 200 m | 28.8 s | 16.0 s | 11.1 s |
| 350 m | 50.4 s | 28.0 s | 19.4 s |
| 500 m | 72.0 s | 40.0 s | 27.7 s |

A passive-geofencing-only app will silently miss churches for exactly the users
it was built for. Hence:

- **Journey mode (`Drum`)** — default, and the primary v1 experience. The user
  taps "Pornește drumul"; a foreground service samples location every 8 s and
  does proximity checks in process. Exact, no missed churches, visible
  notification, and it survives every OEM battery manager.
- **Passive mode** — opt-in. OS geofences with a sliding window. Costs almost
  no battery, works without the user doing anything, and is best-effort.

Journey mode needs **no `ACCESS_BACKGROUND_LOCATION`**: a foreground service
started while the app is visible may use location with only the foreground
runtime permission. That means v1 can ship without the Play Console background
location declaration and the review video. See "Play Store" below.

## The sliding window

Android has no equivalent of iOS's significant-location-change API, and polling
for one would defeat the purpose. Instead the window is driven by its own
geofence:

```
BOOT / APP OPEN / COVERAGE EXIT
  └─ fused getCurrentLocation(BALANCED)
     └─ ChurchStore.nearest(lat, lon, limit = 95)
        └─ coverageRadius = distance to outermost × 0.75   (clamped 2–40 km)
           └─ removeGeofences(stale ids only)
              addGeofences(
                ≤95 church circles  → ENTER, r 150–1000 m, NEVER_EXPIRE, resp 0
                 1 "__coverage__"   → EXIT,  r = coverageRadius
              )
              WindowStore.write(centre, radius, ids)

GEOFENCE BROADCAST  (process may be cold)
  GeofencingEvent.fromIntent(intent)
    ├─ hasError() ─ GEOFENCE_NOT_AVAILABLE → markDirty + rebuild
    ├─ EXIT on "__coverage__"  → rebuild around event.triggeringLocation
    └─ ENTER on a church id    → cooldown check (6 h)
                                 ChurchStore.byId          ← plain SQLite
                                 ChurchNotifier.notify     ← no Flutter
                                 recordEncounter

NOTIFICATION TAP
  → MainActivity (singleTop) with EXTRA_CHURCH_ID
  → TroitaBridge.pendingChurchId
  → Dart consumes on resume → ChurchDetailPage
```

Zero polling, zero background location sampling, one wake-up per ~20 km
travelled. From Piața Universității the current seed produces a 23.1 km coverage
circle around 20 churches.

## Android landmines, and where each is handled

| Trap | Handled in |
|---|---|
| Geofence `PendingIntent` **must** be `FLAG_MUTABLE` on API 31+ — immutable fails *silently*, no crash, no log | `GeofenceManager.pendingIntent` |
| A runtime-registered receiver dies with the process; must be manifest-declared | `AndroidManifest.xml` |
| Receiver has ~10 s; `WorkManager` hand-off gets deferred by Doze and the moment passes | `goAsync()` + 9 s timeout |
| One bad region fails the **entire** `addGeofences` batch | radius clamped to 150–1000 m |
| Reboot, Play services update, location toggle all wipe registrations | `SystemEventReceiver`, `WindowStore.dirty` |
| Force-stop kills all broadcasts until the user reopens the app | unfixable; recovery is cheap on next open |
| Notification channel settings are **immutable** after creation | versioned ids, `_v1` suffix |
| Xiaomi Autostart off ⇒ `BOOT_COMPLETED` never fires | `OemGuidance.openAutostart` |
| Samsung "sleeping apps" stops it after a few days | `OemGuidance` + Settings warning |
| `resolveActivity` returns null for vendor screens without package visibility | `<queries>` in the manifest |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` is Play-restricted to a narrow allowlist | uses `ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS` instead |
| Background location must be requested *after* foreground is granted, and opens Settings on API 30+ | `PermissionService` |
| R8 strips manifest-only classes | `proguard-rules.pro` |
| Android 14 needs `FOREGROUND_SERVICE_LOCATION` + type at `startForeground()` | `JourneyForegroundService` |

## Layout

```
tool/                       seed pipeline (also the future server seeder)
  schema.sql                canonical schema = the future API DTO
  build_seed.py             Overpass → clean → merge curated → prepopulated .db
  hram.py                   patron-saint inference from Romanian church names
  curated.json              human overrides (histories, coords, hramuri)

android/app/src/main/
  assets/seed/churches.db   bundled, installed natively on first run
  kotlin/ro/troita/
    TroitaConfig.kt         every tuning knob
    MainActivity.kt
    bridge/TroitaBridge.kt  the only Dart↔Kotlin boundary
    data/ChurchStore.kt     plain SQLite, opened from a cold receiver
    geofence/               GeofenceManager, receivers, WindowStore, Geo
    journey/                foreground service + in-process proximity engine
    notify/                 channels + notification builder
    oem/OemGuidance.kt      vendor battery-manager deep links

lib/
  core/
    models/church.dart          mirrors schema.sql field for field
    models/feast_calendar.dart  Orthodox Pascha + movable hramuri
    data/church_repository.dart the one query contract
    data/local_church_repository.dart
    data/church_sync_service.dart  ← the entire backend migration
    data/photo_resolver.dart       asset:// today, https:// later
    native/troita_native.dart
    permissions/permission_service.dart
  features/  onboarding · home(journey) · nearby · church_detail · history · settings

test/                       feast calendar + repository SQL
```

## Setup

This is the hand-written part of the project, not a full Flutter scaffold. The
generated boilerplate — Gradle wrapper, `local.properties`, launcher mipmaps,
`ios/`, `.metadata` — is missing on purpose. Drop these files over a fresh
scaffold:

```bash
flutter create --org ro.troita --platforms=android troita_scaffold
# copy this tree over troita_scaffold/, keeping its android/gradle*,
# android/app/src/main/res/mipmap-*/ and android/local.properties
```

Then:

```bash
# 1. seed data (offline uses only curated.json; drop --offline to hit Overpass)
cd tool
pip install -r requirements.txt
python3 build_seed.py --area bucuresti-ilfov \
    --out ../android/app/src/main/assets/seed/churches.db

# 2. app
cd ..
flutter pub get
flutter run
flutter test
```

`build_seed.py --offline` currently produces 20 curated Bucharest/Ilfov entries.
Running without `--offline` pulls `amenity=place_of_worship` + `religion=christian`,
plus `historic=wayside_cross` and `historic=wayside_shrine` — the troițe the app
is named after — and overlays the curated rows on top.

> **Every row in `curated.json` is `verified = 0`.** The coordinates are
> approximate and the histories are summaries. Check them against OSM and parish
> sources before shipping; the flag exists so you can hide unverified rows in
> the UI until someone has signed off.

Missing on purpose: the bell sound, church photos, and a release signing config.

For the bell, create `android/app/src/main/res/raw/` and drop in `toaca.ogg`.
`Channels.bellSound()` resolves it by name at runtime, so the app compiles and
runs without it and the "bell" channel simply falls back to vibration only.
Keep the clip under ~2 seconds and quietly normalised — it fires while someone
is driving, and anything longer is startling rather than discreet.

Note that `res/` accepts nothing but resources: every file under it becomes an
identifier, and filenames are restricted to lowercase `a-z`, `0-9` and
underscore. A stray `README.txt` in `res/raw/` fails the build with
`'R' is not a valid file-based resource name character`.

## Play Store

Ship v1 with journey mode only and passive mode's toggle hidden or disabled.
No `ACCESS_BACKGROUND_LOCATION` request means no declaration form, no demo
video, no multi-week review round-trip. The permission is already in the
manifest, so enabling passive mode later is a store-listing change, not a code
change.

When you do enable it, you need: the prominent disclosure *before* the runtime
prompt (`_Disclosure` in `onboarding_page.dart` is written for this), the Data
Safety form, and an unlisted YouTube video showing the disclosure followed by
the system dialog. The justification that fits the policy: notifying the user
about nearby heritage churches is the app's core function and cannot work while
the app is closed without it.

## Hardcoded vs. abstracted

Hardcoded on purpose — county, church content, radius constants, no auth, no
analytics, no moderation UI, no map tiles.

Abstracted, because these are the migration:

1. **`tool/schema.sql` is the contract.** The SQLite table, `Church`,
   `data class Church`, and the future API DTO are the same 19 fields. Change it
   there first, everywhere else follows.
2. **`ChurchSyncService`** — MVP is `BundledSeedSync` (a no-op; the native side
   installs the asset). `RemoteSync` is written and unwired, showing the exact
   call site: `GET /v1/churches?since=…` upserting on stable id, soft deletes as
   `deleted = 1`.
3. **`PhotoResolver`** — `asset://` now, `https://` later, one function.
4. **`ChurchRepository.nearby()`** — the local bbox-prefilter-then-haversine
   implementation returns exactly what
   `ST_DWithin(geom, :point::geography, :r) ORDER BY geom <-> :point` will.

**The rule to lock in now:** the backend is a *sync source*, not a query path.
The geofencing path runs in a dead process with no network guarantee, so the
local mirror stays authoritative forever. Design it that way from day one and
adding PostGIS is additive rather than a rewrite.

Church ids are already `osm:node/123456` / `troita:<slug>`, so they survive the
move to a server without a remap.

## Verification status

Validated by running the logic:

- Orthodox Pascha 2024–2030 against known dates; always a Sunday 2024–2040
- Bounding-box prefilter never excludes a point inside the radius (120-point
  ring test)
- Nearest-N ordering and coverage-radius computation against the real seed
- Seed pipeline round-trips: 20 rows, hram inference, dedupe, curated merge

Not validated — no Flutter/Android toolchain in the authoring environment, so
`flutter analyze`, `flutter test` and `./gradlew assembleDebug` have not been
run. Expect small compile fixes on first build.

## Next

- Verify `curated.json` and flip `verified = 1`
- Run `build_seed.py` against live Overpass for full Bucharest + Ilfov coverage
- Test on a real Xiaomi and a real Samsung, after a reboot, after two idle days
- Instrument: how often does passive mode actually fire before journey mode
  would have? That number decides whether passive mode is worth the Play review.
- iOS: `CLLocationManager` region monitoring, 20-region limit, same coverage
  circle trick, same SQLite file. Roughly 200 lines of Swift behind the same
  `TroitaNative` interface.
