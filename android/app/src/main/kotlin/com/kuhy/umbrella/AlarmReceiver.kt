package com.kuhy.umbrella

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/** Alarm fire -> start the check service at once; system events -> re-arm. */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            AlarmScheduler.ACTION_FIRE -> {
                // Must happen inside onReceive: the exact-alarm delivery grants
                // a ~10 s allowance to start a foreground service, even in Doze.
                val kind = intent.getStringExtra(AlarmScheduler.EXTRA_KIND)
                    ?: AlarmScheduler.KIND_REARM
                val service = Intent(context, CheckService::class.java)
                    .putExtra(AlarmScheduler.EXTRA_KIND, kind)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(service)
                } else {
                    context.startService(service)
                }
            }
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> AlarmScheduler.restore(context)
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> AlarmScheduler.rearmSoon(context)
        }
    }
}
