/// When to check: turns weekday plans into concrete outings and alarms.
library;

import 'package:umbrella/core/settings.dart';

/// The re-check runs this long before leaving, and only reports a flip.
const Duration recheckLead = Duration(minutes: 5);

/// How far ahead to look for the next enabled day.
const int _horizonDays = 8;

/// One concrete trip out of the house.
class Outing {
  /// Creates an outing.
  const Outing({required this.leave, required this.back});

  /// Leaving home (X), local time.
  final DateTime leave;

  /// Coming back (Y), local time.
  final DateTime back;
}

/// Which of the day's two alarms this is.
enum CheckKind {
  /// The daily notification, [Settings.notifyOffsetMin] before leaving.
  main,

  /// Last look just before leaving; notifies only if the answer flipped.
  recheck,
}

/// A scheduled alarm.
class PlannedCheck {
  /// Creates a planned check.
  const PlannedCheck({
    required this.at,
    required this.kind,
    required this.outing,
  });

  /// When the alarm fires.
  final DateTime at;

  /// Main or re-check.
  final CheckKind kind;

  /// The outing it is about.
  final Outing outing;
}

/// The outing planned for the calendar day of [day], or null if disabled.
Outing? outingOn(Settings s, DateTime day) {
  final plan = s.days[day.weekday - 1];
  if (!plan.enabled) return null;
  final midnight = DateTime(day.year, day.month, day.day);
  final leave = midnight.add(Duration(minutes: plan.leaveMin));
  var back = midnight.add(Duration(minutes: plan.backMin));
  if (!back.isAfter(leave)) back = back.add(const Duration(days: 1));
  return Outing(leave: leave, back: back);
}

/// The outing the Today screen should talk about: the first one that has
/// not finished yet (today's if you are still out, otherwise the next).
Outing? currentOuting(Settings s, DateTime now) {
  // Start from yesterday: an outing that crosses midnight may still be on.
  final start = DateTime(now.year, now.month, now.day - 1);
  for (var d = 0; d <= _horizonDays; d++) {
    final o = outingOn(s, DateTime(start.year, start.month, start.day + d));
    if (o != null && o.back.isAfter(now)) return o;
  }
  return null;
}

/// The next alarm strictly after [now], or null if every day is disabled.
PlannedCheck? nextCheck(Settings s, DateTime now) {
  for (var d = 0; d <= _horizonDays; d++) {
    final o = outingOn(s, DateTime(now.year, now.month, now.day + d));
    if (o == null) continue;
    final main = o.leave.subtract(Duration(minutes: s.notifyOffsetMin));
    if (main.isAfter(now)) {
      return PlannedCheck(at: main, kind: CheckKind.main, outing: o);
    }
    final recheck = o.leave.subtract(recheckLead);
    // Only worth a second look if it is later than the main one.
    if (recheck.isAfter(main) && recheck.isAfter(now)) {
      return PlannedCheck(at: recheck, kind: CheckKind.recheck, outing: o);
    }
  }
  return null;
}
