package com.mayajaal.online
import io.flutter.embedding.android.FlutterActivity
import android.content.Intent
import android.view.WindowManager
import java.util.ArrayDeque
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val pending = ArrayDeque<String>()
    private var shareChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        captureShare(intent)
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mayajaal/share")
        shareChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "keepScreenOn" -> {
                        if (call.arguments == true) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(null)
                    }
                    "takeSharedText" -> result.success(pending.pollFirst())
                else -> result.notImplemented()
            }
        }
    }

    override fun onPause() {
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        super.onPause()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        captureShare(intent)
        shareChannel?.invokeMethod("shareAvailable", null)
    }

    private fun captureShare(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEND || intent.type != "text/plain") return
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString() ?: return
        pending.addLast(text)
        intent.removeExtra(Intent.EXTRA_TEXT)
    }
}
