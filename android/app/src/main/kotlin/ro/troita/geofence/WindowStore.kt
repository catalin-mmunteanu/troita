package ro.troita.geofence

import android.content.Context
import ro.troita.TroitaConfig

/**
 * Persisted state of the active geofence window.
 *
 * Treat "geofences are registered" as soft state: the OS silently drops them on
 * reboot, on a Play services update, when location is toggled, and when the user
 * force-stops the app. This record is what lets us re-assert them cheaply and
 * decide whether a rebuild is even necessary.
 */
object WindowStore {

    private const val K_LAT = "window_lat"
    private const val K_LON = "window_lon"
    private const val K_RADIUS = "window_radius"
    private const val K_IDS = "window_ids"
    private const val K_UPDATED = "window_updated_at"
    private const val K_DIRTY = "window_dirty"
    private const val K_JOURNEY = "journey_active"
    private const val K_PASSIVE = "passive_enabled"
    private const val K_SOUND = "sound_enabled"

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(TroitaConfig.PREFS, Context.MODE_PRIVATE)

    data class Window(
        val lat: Double,
        val lon: Double,
        val radiusM: Double,
        val ids: Set<String>,
        val updatedAt: Long,
        val dirty: Boolean,
    ) {
        val isEmpty: Boolean get() = ids.isEmpty()
    }

    fun read(context: Context): Window {
        val p = prefs(context)
        return Window(
            lat = java.lang.Double.longBitsToDouble(p.getLong(K_LAT, 0L)),
            lon = java.lang.Double.longBitsToDouble(p.getLong(K_LON, 0L)),
            radiusM = java.lang.Double.longBitsToDouble(p.getLong(K_RADIUS, 0L)),
            ids = p.getStringSet(K_IDS, emptySet()) ?: emptySet(),
            updatedAt = p.getLong(K_UPDATED, 0L),
            dirty = p.getBoolean(K_DIRTY, false),
        )
    }

    fun write(context: Context, lat: Double, lon: Double, radiusM: Double, ids: Set<String>) {
        prefs(context).edit()
            .putLong(K_LAT, java.lang.Double.doubleToRawLongBits(lat))
            .putLong(K_LON, java.lang.Double.doubleToRawLongBits(lon))
            .putLong(K_RADIUS, java.lang.Double.doubleToRawLongBits(radiusM))
            .putStringSet(K_IDS, ids)
            .putLong(K_UPDATED, System.currentTimeMillis())
            .putBoolean(K_DIRTY, false)
            .apply()
    }

    fun clear(context: Context) {
        prefs(context).edit()
            .remove(K_LAT).remove(K_LON).remove(K_RADIUS)
            .remove(K_IDS).remove(K_UPDATED).putBoolean(K_DIRTY, false)
            .apply()
    }

    /** Something invalidated our geofences; rebuild at the next opportunity. */
    fun markDirty(context: Context) =
        prefs(context).edit().putBoolean(K_DIRTY, true).apply()

    fun journeyActive(context: Context): Boolean =
        prefs(context).getBoolean(K_JOURNEY, false)

    fun setJourneyActive(context: Context, active: Boolean) =
        prefs(context).edit().putBoolean(K_JOURNEY, active).apply()

    fun passiveEnabled(context: Context): Boolean =
        prefs(context).getBoolean(K_PASSIVE, false)

    fun setPassiveEnabled(context: Context, enabled: Boolean) =
        prefs(context).edit().putBoolean(K_PASSIVE, enabled).apply()

    fun soundEnabled(context: Context): Boolean =
        prefs(context).getBoolean(K_SOUND, false)

    fun setSoundEnabled(context: Context, enabled: Boolean) =
        prefs(context).edit().putBoolean(K_SOUND, enabled).apply()
}
