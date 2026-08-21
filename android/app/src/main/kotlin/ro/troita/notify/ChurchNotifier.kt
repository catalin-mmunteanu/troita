package ro.troita.notify

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import ro.troita.MainActivity
import ro.troita.R
import ro.troita.TroitaConfig
import ro.troita.data.Church
import ro.troita.geofence.WindowStore
import kotlin.math.abs
import kotlin.math.roundToInt

object ChurchNotifier {

    @SuppressLint("MissingPermission") // guarded by areNotificationsEnabled()
    fun notify(context: Context, church: Church, mode: String) {
        Channels.ensure(context)

        val channel = if (WindowStore.soundEnabled(context)) TroitaConfig.CHANNEL_BELL
        else TroitaConfig.CHANNEL_DISCREET

        val open = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            putExtra(TroitaConfig.EXTRA_CHURCH_ID, church.id)
            // Reuse the existing task if the app is already open, otherwise the
            // user gets a second copy of the app behind the detail screen.
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val contentIntent = PendingIntent.getActivity(
            context,
            stableId(church.id),
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, channel)
            .setSmallIcon(R.drawable.ic_troita_notification)
            .setContentTitle(church.name)
            .setContentText(subtitle(context, church))
            .setStyle(NotificationCompat.BigTextStyle().bigText(bigText(context, church)))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_RECOMMENDATION)
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            // Pre-O devices take vibration from the notification, not the channel.
            .setVibrate(longArrayOf(0, 110, 90, 110))
            .setOnlyAlertOnce(true)
            .build()

        // A stable id means passing the same church twice replaces the old
        // notification instead of stacking duplicates in the shade.
        NotificationManagerCompat.from(context)
            .also { if (!it.areNotificationsEnabled()) return }
            .notify(stableId(church.id), notification)
    }

    private fun subtitle(context: Context, church: Church): String {
        val bits = mutableListOf<String>()
        church.patron?.let { bits.add(it) }
        church.yearBuilt?.let { bits.add(context.getString(R.string.year_prefix, it)) }
        if (church.distanceM > 0) bits.add(distance(church.distanceM))
        return bits.joinToString(" · ").ifEmpty { context.getString(R.string.nearby_generic) }
    }

    private fun bigText(context: Context, church: Church): String {
        val head = subtitle(context, church)
        val tail = church.history?.take(220)?.let { if (it.length == 220) "$it…" else it }
        return listOfNotNull(head, tail).joinToString("\n")
    }

    private fun distance(m: Double): String =
        if (m < 950) "${(m / 10).roundToInt() * 10} m" else String.format("%.1f km", m / 1000)

    /** Deterministic, non-negative notification id derived from the church id. */
    private fun stableId(churchId: String): Int = abs(churchId.hashCode()).let {
        if (it == Int.MIN_VALUE) 0 else it % 1_000_000
    }
}
