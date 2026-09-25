/// Exact alarms that wake the app for each check, and the background run.
///
/// Native side: android/app/src/main/kotlin/com/kuhy/umbrella/. The alarm
/// fires AlarmReceiver, which starts CheckService (a short foreground
/// service) running [runBackground] in a headless engine. A foreground
/// service keeps network access in Doze; the JobScheduler job used by
/// android_alarm_manager_plus waited for the screen to come on instead.
library;

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:umbrella/core/schedule.dart';
import 'package:umbrella/services/check_runner.dart';
import 'package:umbrella/services/notifier.dart';
import 'package:umbrella/services/open_meteo.dart';
import 'package:umbrella/services/store.dart';

const _alarm = MethodChannel('umbrella/alarm');
const _bg = MethodChannel('umbrella/bg');

/// Native "just re-arm" kind (after a clock or time zone change).
const String rearmKind = 'rearm';

/// Arms the next check. Idempotent: safe on every launch, settings change
/// and alarm fire. Returns what was armed (null = nothing enabled).
Future<PlannedCheck?> armNext(Store store, {DateTime? now}) async {
  final next = nextCheck(store.settings, now ?? DateTime.now());
  if (next == null) {
    await _alarm.invokeMethod<void>('cancel');
    return null;
  }
  await _alarm.invokeMethod<void>('arm', {
    'at': next.at.millisecondsSinceEpoch,
    'kind': next.kind.name,
  });
  return next;
}

/// One background run for [kind]; always re-arms, always tells the service
/// it is done so the foreground notification goes away.
/// [notifier] and [client] are injectable for tests; the defaults are real.
Future<void> runBackground(
  String kind, {
  Notifier? notifier,
  http.Client? client,
}) async {
  final store = await Store.open();
  final web = client ?? http.Client();
  try {
    if (kind != rearmKind) {
      final n = notifier ?? Notifier();
      await n.init();
      await runCheck(
        kind: CheckKind.values.byName(kind),
        now: DateTime.now(),
        store: store,
        fetch: (p) => fetchEnsemble(web, p),
        notify: n.show,
      );
    }
  } finally {
    web.close();
    // Re-arm even if the check threw, or the chain of days would stop.
    // One minute ahead so this alarm's own time is never picked again.
    try {
      await armNext(store, now: DateTime.now().add(const Duration(minutes: 1)));
    } finally {
      await _bg.invokeMethod<void>('done');
    }
  }
}
