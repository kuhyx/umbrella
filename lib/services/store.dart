/// Persistent state: settings, last good forecasts, last verdict.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:umbrella/core/settings.dart';
import 'package:umbrella/core/verdict.dart';

const _kSettings = 'settings';
const _kVerdict = 'last_verdict';

String _kForecast(Place p) => 'forecast_${p.lat}_${p.lon}';

/// A forecast payload with the time it was fetched.
typedef CachedForecast = ({Map<String, dynamic> json, DateTime fetchedAt});

/// The last verdict, which outing it was for, and whether it was stale.
typedef SavedVerdict = ({
  Verdict verdict,
  DateTime leave,
  DateTime decidedAt,
  bool stale,
});

/// Thin typed wrapper over SharedPreferences.
class Store {
  /// Wraps [prefs].
  Store(this.prefs);

  /// The backing preferences.
  final SharedPreferences prefs;

  /// Opens the store. In a background isolate this must be reloaded so it
  /// sees what the UI isolate wrote.
  static Future<Store> open() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return Store(prefs);
  }

  /// Current settings (defaults on first run).
  Settings get settings {
    final raw = prefs.getString(_kSettings);
    if (raw == null) return Settings.defaults();
    return Settings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Saves settings.
  Future<void> saveSettings(Settings s) =>
      prefs.setString(_kSettings, jsonEncode(s.toJson()));

  /// The last forecast fetched for [p], if any.
  CachedForecast? cachedForecast(Place p) {
    final raw = prefs.getString(_kForecast(p));
    if (raw == null) return null;
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return (
      json: m['json'] as Map<String, dynamic>,
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(m['at'] as int),
    );
  }

  /// Caches a fetched forecast for [p].
  Future<void> saveForecast(Place p, Map<String, dynamic> json, DateTime at) =>
      prefs.setString(
        _kForecast(p),
        jsonEncode({'json': json, 'at': at.millisecondsSinceEpoch}),
      );

  /// The last verdict shown or notified.
  SavedVerdict? get lastVerdict {
    final raw = prefs.getString(_kVerdict);
    if (raw == null) return null;
    // A verdict written by an older build may not parse. It is only a cache
    // of the last answer, so treat it as absent rather than crash the alarm.
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return (
        verdict: Verdict.fromJson(m['verdict'] as Map<String, dynamic>),
        leave: DateTime.fromMillisecondsSinceEpoch(m['leave'] as int),
        decidedAt: DateTime.fromMillisecondsSinceEpoch(m['at'] as int),
        stale: m['stale'] as bool,
      );
    } on Object {
      return null;
    }
  }

  /// Saves the verdict for the outing leaving at [leave].
  Future<void> saveVerdict(
    Verdict v,
    DateTime leave,
    DateTime at, {
    required bool stale,
  }) => prefs.setString(
    _kVerdict,
    jsonEncode({
      'verdict': v.toJson(),
      'leave': leave.millisecondsSinceEpoch,
      'at': at.millisecondsSinceEpoch,
      'stale': stale,
    }),
  );
}
