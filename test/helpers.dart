import 'package:umbrella/core/settings.dart';

/// 2026-09-25 is a Friday; hour ends are UTC but these tests use local
/// DateTimes throughout, so the mapping is tested in whatever zone runs them.
final DateTime friday = DateTime(2026, 9, 25);

const Place home = Place(lat: 52.2342, lon: 20.9767);
const Place work = Place(lat: 52.2297, lon: 21.0122);

/// Builds an Open-Meteo-shaped payload: [rain] is members x hours, starting
/// with the hour ending at [firstEnd]. Member 0 is the control run (`rain`).
Map<String, dynamic> openMeteo({
  required DateTime firstEnd,
  required List<List<double?>> rain,
  List<List<double?>>? showers,
}) {
  final hours = rain.first.length;
  String key(String v, int m) =>
      m == 0 ? v : '${v}_member${m.toString().padLeft(2, '0')}';
  return {
    'hourly': {
      'time': [
        for (var i = 0; i < hours; i++)
          firstEnd.add(Duration(hours: i)).millisecondsSinceEpoch ~/ 1000,
      ],
      for (var m = 0; m < rain.length; m++) key('rain', m): rain[m],
      if (showers != null)
        for (var m = 0; m < showers.length; m++) key('showers', m): showers[m],
    },
  };
}

Settings settingsWith({
  Place? home,
  Place? destination,
  int leave = 8 * 60,
  int back = 17 * 60,
  bool weekends = false,
}) => Settings.defaults().copyWith(
  home: home,
  destination: destination,
  days: List.generate(
    7,
    (i) => DayPlan(enabled: weekends || i < 5, leaveMin: leave, backMin: back),
  ),
);
