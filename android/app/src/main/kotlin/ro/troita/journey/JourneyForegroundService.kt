package ro.troita.journey

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import ro.troita.MainActivity
import ro.troita.R
import ro.troita.TroitaConfig
import ro.troita.geofence.GeofenceManager
import ro.troita.geofence.WindowStore
import ro.troita.notify.Channels

/**
 * Journey mode: user-initiated, visible, and — importantly — it needs no
 * ACCESS_BACKGROUND_LOCATION at all. A foreground service started while the app
 * is in the foreground may access location with only the runtime foreground
 * permission, which means this mode ships without the Play Console background
 * location declaration, without the demo video, and without being at the mercy
 * of OEM battery managers.
 *
 * That makes it the right default for v1, with passive geofencing as an opt-in.
 */
class JourneyForegroundService : Service() {

    private lateinit var client: FusedLocationProviderClient
    private lateinit var engine: JourneyEngine
    private var startedAt = 0L
    private var notified = 0

    private val callback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            val location = result.lastLocation ?: return
            val hits = try {
                engine.onLocation(location)
            } catch (e: Exception) {
                Log.e(TAG, "journey tick failed", e); emptyList()
            }
            if (hits.isNotEmpty()) {
                notified += hits.size
                updateNotification()
            }
            listener?.invoke(state())
        }
    }

    override fun onCreate() {
        super.onCreate()
        Channels.ensure(this)
        client = LocationServices.getFusedLocationProviderClient(this)
        engine = JourneyEngine(applicationContext)
    }

    @SuppressLint("MissingPermission") // checked via hasForegroundLocation()
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == TroitaConfig.ACTION_STOP_JOURNEY) {
            stop()
            return START_NOT_STICKY
        }
        startedAt = System.currentTimeMillis()

        // Android 14+ requires the type at startForeground() time and throws
        // if FOREGROUND_SERVICE_LOCATION is missing.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID, buildNotification(),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION,
            )
        } else {
            startForeground(NOTIFICATION_ID, buildNotification())
        }

        if (!GeofenceManager.hasForegroundLocation(this)) {
            Log.w(TAG, "started without location permission; stopping")
            stop()
            return START_NOT_STICKY
        }

        val request = LocationRequest.Builder(
            Priority.PRIORITY_BALANCED_POWER_ACCURACY, TroitaConfig.JOURNEY_INTERVAL_MS
        )
            .setMinUpdateIntervalMillis(TroitaConfig.JOURNEY_FASTEST_INTERVAL_MS)
            .setMinUpdateDistanceMeters(TroitaConfig.JOURNEY_MIN_DISPLACEMENT_M)
            .setWaitForAccurateLocation(false)
            .build()

        try {
            client.requestLocationUpdates(request, callback, mainLooper)
        } catch (e: SecurityException) {
            Log.e(TAG, "location permission revoked mid-flight", e)
            stop()
            return START_NOT_STICKY
        }

        WindowStore.setJourneyActive(this, true)
        listener?.invoke(state())
        // START_REDELIVER_INTENT: if the system kills us under memory pressure
        // we want the journey resumed with the same intent, not silently dropped.
        return START_REDELIVER_INTENT
    }

    private fun stop() {
        runCatching { client.removeLocationUpdates(callback) }
        WindowStore.setJourneyActive(this, false)
        listener?.invoke(mapOf("active" to false, "notified" to notified))
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        runCatching { client.removeLocationUpdates(callback) }
        WindowStore.setJourneyActive(this, false)
        listener?.invoke(mapOf("active" to false, "notified" to notified))
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ---------------------------------------------------------- notification

    @SuppressLint("MissingPermission") // guarded by areNotificationsEnabled()
    private fun updateNotification() {
        androidx.core.app.NotificationManagerCompat.from(this)
            .also { if (!it.areNotificationsEnabled()) return }
            .notify(NOTIFICATION_ID, buildNotification())
    }

    private fun buildNotification(): android.app.Notification {
        val open = PendingIntent.getActivity(
            this, 1,
            Intent(this, MainActivity::class.java).setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stop = PendingIntent.getService(
            this, 2,
            Intent(this, JourneyForegroundService::class.java)
                .setAction(TroitaConfig.ACTION_STOP_JOURNEY),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val text = if (notified == 0) getString(R.string.journey_running)
        else resources.getQuantityString(R.plurals.journey_found, notified, notified)

        return NotificationCompat.Builder(this, TroitaConfig.CHANNEL_JOURNEY)
            .setSmallIcon(R.drawable.ic_troita_notification)
            .setContentTitle(getString(R.string.journey_title))
            .setContentText(text)
            .setContentIntent(open)
            .addAction(0, getString(R.string.journey_stop), stop)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun state(): Map<String, Any?> = mapOf(
        "active" to true,
        "notified" to notified,
        "candidates" to engine.lastCount,
        "started_at" to startedAt,
    )

    companion object {
        private const val TAG = "JourneyService"
        private const val NOTIFICATION_ID = 4711

        /** Set by the MethodChannel bridge so the UI can mirror service state. */
        @Volatile
        var listener: ((Map<String, Any?>) -> Unit)? = null

        fun start(context: Context) {
            val intent = Intent(context, JourneyForegroundService::class.java)
            // Must be called while the app is visible: Android 12+ forbids
            // starting a foreground service from the background.
            androidx.core.content.ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            context.startService(
                Intent(context, JourneyForegroundService::class.java)
                    .setAction(TroitaConfig.ACTION_STOP_JOURNEY)
            )
        }
    }
}
