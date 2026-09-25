import 'package:flutter_test/flutter_test.dart';
import 'package:umbrella/core/forecast.dart';
import 'package:umbrella/core/verdict.dart';

import '../helpers.dart';

void main() {
  // Hours ending 09:00 .. 12:00 on Friday -> buckets 08-09 .. 11-12.
  final firstEnd = friday.add(const Duration(hours: 9));

  group('EnsembleForecast.fromOpenMeteo', () {
    test('sums rain and showers per member, keeps nulls', () {
      final f = EnsembleForecast.fromOpenMeteo(
        openMeteo(
          firstEnd: firstEnd,
          rain: [
            [0.1, null],
            [0.0, 0.5],
          ],
          showers: [
            [0.1, 0.3],
            [null, 0.0],
          ],
        ),
      );
      expect(f.members, [
        [0.2, null],
        [0.0, 0.5],
      ]);
      expect(f.hourEnds.first.isAtSameMomentAs(firstEnd), isTrue);
    });

    test('works without a showers series', () {
      final f = EnsembleForecast.fromOpenMeteo(
        openMeteo(
          firstEnd: firstEnd,
          rain: [
            [0.4],
          ],
        ),
      );
      expect(f.members.single, [0.4]);
    });

    test('ignores non-rain keys and rejects payloads without members', () {
      expect(
        () => EnsembleForecast.fromOpenMeteo({
          'hourly': {
            'time': [0],
            'snowfall': [1],
          },
        }),
        throwsFormatException,
      );
      expect(
        () => EnsembleForecast.fromOpenMeteo({'hourly': 3}),
        throwsFormatException,
      );
      expect(
        () => EnsembleForecast.fromOpenMeteo({
          'hourly': {'time': 'x'},
        }),
        throwsFormatException,
      );
    });

    test('hoursOverlapping maps a non-round window to hour-end stamps', () {
      final f = EnsembleForecast.fromOpenMeteo(
        openMeteo(
          firstEnd: firstEnd,
          rain: [
            [0, 0, 0, 0],
          ],
        ),
      );
      // 08:30-10:00 touches buckets ending 09:00 and 10:00, not 11:00.
      expect(
        f.hoursOverlapping(
          friday.add(const Duration(hours: 8, minutes: 30)),
          friday.add(const Duration(hours: 10)),
        ),
        [0, 1],
      );
      // Leaving exactly at 09:00 skips the bucket ending at 09:00.
      expect(
        f.hoursOverlapping(
          friday.add(const Duration(hours: 9)),
          friday.add(const Duration(hours: 10, minutes: 1)),
        ),
        [1, 2],
      );
    });
  });

  group('decide', () {
    EnsembleForecast fc(List<List<double?>> rain) =>
        EnsembleForecast.fromOpenMeteo(
          openMeteo(firstEnd: firstEnd, rain: rain),
        );
    final start = friday.add(const Duration(hours: 8));
    final end = friday.add(const Duration(hours: 12));

    test('share = members with any wet hour; threshold decides', () {
      final v = decide(
        forecasts: [
          fc([
            [0, 0.2, 0, 0],
            [0, 0, 0, 0.1],
            [0, 0, 0, 0],
            [0.5, 0, 0, 0],
          ]),
        ],
        start: start,
        end: end,
        threshold: 0.5,
      )!;
      expect(v.umbrella, isTrue);
      expect(v.wet, 2);
      expect(v.members, 4);
      expect(v.rainShare, 0.5);
      expect(v.hours.map((h) => h.share), [0.25, 0.25, 0, 0]);
      expect(v.hours.first.start, start);
    });

    test('drops members with gaps; null when nothing usable', () {
      final v = decide(
        forecasts: [
          fc([
            [0, null, 0, 0],
            [0, 0, 0, 0],
          ]),
        ],
        start: start,
        end: end,
        threshold: 0.3,
      )!;
      expect(v.members, 1);
      expect(v.umbrella, isFalse);
      expect(
        decide(
          forecasts: [
            fc([
              [null, 0, 0, 0],
            ]),
          ],
          start: start,
          end: end,
          threshold: 0.3,
        ),
        isNull,
      );
    });

    test('null when no forecast covers the window', () {
      expect(
        decide(
          forecasts: [
            fc([
              [1, 1, 1, 1],
            ]),
          ],
          start: end.add(const Duration(days: 3)),
          end: end.add(const Duration(days: 3, hours: 2)),
          threshold: 0.3,
        ),
        isNull,
      );
      expect(
        decide(forecasts: [], start: start, end: end, threshold: 0.3),
        isNull,
      );
    });

    test('the wetter place wins; hour strip takes the max', () {
      final v = decide(
        forecasts: [
          fc([
            [0, 0, 0, 1],
            [0, 0, 0, 0],
          ]),
          fc([
            [1, 0, 0, 0],
            [1, 0, 0, 0],
            [0, 0, 0, 0],
          ]),
          fc([
            [0, 0, 0, 0],
          ]),
        ],
        start: start,
        end: end,
        threshold: 0.6,
      )!;
      expect(v.members, 3);
      expect(v.wet, 2);
      expect(v.umbrella, isTrue);
      expect(v.hours.map((h) => h.share).toList(), [2 / 3, 0, 0, 0.5]);
    });
  });

  group('Verdict', () {
    test('percentages round from integer counts (23/40 is 58)', () {
      const v = Verdict(umbrella: true, wet: 23, members: 40, hours: []);
      expect(v.rainPct, 58);
      expect(v.confidencePct, 58);
      const dry = Verdict(umbrella: false, wet: 1, members: 40, hours: []);
      expect(dry.confidencePct, 98);
    });

    test('wetSpan covers first to last hour at threshold', () {
      final a = friday.add(const Duration(hours: 9));
      final v = Verdict(
        umbrella: true,
        wet: 1,
        members: 2,
        hours: [
          HourChance(start: a, share: 0.5),
          HourChance(start: a.add(const Duration(hours: 1)), share: 0.1),
          HourChance(start: a.add(const Duration(hours: 2)), share: 0.6),
        ],
      );
      expect(v.wetSpan(0.5), (a, a.add(const Duration(hours: 3))));
      expect(v.wetSpan(0.9), isNull);
    });

    test('json round trip', () {
      final v = Verdict(
        umbrella: true,
        wet: 3,
        members: 40,
        hours: [HourChance(start: friday, share: 0.25)],
      );
      final back = Verdict.fromJson(v.toJson());
      expect(back.toJson(), v.toJson());
      expect(back.hours.single.start, friday);
    });
  });
}
