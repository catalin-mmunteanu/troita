package ro.troita

/**
 * Every tuning knob in one place. These are the values the whole background
 * behaviour hangs off, so keep them here rather than scattered as literals —
 * later they become a remote-config payload without touching call sites.
 */
object TroitaConfig {

    /**
     * Android's hard limit is 100 geofences per app. We keep headroom for the
     * coverage circle and for a few slots of slack, because hitting the limit
     * makes addGeofences() fail for the *whole batch*, not just the overflow.
     */
    const val MAX_CHURCH_GEOFENCES = 95

    /** Request id of the big circle whose EXIT tells us to rebuild the window. */
    const val COVERAGE_ID = "__coverage__"

    /**
     * The coverage circle sits inside the ring of registered churches, so we
     * rebuild slightly before the user reaches the edge of the window.
     */
    const val COVERAGE_SHRINK = 0.75
    const val COVERAGE_MIN_RADIUS_M = 2_000.0
    const val COVERAGE_MAX_RADIUS_M = 40_000.0

    /** Don't notify about the same church twice inside this window. */
    const val ENCOUNTER_COOLDOWN_MS = 6L * 60 * 60 * 1000

    /**
     * Geofence radius floor. Below ~150 m Play services' own docs warn that
     * reliability collapses; below 100 m you will simply miss transitions.
     */
    const val MIN_GEOFENCE_RADIUS_M = 150f
    const val MAX_GEOFENCE_RADIUS_M = 1_000f

    /** Journey mode: active location sampling while the user is driving. */
    const val JOURNEY_INTERVAL_MS = 8_000L
    const val JOURNEY_FASTEST_INTERVAL_MS = 4_000L
    const val JOURNEY_MIN_DISPLACEMENT_M = 20f

    /** Candidates held in memory during a journey, and when to refresh them. */
    const val JOURNEY_CANDIDATE_LIMIT = 400
    const val JOURNEY_REFRESH_DISTANCE_M = 10_000.0

    /**
     * At speed the sampling interval alone can carry you past a small radius,
     * so widen the trigger circle in proportion to how far we travel between
     * fixes. 25 m/s (90 km/h) x 8 s = 200 m of blind spot.
     */
    const val JOURNEY_SPEED_PADDING_FACTOR = 1.2

    /** Notification channels. IDs are versioned: channel settings are immutable. */
    const val CHANNEL_DISCREET = "troita_discreet_v1"
    const val CHANNEL_BELL = "troita_bell_v1"
    const val CHANNEL_JOURNEY = "troita_journey_v1"

    const val PREFS = "troita_prefs"
    const val EXTRA_CHURCH_ID = "ro.troita.extra.CHURCH_ID"
    const val ACTION_GEOFENCE = "ro.troita.action.GEOFENCE"
    const val ACTION_STOP_JOURNEY = "ro.troita.action.STOP_JOURNEY"
}
