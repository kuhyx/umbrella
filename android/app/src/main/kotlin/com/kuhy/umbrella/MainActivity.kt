package com.kuhy.umbrella

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AlarmScheduler.attach(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}
