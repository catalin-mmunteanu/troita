package ro.troita.oem

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings

/**
 * Android's own Doze is survivable. Vendor battery managers are not.
 *
 * On Xiaomi, Autostart is off by default and a disabled Autostart means the
 * BOOT_COMPLETED receiver never runs — geofences are simply gone after every
 * reboot. Samsung's "Sleeping apps" does the equivalent after a few days of
 * light use. In Romania those two brands are most of the market, so this is not
 * an edge case; it is the majority path.
 *
 * These intents are undocumented and vendor-specific. Every call is guarded and
 * falls back to the generic settings screen.
 */
object OemGuidance {

    data class Vendor(val id: String, val label: String, val needsAutostart: Boolean)

    fun detect(): Vendor {
        val m = Build.MANUFACTURER.lowercase()
        val b = Build.BRAND.lowercase()
        return when {
            m.contains("xiaomi") || b.contains("redmi") || b.contains("poco") ->
                Vendor("xiaomi", "Xiaomi / Redmi / POCO", true)
            m.contains("samsung") -> Vendor("samsung", "Samsung", false)
            m.contains("huawei") || b.contains("honor") -> Vendor("huawei", "Huawei / Honor", true)
            m.contains("oppo") || m.contains("realme") -> Vendor("oppo", "OPPO / realme", true)
            m.contains("vivo") || m.contains("iqoo") -> Vendor("vivo", "vivo / iQOO", true)
            m.contains("oneplus") -> Vendor("oneplus", "OnePlus", true)
            m.contains("motorola") -> Vendor("motorola", "Motorola", false)
            else -> Vendor("generic", Build.MANUFACTURER, false)
        }
    }

    private val AUTOSTART_TARGETS = mapOf(
        "xiaomi" to listOf(
            "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
        ),
        "huawei" to listOf(
            "com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            "com.huawei.systemmanager" to "com.huawei.systemmanager.optimize.process.ProtectActivity",
        ),
        "oppo" to listOf(
            "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
            "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
        ),
        "vivo" to listOf(
            "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
            "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
        ),
        "oneplus" to listOf(
            "com.oneplus.security" to "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
        ),
    )

    /** Opens the vendor's autostart screen; returns false if we couldn't. */
    fun openAutostart(context: Context): Boolean {
        val vendor = detect()
        for ((pkg, cls) in AUTOSTART_TARGETS[vendor.id].orEmpty()) {
            val intent = Intent().setComponent(ComponentName(pkg, cls))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (context.packageManager.resolveActivity(intent, 0) != null) {
                return runCatching { context.startActivity(intent); true }.getOrDefault(false)
            }
        }
        return openAppDetails(context)
    }

    /**
     * The *list* of battery-optimised apps, not a request dialog.
     * REQUEST_IGNORE_BATTERY_OPTIMIZATIONS needs a permission Play restricts to
     * a narrow allowlist that a geofencing app does not fall into, so we send
     * the user to settings instead of asking for it.
     */
    fun openBatteryOptimisation(context: Context): Boolean = runCatching {
        context.startActivity(
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
        true
    }.getOrElse { openAppDetails(context) }

    fun openAppDetails(context: Context): Boolean = runCatching {
        context.startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.fromParts("package", context.packageName, null))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
        true
    }.getOrDefault(false)

    fun openNotificationChannel(context: Context, channelId: String): Boolean = runCatching {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startActivity(
                Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                    .putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            true
        } else openAppDetails(context)
    }.getOrDefault(false)

    fun openLocationSettings(context: Context): Boolean = runCatching {
        context.startActivity(
            Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
        true
    }.getOrDefault(false)
}
