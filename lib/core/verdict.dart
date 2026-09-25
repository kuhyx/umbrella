/// The one decision this app makes: umbrella or not, and how sure.
library;

import 'package:umbrella/core/forecast.dart';

/// An hour counts as wet for a member at this much liquid (mm).
const double wetHourMm = 0.2;

/// Rain share for one hourly bucket of the outing.
class HourChance {
  /// Creates an hour chance.
  const HourChance({required this.start, required this.share});

  /// Reads a value written by [toJson].
  factory HourChance.fromJson(Map<String, dynamic> json) => HourChance(
    start: DateTime.fromMillisecondsSinceEpoch(json['start'] as int),
    share: (json['share'] as num).toDouble(),
  );

  /// Start of the hour (local display uses this).
  final DateTime start;

  /// Fraction 0..1 of members that are wet in this hour.
  final double share;

  /// JSON form for storage.
  Map<String, dynamic> toJson() => {
    'start': start.millisecondsSinceEpoch,
    'share': share,
  };
}

/// The answer for one outing.
class Verdict {
  /// Creates a verdict.
  const Verdict({
    required this.umbrella,
    required this.wet,
    required this.members,
    required this.hours,
  });

  /// Reads a verdict written by [toJson].
  factory Verdict.fromJson(Map<String, dynamic> json) => Verdict(
    umbrella: json['umbrella'] as bool,
    wet: json['wet'] as int,
    members: json['members'] as int,
    hours: [
      for (final h in json['hours'] as List<dynamic>)
        HourChance.fromJson(h as Map<String, dynamic>),
    ],
  );

  /// Take it?
  final bool umbrella;

  /// Members with at least one wet hour in the outing, at the wetter of the
  /// checked places.
  final int wet;

  /// How many forecast variants voted (at the place that decided).
  final int members;

  /// Fraction 0..1 of members that rain.
  double get rainShare => wet / members;

  /// Per-hour rain share across the outing (max over places).
  final List<HourChance> hours;

  // Percentages come from the integer counts: 23/40 as a double is
  // 0.57499..., so (share * 100).round() would say 57 where 58 is right.
  int _pct(int n) => (n * 200 + members) ~/ (2 * members);

  /// Percent the app is sure of its own answer.
  int get confidencePct => _pct(umbrella ? wet : members - wet);

  /// Percent chance of rain.
  int get rainPct => _pct(wet);

  /// First and last hour whose share reaches [threshold], or null.
  (DateTime, DateTime)? wetSpan(double threshold) {
    final wet = hours.where((h) => h.share >= threshold).toList();
    if (wet.isEmpty) return null;
    return (wet.first.start, wet.last.start.add(const Duration(hours: 1)));
  }

  /// JSON form for storage.
  Map<String, dynamic> toJson() => {
    'umbrella': umbrella,
    'wet': wet,
    'members': members,
    'hours': [for (final h in hours) h.toJson()],
  };
}

/// Decides for the outing [start]..[end] across every place's forecast.
///
/// A member is wet at a place if any hour of the outing reaches [wetHourMm].
/// Members with a gap (null) inside the outing are dropped rather than
/// guessed. The wetter place wins. Returns null if no place has any usable
/// member for the window -- the caller must say "couldn't check", not "dry".
Verdict? decide({
  required List<EnsembleForecast> forecasts,
  required DateTime start,
  required DateTime end,
  required double threshold,
}) {
  double? bestShare;
  var bestWet = 0;
  var bestMembers = 0;
  final hourShare = <int, double>{};
  for (final f in forecasts) {
    final idx = f.hoursOverlapping(start, end);
    if (idx.isEmpty) continue;
    final usable = [
      for (final m in f.members)
        if (idx.every((i) => m[i] != null)) m,
    ];
    if (usable.isEmpty) continue;
    final wet = usable.where((m) => idx.any((i) => m[i]! >= wetHourMm)).length;
    final share = wet / usable.length;
    if (bestShare == null || share > bestShare) {
      bestShare = share;
      bestWet = wet;
      bestMembers = usable.length;
    }
    for (final i in idx) {
      final h = usable.where((m) => m[i]! >= wetHourMm).length / usable.length;
      final key = f.hourEnds[i].millisecondsSinceEpoch;
      hourShare[key] = hourShare[key] == null || h > hourShare[key]!
          ? h
          : hourShare[key]!;
    }
  }
  if (bestShare == null) return null;
  final keys = hourShare.keys.toList()..sort();
  return Verdict(
    umbrella: bestShare >= threshold,
    wet: bestWet,
    members: bestMembers,
    hours: [
      for (final k in keys)
        HourChance(
          start: DateTime.fromMillisecondsSinceEpoch(
            k,
          ).subtract(const Duration(hours: 1)),
          share: hourShare[k]!,
        ),
    ],
  );
}
