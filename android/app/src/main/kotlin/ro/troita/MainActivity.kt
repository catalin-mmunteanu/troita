package ro.troita

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import ro.troita.bridge.TroitaBridge

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Notification channels are created by flutter_local_notifications from
        // Dart. There is no native Channels object any more — one owner.
        capture(intent)
    }

    /**
     * launchMode is singleTop, so a notification tap on an already-running app
     * arrives here rather than through onCreate.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        capture(intent)
        // The engine is alive in this case, so tell Dart straight away instead
        // of waiting for it to poll on resume.
        TroitaBridge.emitPendingChurch()
    }

    private fun capture(intent: Intent?) {
        intent?.getStringExtra(TroitaConfig.EXTRA_CHURCH_ID)?.let {
            TroitaBridge.pendingChurchId = it
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        TroitaBridge.attach(applicationContext, flutterEngine)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        TroitaBridge.detach()
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
