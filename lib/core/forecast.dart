/// An Open-Meteo ensemble forecast reduced to what the verdict needs:
/// liquid precipitation per forecast variant ("member") per hour.
library;

/// Hourly liquid precipitation for every ensemble member at one place.
class EnsembleForecast {
  /// Creates a forecast. [hourEnds] and every row of [members] line up.
  const EnsembleForecast({required this.hourEnds, required this.members});

  /// Parses an Open-Meteo `/v1/ensemble` response requested with
  /// `hourly=rain,showers&timeformat=unixtime`.
  ///
  /// Liquid = rain + showers. Snowfall is deliberately left out (nobody opens
  /// an umbrella for snow); sleet and freezing rain arrive as `rain`.
  /// Throws [FormatException] when the payload has no usable members.
  factory EnsembleForecast.fromOpenMeteo(Map<String, dynamic> json) {
    final hourly = json['hourly'];
    if (hourly is! Map<String, dynamic> || hourly['time'] is! List) {
      throw const FormatException('Open-Meteo response has no hourly.time');
    }
    final hourEnds = [
      for (final t in hourly['time'] as List<dynamic>)
        DateTime.fromMillisecondsSinceEpoch((t as int) * 1000, isUtc: true),
    ];
    final members = <List<double?>>[];
    // The control run is `rain`; perturbed runs are `rain_memberNN`.
    for (final key in hourly.keys) {
      if (key != 'rain' && !key.startsWith('rain_member')) continue;
      final rain = hourly[key] as List<dynamic>;
      final showers = hourly[key.replaceFirst('rain', 'showers')];
      members.add([
        for (var i = 0; i < rain.length; i++)
          _sum(rain[i], showers is List ? showers[i] : 0),
      ]);
    }
    if (members.isEmpty) {
      throw const FormatException('Open-Meteo response has no rain members');
    }
    return EnsembleForecast(hourEnds: hourEnds, members: members);
  }

  /// End of each hourly bucket, UTC. Open-Meteo precipitation is the total
  /// over the hour *preceding* the timestamp, so hour i covers
  /// (hourEnds[i] - 1h, hourEnds[i]].
  final List<DateTime> hourEnds;

  /// members[m][i] = liquid mm in hour i for member m; null = no data.
  final List<List<double?>> members;

  /// Indices of the hourly buckets that overlap [start, end).
  List<int> hoursOverlapping(DateTime start, DateTime end) => [
    for (var i = 0; i < hourEnds.length; i++)
      if (hourEnds[i].isAfter(start) &&
          hourEnds[i].subtract(const Duration(hours: 1)).isBefore(end))
        i,
  ];

  static double? _sum(Object? a, Object? b) {
    if (a == null) return null;
    return (a as num).toDouble() + ((b as num?)?.toDouble() ?? 0);
  }
}
