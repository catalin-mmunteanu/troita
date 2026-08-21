package ro.troita.geofence

import android.Manifest
import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.CurrentLocationRequest
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withTimeoutOrNull
import ro.troita.TroitaConfig
import ro.troita.data.Church
import ro.troita.data.ChurchStore

/**
 * Owns the sliding geofence window.
 *
 * The window is driven by a single large "coverage" circle registered with an
 * EXIT trigger. When the user leaves it, the OS wakes us and we rebuild around
 * the new position. This costs nothing in battery — there is no polling, no
 * foreground service and no background location sampling. Android has no
 * equivalent of iOS's significant-location-change API, and this is the closest
 * thing that is actually free.
 */
object GeofenceManager {

    private const val TAG = "GeofenceManager"

    sealed interface Result {
        data class Ok(val registered: Int, val coverageRadiusM: Double) : Result
        object NoPermission : Result
        object NoLocation : Result
        object NoChurches : Result
        data class Failed(val reason: String) : Result
    }

    // ------------------------------------------------------------------ intent

    /**
     * MUST be mutable on API 31+: Play services fills the transition extras into
     * this intent. An immutable PendingIntent here fails silently — no crash, no
     * log, geofences simply never fire. This is the single most common cause of
     * "my geofences don't work".
     */
    fun pendingIntent(context: Context): PendingIntent {
        val intent = Intent(context.applicationContext, GeofenceBroadcastReceiver::class.java)
            .setAction(TroitaConfig.ACTION_GEOFENCE)
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags = flags or PendingIntent.FLAG_MUTABLE
        }
        return PendingIntent.getBroadcast(context.applicationContext, 0, intent, flags)
    }

    // ------------------------------------------------------------- permissions

    fun hasForegroundLocation(context: Context): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    fun hasBackgroundLocation(context: Context): Boolean =
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) hasForegroundLocation(context)
        else hasForegroundLocation(context) && ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_BACKGROUND_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

    // ---------------------------------------------------------------- rebuild

    /** Rebuild around an explicit position (the geofence event's own location). */
    suspend fun rebuild(context: Context, at: Location?): Result {
        val ctx = context.applicationContext
        if (!hasBackgroundLocation(ctx)) {
            Log.w(TAG, "background location not granted; refusing to register")
            return Result.NoPermission
        }
        val here = at ?: currentLocation(ctx) ?: return Result.NoLocation
        return rebuildAt(ctx, here.latitude, here.longitude)
    }

    @SuppressLint("MissingPermission") // guarded by hasBackgroundLocation above
    suspend fun rebuildAt(context: Context, lat: Double, lon: Double): Result {
        val ctx = context.applicationContext
        if (!hasBackgroundLocation(ctx)) return Result.NoPermission

        val churches = ChurchStore.nearest(ctx, lat, lon, TroitaConfig.MAX_CHURCH_GEOFENCES)
        if (churches.isEmpty()) {
            clear(ctx)
            return Result.NoChurches
        }

        val coverageRadius = coverageRadius(churches)
        val previous = WindowStore.read(ctx)
        val desired = churches.map { it.id }.toSet()

        val client = LocationServices.getGeofencingClient(ctx)

        // Diff rather than churn: removing and re-adding 95 regions on every
        // rebuild wakes Play services harder than it needs to and briefly leaves
        // the user unmonitored.
        val stale = previous.ids - desired
        if (stale.isNotEmpty() && !previous.dirty) {
            runCatching { client.removeGeofences(stale.toList()).await() }
                .onFailure { Log.w(TAG, "removeGeofences(stale) failed", it) }
        }
        if (previous.dirty) {
            // Our record of what is registered is untrustworthy — start clean.
            runCatching { client.removeGeofences(pendingIntent(ctx)).await() }
        }

        val fences = buildList {
            churches.forEach { add(it.toGeofence()) }
            add(coverageGeofence(lat, lon, coverageRadius))
        }

        val request = GeofencingRequest.Builder()
            // ENTER only. INITIAL_TRIGGER_EXIT would fire the coverage fence
            // immediately in the (impossible) case we're outside our own circle,
            // and would also mean every rebuild reports exits for churches we
            // just stopped watching.
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .addGeofences(fences)
            .build()

        return try {
            client.addGeofences(request, pendingIntent(ctx)).await()
            WindowStore.write(ctx, lat, lon, coverageRadius, desired)
            Log.i(TAG, "window: ${churches.size} churches, coverage ${coverageRadius.toInt()} m")
            Result.Ok(churches.size, coverageRadius)
        } catch (e: Exception) {
            // A single bad region fails the entire batch, so log enough to find it.
            Log.e(TAG, "addGeofences failed for ${fences.size} regions", e)
            WindowStore.markDirty(ctx)
            Result.Failed(e.message ?: e::class.java.simpleName)
        }
    }

    /**
     * Rebuild only if we have drifted far enough to matter, or if our record of
     * the registered set is stale. Called on app open, on boot, and after any
     * event that may have wiped the regions.
     */
    suspend fun ensureFresh(context: Context, at: Location? = null): Result {
        val ctx = context.applicationContext
        if (!WindowStore.passiveEnabled(ctx)) return Result.Ok(0, 0.0)
        val window = WindowStore.read(ctx)
        if (window.isEmpty || window.dirty) return rebuild(ctx, at)

        val here = at ?: currentLocation(ctx) ?: return Result.NoLocation
        val drift = Geo.distanceM(window.lat, window.lon, here.latitude, here.longitude)
        return if (drift > window.radiusM * 0.5) rebuildAt(ctx, here.latitude, here.longitude)
        else Result.Ok(window.ids.size, window.radiusM)
    }

    suspend fun clear(context: Context) {
        val ctx = context.applicationContext
        runCatching { LocationServices.getGeofencingClient(ctx).removeGeofences(pendingIntent(ctx)).await() }
            .onFailure { Log.w(TAG, "clear failed", it) }
        WindowStore.clear(ctx)
    }

    // ------------------------------------------------------------------ pieces

    private fun Church.toGeofence(): Geofence {
        val radius = (geofenceRadiusM ?: 350).toFloat()
            .coerceIn(TroitaConfig.MIN_GEOFENCE_RADIUS_M, TroitaConfig.MAX_GEOFENCE_RADIUS_M)
        return Geofence.Builder()
            .setRequestId(id)
            .setCircularRegion(lat, lon, radius)
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER)
            // 0 = report as soon as the platform notices. It is not "instant":
            // expect tens of seconds to a couple of minutes in practice.
            .setNotificationResponsiveness(0)
            .build()
    }

    private fun coverageGeofence(lat: Double, lon: Double, radiusM: Double) =
        Geofence.Builder()
            .setRequestId(TroitaConfig.COVERAGE_ID)
            .setCircularRegion(lat, lon, radiusM.toFloat())
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_EXIT)
            .setNotificationResponsiveness(0)
            .build()

    /**
     * Sit the coverage circle comfortably inside the outermost church we are
     * watching, so the window is rebuilt before the user outruns it. In a dense
     * city that is a couple of kilometres; in the country it is capped so we
     * don't wait forever for an exit.
     */
    private fun coverageRadius(churches: List<Church>): Double {
        val outermost = churches.maxOf { it.distanceM }
        return Geo.clamp(
            outermost * TroitaConfig.COVERAGE_SHRINK,
            TroitaConfig.COVERAGE_MIN_RADIUS_M,
            TroitaConfig.COVERAGE_MAX_RADIUS_M,
        )
    }

    @SuppressLint("MissingPermission")
    suspend fun currentLocation(context: Context): Location? {
        if (!hasForegroundLocation(context)) return null
        val client = LocationServices.getFusedLocationProviderClient(context)
        return withTimeoutOrNull(12_000) {
            runCatching {
                client.getCurrentLocation(
                    CurrentLocationRequest.Builder()
                        .setPriority(Priority.PRIORITY_BALANCED_POWER_ACCURACY)
                        .setMaxUpdateAgeMillis(5 * 60_000)
                        .setDurationMillis(10_000)
                        .build(),
                    null,
                ).await()
            }.getOrNull() ?: runCatching { client.lastLocation.await() }.getOrNull()
        }
    }
}
