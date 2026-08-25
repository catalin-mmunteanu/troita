package ro.troita.bridge

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.CurrentLocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import ro.troita.TroitaConfig
import ro.troita.data.ChurchStore

/**
 * The only place Dart and Kotlin meet.
 *
 * Down to four jobs since the geofencing came out: install the seed database,
 * create the notification channels, hand Dart a location fix for the map, and
 * pass on the church id from a notification tap. Everything else — queries,
 * favourites, visits — happens in Dart against SQLite directly.
 */
object TroitaBridge {

    private const val TAG = "TroitaBridge"
    private const val METHOD_CHANNEL = "ro.troita/native"

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val main = Handler(Looper.getMainLooper())

    private var channel: MethodChannel? = null

    @Volatile
    var pendingChurchId: String? = null

    fun attach(context: Context, engine: FlutterEngine) {
        val app = context.applicationContext
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL).apply {
            setMethodCallHandler { call, result -> handle(app, call, result) }
        }
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    fun emitPendingChurch() {
        val id = pendingChurchId ?: return
        main.post { channel?.invokeMethod("onChurchOpened", id) }
    }

    // ------------------------------------------------------------------ calls

    private fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        // Off the main thread: open() may copy a multi-megabyte asset on first
        // launch, and that must not block the first frame.
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
            // Notification channels are created by flutter_local_notifications
            // from Dart — one owner, not two.
            ChurchStore.open(context)
            mapOf(
                "database_path" to ChurchStore.databaseFile(context).absolutePath,
                "seed" to ChurchStore.meta(context),
                "status" to status(context),
            )
        }

        "databasePath" -> ChurchStore.databaseFile(context).absolutePath

        "status" -> status(context)

        // The map needs a position. Keeping the single fused-location call here
        // means there is exactly one place that asks the OS where we are.
        "currentLocation" -> currentLocation(context)?.let {
            mapOf(
                "lat" to it.latitude,
                "lon" to it.longitude,
                "accuracy_m" to it.accuracy.toDouble(),
                "age_ms" to (System.currentTimeMillis() - it.time),
            )
        }

        "setOnboarded" -> {
            context.getSharedPreferences(TroitaConfig.PREFS, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(TroitaConfig.KEY_ONBOARDED, call.argument<Boolean>("value") ?: true)
                .apply()
            true
        }

        "consumePendingChurchId" -> pendingChurchId.also { pendingChurchId = null }

        else -> throw UnsupportedOperationException("unknown method ${call.method}")
    }

    // ---------------------------------------------------------------- helpers

    private fun status(context: Context): Map<String, Any?> {
        val prefs = context.getSharedPreferences(TroitaConfig.PREFS, Context.MODE_PRIVATE)
        return mapOf(
            "location" to hasLocation(context),
            "onboarded" to prefs.getBoolean(TroitaConfig.KEY_ONBOARDED, false),
        )
    }

    private fun hasLocation(context: Context): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    @SuppressLint("MissingPermission") // guarded by hasLocation()
    private suspend fun currentLocation(context: Context): android.location.Location? {
        if (!hasLocation(context)) return null
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
