package ro.troita.bridge

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import ro.troita.MainActivity
import ro.troita.R
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * The home-screen widget: today's date, saint and fasting rule.
 *
 * It computes nothing. The rules live in the Dart engine and the published
 * calendar, and a third copy of them in Kotlin would be one more thing to drift.
 * Instead Dart hands over the next sixty days each time the app opens
 * ([store]), and the widget only looks up today. Sixty days means it stays right
 * through two months of the app never being opened.
 *
 * Today changes at midnight, which no widget update period guarantees, so an
 * inexact alarm is set for just after it. Inexact on purpose: exact alarms need
 * a permission and a Play justification, and a widget a few minutes late into
 * the new day is fine.
 */
object TroitaWidget {

    private const val TAG = "TroitaWidget"
    private const val PREFS = "troita_widget"
    private const val KEY_DAYS = "days"
    const val ACTION_MIDNIGHT = "ro.troita.widget.MIDNIGHT"

    /** Called from Dart with a JSON object keyed by YYYY-MM-DD. */
    fun store(context: Context, json: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY_DAYS, json).apply()
        refresh(context)
    }

    fun refresh(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, TroitaWidgetProvider::class.java))
        if (ids.isEmpty()) return
        for (id in ids) manager.updateAppWidget(id, render(context))
        scheduleMidnight(context)
    }

    private fun todayKey(): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Calendar.getInstance().time)

    fun render(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.troita_widget)

        // Tapping anywhere opens the app, which opens on today.
        val open = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.widget_root, open)

        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_DAYS, null)
        val day = try {
            raw?.let { JSONObject(it).optJSONObject(todayKey()) }
        } catch (e: Exception) {
            Log.w(TAG, "unreadable widget data", e)
            null
        }

        if (day == null) {
            // Never opened, or not for sixty days. Say how to fix it rather
            // than show a stale day as if it were today.
            views.setTextViewText(R.id.widget_date, context.getString(R.string.app_name))
            views.setTextViewText(R.id.widget_saint, context.getString(R.string.widget_open_app))
            views.setViewVisibility(R.id.widget_fast, View.GONE)
            return views
        }

        views.setTextViewText(R.id.widget_date, day.optString("date"))
        views.setTextViewText(R.id.widget_saint, day.optString("saint"))
        colour(day.optString("saintColour"))?.let {
            views.setTextColor(R.id.widget_saint, it)
        }

        val fast = day.optString("fast")
        if (fast.isNullOrEmpty()) {
            views.setViewVisibility(R.id.widget_fast, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_fast, View.VISIBLE)
            views.setTextViewText(R.id.widget_fast, fast)
            colour(day.optString("fastColour"))?.let {
                views.setTextColor(R.id.widget_fast, it)
            }
        }
        return views
    }

    private fun colour(hex: String?): Int? =
        if (hex.isNullOrEmpty()) null else try { Color.parseColor(hex) } catch (e: Exception) { null }

    private fun scheduleMidnight(context: Context) {
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val next = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 1)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val pending = PendingIntent.getBroadcast(
            context, 1,
            Intent(context, TroitaWidgetProvider::class.java).setAction(ACTION_MIDNIGHT),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        // RTC, not RTC_WAKEUP: there is no reason to wake a sleeping phone to
        // redraw a widget nobody is looking at; it updates when the screen does.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarm.setAndAllowWhileIdle(AlarmManager.RTC, next.timeInMillis, pending)
        } else {
            alarm.set(AlarmManager.RTC, next.timeInMillis, pending)
        }
    }
}

class TroitaWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        TroitaWidget.refresh(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            TroitaWidget.ACTION_MIDNIGHT,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> TroitaWidget.refresh(context)
        }
    }
}
