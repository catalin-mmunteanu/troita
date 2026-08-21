-- Troița canonical schema.
-- This is the contract shared by: the bundled seed .db, the on-device SQLite
-- mirror, and the future PostGIS-backed API DTO. Change it in one place only.

PRAGMA journal_mode=DELETE;
PRAGMA user_version=1;

CREATE TABLE IF NOT EXISTS churches (
    id                TEXT    PRIMARY KEY,           -- 'osm:node/123456' | 'troita:<uuid>'
    name              TEXT    NOT NULL,
    kind              TEXT    NOT NULL,              -- church|monastery|chapel|cathedral|wayside_cross
    denomination      TEXT,                          -- romanian_orthodox|orthodox|greek_catholic|...
    lat               REAL    NOT NULL,
    lon               REAL    NOT NULL,
    patron            TEXT,                          -- hramul, e.g. 'Sfântul Nicolae'
    feast_day         TEXT,                          -- 'MM-DD', or 'movable:<key>'
    year_built        INTEGER,
    history           TEXT,
    photo_ref         TEXT,                          -- 'asset://churches/x.jpg' | 'https://...'
    geofence_radius_m INTEGER,                       -- NULL => tier default by `kind`
    priority          INTEGER NOT NULL DEFAULT 0,    -- higher = keep in the geofence window first
    address           TEXT,
    wikidata          TEXT,
    source            TEXT    NOT NULL,              -- osm|manual
    verified          INTEGER NOT NULL DEFAULT 0,    -- 1 = human-checked coords + text
    updated_at        TEXT    NOT NULL,              -- ISO8601 UTC
    deleted           INTEGER NOT NULL DEFAULT 0
);

-- Bounding-box prefilter index. Nearest-N = bbox scan + haversine sort in memory,
-- which is sub-millisecond at county scale. Mirrors the server's
-- ST_DWithin(geography) ORDER BY geom <-> point.
CREATE INDEX IF NOT EXISTS idx_churches_lat  ON churches(lat);
CREATE INDEX IF NOT EXISTS idx_churches_bbox ON churches(lat, lon);
CREATE INDEX IF NOT EXISTS idx_churches_live ON churches(deleted, lat, lon);

-- Notification cooldown / visit log. Written by the native background path only.
CREATE TABLE IF NOT EXISTS encounters (
    church_id    TEXT    NOT NULL,
    notified_at  INTEGER NOT NULL,                   -- epoch millis
    mode         TEXT    NOT NULL,                   -- geofence|journey
    dismissed    INTEGER NOT NULL DEFAULT 0,
    opened       INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_encounters ON encounters(church_id, notified_at DESC);

CREATE TABLE IF NOT EXISTS meta (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- Major commemorations. Deliberately not a full 365-day menologion: ~120
-- curated entries covering the Praznice Împărătești, the great saints, and the
-- Romanian ones. Days without an entry render honestly as fasting state only.
--
-- Lives in the same file as `churches` so the native notification path can read
-- both without a second database.
CREATE TABLE IF NOT EXISTS feasts (
    id          TEXT    PRIMARY KEY,       -- 'feast:11-21' | 'feast:mov:ascension'
    month_day   TEXT,                      -- 'MM-DD'; NULL when movable
    movable_key TEXT,                      -- matches FeastCalendar._movable
    name        TEXT    NOT NULL,
    short_name  TEXT,                      -- for the calendar grid and badges
    rank        TEXT    NOT NULL,          -- praznic|cruce_rosie|cruce_neagra|simplu
    kind        TEXT,                      -- domnesc|maica_domnului|sfant|romanesc
    note        TEXT,
    dezlegare   TEXT,                      -- overrides the computed fast level
    source      TEXT    NOT NULL,
    verified    INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_feasts_day ON feasts(month_day);
CREATE INDEX IF NOT EXISTS idx_feasts_mov ON feasts(movable_key);
