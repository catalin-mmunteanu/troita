package ro.troita.bridge

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import ro.troita.TroitaConfig
import ro.troita.data.ChurchStore
import ro.troita.geofence.GeofenceManager
import ro.troita.geofence.WindowStore
import ro.troita.journey.JourneyForegroundService
import ro.troita.notify.Channels
import ro.troita.oem.OemGuidance

/**
 * The *only* place Dart and Kotlin meet.
 *
 * Note what is not here: no church lookups on the notification path, no
 * geofence transition callbacks into Dart. Dart drives configuration and reads
 * the SQLite file directly with sqflite; the background path never crosses this
 * boundary, so a dead Flutter engine cannot break notifications.
 */
object TroitaBridge {

    private const val TAG = "TroitaBridge"
    private const val METHOD_CHANNEL = "ro.troita/native"
    private const val EVENT_CHANNEL = "ro.troita/journey"

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val main = Handler(Looper.getMainLooper())

    private var channel: MethodChannel? = null
    private var events: EventChannel.EventSink? = null

    @Volatile
    var pendingChurchId: String? = null

    fun attach(context: Context, engine: FlutterEngine) {
        val app = context.applicationContext

        channel = MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL).apply {
            setMethodCallHandler { call, result -> handle(app, call, result) }
        }

        EventChannel(engine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    events = sink
                    JourneyForegroundService.listener = { state ->
                        main.post { events?.success(state) }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    JourneyForegroundService.listener = null
                    events = null
                }
            }
        )
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
        JourneyForegroundService.listener = null
        events = null
    }

    fun emitPendingChurch() {
        val id = pendingChurchId ?: return
        main.post { channel?.invokeMethod("onChurchOpened", id) }
    }

    // ------------------------------------------------------------------ calls

    private fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        // Every handler runs off the main thread — ChurchStore.open() may copy a
        // multi-megabyte asset on first launch.
        scope.launch {
            try {
                val value = dispatch(context, call)
                withContext(Dispatchers.Main) { result.success(value) }
            } catch (e: Exception) {
                Log.e(TAG, "method ${call.method} failed", e)
                withContext(Dispatchers.Main) {
                    result.error("troita_error", e.message, e::class.java.simpleName)
                }
            }
        }
    }

    private suspend fun dispatch(context: Context, call: MethodCall): Any? = when (call.method) {

        "initialize" -> {
            Channels.ensure(context)
            ChurchStore.open(context)
            mapOf(
                "database_path" to ChurchStore.databaseFile(context).absolutePath,
                "seed" to ChurchStore.meta(context),
                "status" to status(context),
            )
        }

        "databasePath" -> ChurchStore.databaseFile(context).absolutePath

        // The UI needs a position for the "nearby" list. Reusing the native
        // fused-location call keeps a location plugin out of the Dart side and
        // means there is exactly one place that asks the OS where we are.
        "currentLocation" -> GeofenceManager.currentLocation(context)?.let {
            mapOf(
                "lat" to it.latitude,
                "lon" to it.longitude,
                "accuracy_m" to it.accuracy.toDouble(),
                "age_ms" to (System.currentTimeMillis() - it.time),
            )
        }

        "status" -> status(context)

        "refreshWindow" -> {
            val r = GeofenceManager.rebuild(context, null)
            resultMap(r) + ("status" to status(context))
        }

        "ensureFresh" -> resultMap(GeofenceManager.ensureFresh(context))

        "setPassiveEnabled" -> {
            val enabled = call.argument<Boolean>("enabled") ?: false
            WindowStore.setPassiveEnabled(context, enabled)
            if (enabled) resultMap(GeofenceManager.rebuild(context, null))
            else { GeofenceManager.clear(context); mapOf("ok" to true, "registered" to 0) }
        }

        "setSoundEnabled" -> {
            WindowStore.setSoundEnabled(context, call.argument<Boolean>("enabled") ?: false)
            true
        }

        "startJourney" -> {
            JourneyForegroundService.start(context)
            true
        }

        "stopJourney" -> {
            JourneyForegroundService.stop(context)
            true
        }

        "consumePendingChurchId" -> pendingChurchId.also { pendingChurchId = null }

        "markOpened" -> {
            call.argument<String>("id")?.let { ChurchStore.markOpened(context, it) }
            true
        }

        "recentEncounters" -> ChurchStore.recentEncounters(context).map { (church, at) ->
            church.toMap() + ("notified_at" to at)
        }

        "oemVendor" -> OemGuidance.detect().let {
            mapOf(
                "id" to it.id,
                "label" to it.label,
                "needs_autostart" to it.needsAutostart,
                "battery_optimised" to isBatteryOptimised(context),
            )
        }

        "openAutostartSettings" -> OemGuidance.openAutostart(context)
        "openBatterySettings" -> OemGuidance.openBatteryOptimisation(context)
        "openAppDetails" -> OemGuidance.openAppDetails(context)
        "openLocationSettings" -> OemGuidance.openLocationSettings(context)
        "openNotificationSettings" -> OemGuidance.openNotificationChannel(
            context, call.argument<String>("channel") ?: TroitaConfig.CHANNEL_DISCREET
        )

        else -> throw UnsupportedOperationException("unknown method ${call.method}")
    }

    // ----------------------------------------------------------------- helpers

    private fun status(context: Context): Map<String, Any?> {
        val window = WindowStore.read(context)
        return mapOf(
            "foreground_location" to GeofenceManager.hasForegroundLocation(context),
            "background_location" to GeofenceManager.hasBackgroundLocation(context),
            "passive_enabled" to WindowStore.passiveEnabled(context),
            "sound_enabled" to WindowStore.soundEnabled(context),
            "journey_active" to WindowStore.journeyActive(context),
            "battery_optimised" to isBatteryOptimised(context),
            "window" to mapOf(
                "lat" to window.lat,
                "lon" to window.lon,
                "radius_m" to window.radiusM,
                "count" to window.ids.size,
                "updated_at" to window.updatedAt,
                "dirty" to window.dirty,
            ),
        )
    }

    private fun resultMap(r: GeofenceManager.Result): Map<String, Any?> = when (r) {
        is GeofenceManager.Result.Ok ->
            mapOf("ok" to true, "registered" to r.registered, "coverage_m" to r.coverageRadiusM)
        GeofenceManager.Result.NoPermission -> mapOf("ok" to false, "reason" to "permission")
        GeofenceManager.Result.NoLocation -> mapOf("ok" to false, "reason" to "location")
        GeofenceManager.Result.NoChurches -> mapOf("ok" to false, "reason" to "no_churches")
        is GeofenceManager.Result.Failed -> mapOf("ok" to false, "reason" to r.reason)
    }

    private fun isBatteryOptimised(context: Context): Boolean {
        val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return false
        return !pm.isIgnoringBatteryOptimizations(context.packageName)
    }
}
