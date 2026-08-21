package ro.troita.notify

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import androidx.core.content.ContextCompat
import ro.troita.R
import ro.troita.TroitaConfig

/**
 * Channel settings are immutable once created — you cannot later turn sound on,
 * change the vibration pattern, or raise importance on an existing channel.
 * So: create every variant up front with a versioned id, and let the user pick
 * between them rather than trying to mutate one.
 */
object Channels {

    fun ensure(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = ContextCompat.getSystemService(context, NotificationManager::class.java) ?: return

        // Discreet: a short double pulse, no sound. The default mode — the point
        // of the app is to be noticed in the corner of your eye, not to shout.
        val discreet = NotificationChannel(
            TroitaConfig.CHANNEL_DISCREET,
            context.getString(R.string.channel_discreet_name),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = context.getString(R.string.channel_discreet_desc)
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 110, 90, 110)
            setSound(null, null)
            setShowBadge(false)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }

        // Bell: same pulse plus a toacă/clopot sample if one is bundled.
        val bell = NotificationChannel(
            TroitaConfig.CHANNEL_BELL,
            context.getString(R.string.channel_bell_name),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = context.getString(R.string.channel_bell_desc)
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 110, 90, 110)
            setShowBadge(false)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            bellSound(context)?.let {
                setSound(
                    it,
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                        .build(),
                )
            }
        }

        // Journey: the mandatory foreground-service notification. Minimum
        // importance so it sits silently in the shade.
        val journey = NotificationChannel(
            TroitaConfig.CHANNEL_JOURNEY,
            context.getString(R.string.channel_journey_name),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = context.getString(R.string.channel_journey_desc)
            enableVibration(false)
            setSound(null, null)
            setShowBadge(false)
        }

        nm.createNotificationChannel(discreet)
        nm.createNotificationChannel(bell)
        nm.createNotificationChannel(journey)
    }

    /**
     * Resolved by name at runtime so the project compiles without the audio
     * asset. Drop a file at res/raw/toaca.ogg to enable it.
     */
    private fun bellSound(context: Context): Uri? {
        val id = context.resources.getIdentifier("toaca", "raw", context.packageName)
        return if (id == 0) null else Uri.parse("android.resource://${context.packageName}/$id")
    }
}
