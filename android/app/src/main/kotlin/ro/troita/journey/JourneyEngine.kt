package ro.troita.journey

import android.content.Context
import android.location.Location
import android.util.Log
import ro.troita.TroitaConfig
import ro.troita.data.Church
import ro.troita.data.ChurchStore
import ro.troita.geofence.Geo
import ro.troita.notify.ChurchNotifier

/**
 * In-process proximity detection for journey mode.
 *
 * OS geofences are the wrong tool at driving speed: ENTER latency is routinely
 * tens of seconds to minutes, and a transition is only detected if a location
 * fix happens to land inside the circle. At 90 km/h a 300 m radius is occupied
 * for about 24 seconds, so passive geofencing silently misses churches. Here we
 * hold candidates in memory and test every fix ourselves, which is exact.
 */
class JourneyEngine(private val context: Context) {

    private var candidates: List<Church> = emptyList()
    private var candidateCenter: Location? = null
    private val inside = mutableSetOf<String>()

    var lastCount: Int = 0
        private set

    fun onLocation(location: Location): List<Church> {
        refreshCandidatesIfNeeded(location)
        if (candidates.isEmpty()) return emptyList()

        // Widen the trigger circle by however far we travel between fixes, so a
        // fast approach can't step straight over a small radius.
        val speed = if (location.hasSpeed()) location.speed.toDouble() else 0.0
        val padding = speed * (TroitaConfig.JOURNEY_INTERVAL_MS / 1000.0) *
            TroitaConfig.JOURNEY_SPEED_PADDING_FACTOR

        val hits = mutableListOf<Church>()
        val stillInside = mutableSetOf<String>()

        for (church in candidates) {
            val d = Geo.distanceM(location.latitude, location.longitude, church.lat, church.lon)
            val trigger = (church.geofenceRadiusM ?: 350) + padding
            if (d > trigger) continue

            stillInside.add(church.id)
            // Only fire on the transition into the circle, not on every fix.
            if (church.id in inside) continue
            if (ChurchStore.recentlyNotified(context, church.id)) continue

            val withDistance = church.copy(distanceM = d)
            ChurchNotifier.notify(context, withDistance, mode = "journey")
            ChurchStore.recordEncounter(context, church.id, "journey")
            hits.add(withDistance)
        }

        inside.clear()
        inside.addAll(stillInside)
        lastCount = candidates.size
        return hits
    }

    private fun refreshCandidatesIfNeeded(location: Location) {
        val center = candidateCenter
        val moved = center == null || Geo.distanceM(
            center.latitude, center.longitude, location.latitude, location.longitude
        ) > TroitaConfig.JOURNEY_REFRESH_DISTANCE_M

        if (!moved) return
        candidates = ChurchStore.nearest(
            context, location.latitude, location.longitude,
            TroitaConfig.JOURNEY_CANDIDATE_LIMIT, maxRadiusM = 50_000.0,
        )
        candidateCenter = location
        Log.i(TAG, "journey candidates refreshed: ${candidates.size}")
    }

    private companion object {
        const val TAG = "JourneyEngine"
    }
}
