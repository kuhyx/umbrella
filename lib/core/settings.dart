/// User settings: where rain matters, when they are out, how eager to warn.
library;

import 'package:flutter/foundation.dart' show immutable;

/// A saved point on the map (home or the usual destination).
@immutable
class Place {
  /// Creates a place.
  const Place({required this.lat, required this.lon});

  /// Reads a place written by [toJson].
  factory Place.fromJson(Map<String, dynamic> json) => Place(
    lat: (json['lat'] as num).toDouble(),
    lon: (json['lon'] as num).toDouble(),
  );

  /// Latitude in degrees.
  final double lat;

  /// Longitude in degrees.
  final double lon;

  /// JSON form for storage.
  Map<String, dynamic> toJson() => {'lat': lat, 'lon': lon};

  @override
  bool operator ==(Object other) =>
      other is Place && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);

  /// "52.2297, 21.0122" -- how the settings screen shows a place.
  String get label => '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}';
}

/// One weekday's plan: whether they go out, and leave/back times.
class DayPlan {
  /// Creates a day plan. Times are minutes after local midnight.
  const DayPlan({
    required this.enabled,
    required this.leaveMin,
    required this.backMin,
  });

  /// Reads a plan written by [toJson].
  factory DayPlan.fromJson(Map<String, dynamic> json) => DayPlan(
    enabled: json['enabled'] as bool,
    leaveMin: json['leave'] as int,
    backMin: json['back'] as int,
  );

  /// False means no check and no notification that day.
  final bool enabled;

  /// Leaving home (X), minutes after midnight.
  final int leaveMin;

  /// Coming back (Y), minutes after midnight. May be <= [leaveMin], which
  /// means "back after midnight", i.e. the next calendar day.
  final int backMin;

  /// JSON form for storage.
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'leave': leaveMin,
    'back': backMin,
  };

  /// Copy with some fields replaced.
  DayPlan copyWith({bool? enabled, int? leaveMin, int? backMin}) => DayPlan(
    enabled: enabled ?? this.enabled,
    leaveMin: leaveMin ?? this.leaveMin,
    backMin: backMin ?? this.backMin,
  );
}

/// Everything the user can set.
class Settings {
  /// Creates settings.
  const Settings({
    required this.home,
    required this.destination,
    required this.days,
    required this.notifyOffsetMin,
    required this.thresholdPct,
  });

  /// Mon-Fri 08:00 -> 17:00, weekends off, no places yet.
  factory Settings.defaults() => Settings(
    home: null,
    destination: null,
    days: List.generate(
      7,
      (i) => DayPlan(enabled: i < 5, leaveMin: 8 * 60, backMin: 17 * 60),
    ),
    notifyOffsetMin: 30,
    thresholdPct: 30,
  );

  /// Reads settings written by [toJson].
  factory Settings.fromJson(Map<String, dynamic> json) {
    Place? place(Object? raw) =>
        raw == null ? null : Place.fromJson(raw as Map<String, dynamic>);
    return Settings(
      home: place(json['home']),
      destination: place(json['destination']),
      days: [
        for (final d in json['days'] as List<dynamic>)
          DayPlan.fromJson(d as Map<String, dynamic>),
      ],
      notifyOffsetMin: json['offset'] as int,
      thresholdPct: json['threshold'] as int,
    );
  }

  /// Where the user lives. Null until set; nothing is checked without it.
  final Place? home;

  /// Optional second place; rain there counts as much as at home.
  final Place? destination;

  /// Seven plans, index 0 = Monday (DateTime.weekday - 1).
  final List<DayPlan> days;

  /// Minutes before leaving that the notification fires.
  final int notifyOffsetMin;

  /// Rain share (percent of forecast variants) at which to say "umbrella".
  final int thresholdPct;

  /// Places to check, home first.
  List<Place> get places => [?home, ?destination];

  /// JSON form for storage.
  Map<String, dynamic> toJson() => {
    'home': home?.toJson(),
    'destination': destination?.toJson(),
    'days': [for (final d in days) d.toJson()],
    'offset': notifyOffsetMin,
    'threshold': thresholdPct,
  };

  /// Copy with some fields replaced. Places use explicit clear flags because
  /// null is a meaningful value for them.
  Settings copyWith({
    Place? home,
    Place? destination,
    bool clearDestination = false,
    List<DayPlan>? days,
    int? notifyOffsetMin,
    int? thresholdPct,
  }) => Settings(
    home: home ?? this.home,
    destination: clearDestination ? null : destination ?? this.destination,
    days: days ?? this.days,
    notifyOffsetMin: notifyOffsetMin ?? this.notifyOffsetMin,
    thresholdPct: thresholdPct ?? this.thresholdPct,
  );
}
