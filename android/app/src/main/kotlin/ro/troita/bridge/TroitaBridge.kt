package ro.troita.bridge

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import ro.troita.TroitaConfig
import ro.troita.data.ChurchStore

/**
 * The only place Dart and Kotlin meet.
 *
 * Down to three jobs: install the seed database, report onboarding status,
 * and pass on the church id from a notification tap. Everything else —
 * queries, favourites, visits — happens in Dart against SQLite directly.
 *
 * There used to be a fourth, a fused-location fix "for the map". The map never
 * asked for it; only a screen nothing navigated to did. The app requested
 * location at onboarding for a feature that did not use it, so the call, the
 * permission and the Play Services location dependency are gone.
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
            "onboarded" to prefs.getBoolean(TroitaConfig.KEY_ONBOARDED, false),
        )
    }
}
