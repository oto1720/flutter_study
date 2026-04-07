package com.example.flutter_learn

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.example.flutter_study/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDeviceModel" -> {
                        // 例: "Google Pixel 8" / "samsung SM-G991B"
                        result.success("${Build.MANUFACTURER} ${Build.MODEL}")
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
