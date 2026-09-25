package com.kuhy.umbrella

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * The one pending check alarm. Dart decides *when* (lib/core/schedule.dart);
 * this only sets it with setExactAndAllowWhileIdle, which -- unlike a
 * JobScheduler job -- fires and lets us start a foreground service in Doze.
 *
 * The alarm is also written to prefs so the boot receiver can re-set it with
 * no Dart and no service start (Android 15 restricts FGS starts at boot).
 */
object AlarmScheduler {
    const val ACTION_FIRE = "com.kuhy.umbrella.FIRE"
    const val EXTRA_KIND = "kind"
    const val KIND_REARM = "rearm"
    private const val PREFS = "umbrella_alarm"
    private const val REQUEST_CODE = 7

    fun attach(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, "umbrella/alarm").setMethodCallHandler { call, result ->
            when (call.method) {
                "arm" -> {
                    val at = (call.argument<Number>("at") ?: 0).toLong()
                    arm(app, at, call.argument<String>("kind") ?: KIND_REARM)
                    result.success(null)
                }
                "cancel" -> {
                    cancel(app)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun arm(context: Context, atMillis: Long, kind: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putLong("at", atMillis).putString("kind", kind).apply()
        manager(context).setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP, atMillis, pending(context, kind),
        )
    }

    fun cancel(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
        manager(context).cancel(pending(context, KIND_REARM))
    }

    /** After boot/update: put the saved alarm back; a missed one fires in a minute. */
    fun restore(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val at = prefs.getLong("at", 0L)
        if (at == 0L) return
        val soon = System.currentTimeMillis() + 60_000L
        arm(context, maxOf(at, soon), prefs.getString("kind", KIND_REARM) ?: KIND_REARM)
    }

    /** Clock or zone changed: X and Y are local times, so let Dart recompute. */
    fun rearmSoon(context: Context) =
        arm(context, System.currentTimeMillis() + 60_000L, KIND_REARM)

    private fun manager(context: Context) =
        context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    // Same request code for every kind: FLAG_UPDATE_CURRENT replaces the one
    // pending alarm instead of stacking a second.
    private fun pending(context: Context, kind: String): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            Intent(context, AlarmReceiver::class.java)
                .setAction(ACTION_FIRE).putExtra(EXTRA_KIND, kind),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
}
