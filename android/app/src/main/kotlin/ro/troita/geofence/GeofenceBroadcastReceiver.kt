package ro.troita.geofence

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofenceStatusCodes
import com.google.android.gms.location.GeofencingEvent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull
import ro.troita.TroitaConfig
import ro.troita.data.ChurchStore
import ro.troita.notify.ChurchNotifier

/**
 * The entire background path lives here, in Kotlin, with no Flutter involvement.
 *
 * When the process is dead the OS restarts it and delivers this broadcast. If
 * the handling logic lived in Dart we would have to spin up a FlutterEngine and
 * re-register plugins first — several hundred milliseconds of cold start, and a
 * whole category of OEM-specific failures. Reading SQLite and posting a
 * notification from Kotlin is boring, which is exactly what you want at 2 a.m.
 * on a Xiaomi.
 *
 * Declared statically in the manifest: a runtime-registered receiver dies with
 * the process and would never be called in the case that matters most.
 */
class GeofenceBroadcastReceiver : BroadcastReceiver() {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        val app = context.applicationContext

        // goAsync() buys roughly 10 seconds of guaranteed process lifetime.
        // Do not hand off to WorkManager: Doze will defer the work and the
        // moment the user was driving past the church will be long gone.
        val pending = goAsync()
        scope.launch {
            try {
                withTimeoutOrNull(9_000) { handle(app, event) }
            } catch (e: Exception) {
                Log.e(TAG, "geofence handling failed", e)
            } finally {
                pending.finish()
            }
        }
    }

    private suspend fun handle(context: Context, event: GeofencingEvent) {
        if (event.hasError()) {
            val code = event.errorCode
            Log.w(TAG, "geofence error: ${GeofenceStatusCodes.getStatusCodeString(code)}")
            if (code == GeofenceStatusCodes.GEOFENCE_NOT_AVAILABLE) {
                // Play services restarted / NLP disabled / location toggled.
                // Our registrations are gone; flag it and try once immediately.
                WindowStore.markDirty(context)
                GeofenceManager.rebuild(context, null)
            }
            return
        }

        val ids = event.triggeringGeofences?.map { it.requestId }.orEmpty()
        if (ids.isEmpty()) return
        val transition = event.geofenceTransition
        Log.i(TAG, "transition=$transition ids=$ids")

        if (transition == Geofence.GEOFENCE_TRANSITION_EXIT &&
            ids.contains(TroitaConfig.COVERAGE_ID)
        ) {
            // Left the covered area — slide the window forward. The event's own
            // location is fresher and cheaper than asking for a new fix.
            GeofenceManager.rebuild(context, event.triggeringLocation)
            return
        }

        if (transition != Geofence.GEOFENCE_TRANSITION_ENTER) return

        for (id in ids) {
            if (id == TroitaConfig.COVERAGE_ID) continue
            if (ChurchStore.recentlyNotified(context, id)) {
                Log.d(TAG, "cooldown suppressed $id")
                continue
            }
            val church = ChurchStore.byId(context, id)
            if (church == null) {
                Log.w(TAG, "geofence for unknown church $id")
                continue
            }
            ChurchNotifier.notify(context, church, mode = "geofence")
            ChurchStore.recordEncounter(context, id, "geofence")
        }
    }

    private companion object {
        const val TAG = "GeofenceReceiver"
    }
}
