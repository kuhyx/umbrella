package com.kuhy.umbrella

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Runs one check: a short foreground service hosting a headless Flutter
 * engine that executes `backgroundMain` in lib/main.dart. A foreground
 * service keeps network access while the phone dozes, which a JobScheduler
 * job (android_alarm_manager_plus) does not -- that job simply waited for
 * the screen to come on.
 */
class CheckService : Service() {
    private var engine: FlutterEngine? = null
    private val handler = Handler(Looper.getMainLooper())
    private val watchdog = Runnable { finish() }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        goForeground()
        if (engine != null) return START_NOT_STICKY // a check is already running
        val kind = intent?.getStringExtra(AlarmScheduler.EXTRA_KIND)
            ?: AlarmScheduler.KIND_REARM
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(applicationContext)
        loader.ensureInitializationComplete(applicationContext, null)
        val e = FlutterEngine(applicationContext)
        engine = e
        AlarmScheduler.attach(applicationContext, e.dartExecutor.binaryMessenger)
        MethodChannel(e.dartExecutor.binaryMessenger, "umbrella/bg")
            .setMethodCallHandler { call, result ->
                result.success(null)
                if (call.method == "done") handler.post { finish() }
            }
        e.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "backgroundMain"),
            listOf(kind),
        )
        // shortService is capped at 3 minutes; never let it reach the ANR.
        handler.postDelayed(watchdog, WATCHDOG_MS)
        return START_NOT_STICKY
    }

    override fun onTimeout(startId: Int) = finish()

    override fun onTimeout(startId: Int, fgsType: Int) = finish()

    override fun onDestroy() {
        teardown()
        super.onDestroy()
    }

    private fun finish() {
        teardown()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun teardown() {
        handler.removeCallbacks(watchdog)
        engine?.destroy()
        engine = null
    }

    private fun goForeground() {
        val nm = getSystemService(NotificationManager::class.java)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL, "Checking the forecast", NotificationManager.IMPORTANCE_MIN,
                ),
            )
            Notification.Builder(this, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_umbrella)
            .setContentTitle("☂️ ⏳")
            .build()
        // Its own id: removing it must never remove the verdict (id 1).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SHORT_SERVICE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private companion object {
        const val CHANNEL = "umbrella_checking"
        const val NOTIFICATION_ID = 99
        const val WATCHDOG_MS = 150_000L
    }
}
