package com.rollins.sukoyaka

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Hosts the widget's quick-log popup: a second engine running the app's
 *  normal Dart entrypoint, routed straight to `/quickLog`, themed as a
 *  floating dialog via `QuickLogDialogTheme` instead of the full tabbed app. */
class QuickLogActivity : FlutterActivity() {
    override fun getInitialRoute(): String = "/quickLog"

    // FlutterActivity defaults to an opaque SurfaceView-backed renderer, which
    // doesn't composite inside a floating/translucent window (the popup would
    // silently fail to render). Transparent mode switches it to a
    // TextureView-backed renderer, which does.
    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "quick_log/close")
            .setMethodCallHandler { call, result ->
                if (call.method == "close") {
                    finish()
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
