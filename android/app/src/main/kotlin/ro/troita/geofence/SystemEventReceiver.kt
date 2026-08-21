package ro.troita.geofence

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

/**
 * Re-asserts the geofence window after the events that silently wipe it.
 *
 * Not covered, because nothing can cover it: if the user force-stops the app
 * from Settings, Android delivers us no broadcasts at all until they launch it
 * again. Accept that and make the "open the app once" recovery cheap.
 */
class SystemEventReceiver : BroadcastReceiver() {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        Log.i(TAG, "system event: $action")
        val app = context.applicationContext

        val pending = goAsync()
        scope.launch {
            try {
                withTimeoutOrNull(9_000) {
                    when (action) {
                        Intent.ACTION_BOOT_COMPLETED,
                        "android.intent.action.QUICKBOOT_POWERON",
                        Intent.ACTION_MY_PACKAGE_REPLACED,
                        -> {
                            WindowStore.markDirty(app)
                            GeofenceManager.ensureFresh(app)
                        }

                        "android.location.PROVIDERS_CHANGED" -> {
                            // Toggling location off drops every registration.
                            WindowStore.markDirty(app)
                            GeofenceManager.ensureFresh(app)
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "re-registration failed", e)
            } finally {
                pending.finish()
            }
        }
    }

    private companion object {
        const val TAG = "SystemEventReceiver"
    }
}
