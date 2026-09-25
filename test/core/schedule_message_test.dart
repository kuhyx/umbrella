import 'package:flutter_test/flutter_test.dart';
import 'package:umbrella/core/message.dart';
import 'package:umbrella/core/schedule.dart';
import 'package:umbrella/core/settings.dart';
import 'package:umbrella/core/verdict.dart';

import '../helpers.dart';

DateTime at(int day, int h, [int m = 0]) => DateTime(2026, 9, day, h, m);

void main() {
  group('schedule', () {
    final s = settingsWith(home: home);

    test('outingOn: disabled day is null; overnight back rolls over', () {
      expect(outingOn(s, at(26, 12)), isNull); // Saturday
      final o = outingOn(s, at(25, 3))!;
      expect(o.leave, at(25, 8));
      expect(o.back, at(25, 17));
      final night = outingOn(
        settingsWith(leave: 22 * 60, back: 2 * 60),
        at(25, 1),
      )!;
      expect(night.back, at(26, 2));
    });

    test('currentOuting: today while out, next weekday after, overnight', () {
      expect(currentOuting(s, at(25, 16))!.leave, at(25, 8));
      expect(currentOuting(s, at(25, 18))!.leave, at(28, 8));
      final night = settingsWith(leave: 22 * 60, back: 2 * 60);
      expect(currentOuting(night, at(26, 1))!.leave, at(25, 22));
      expect(currentOuting(_allOff(), at(25, 1)), isNull);
    });

    test('nextCheck: main, then re-check, then next day', () {
      final a = nextCheck(s, at(25, 7))!;
      expect((a.at, a.kind), (at(25, 7, 30), CheckKind.main));
      final b = nextCheck(s, at(25, 7, 30))!;
      expect((b.at, b.kind), (at(25, 7, 55), CheckKind.recheck));
      expect(b.outing.leave, at(25, 8));
      final c = nextCheck(s, at(25, 7, 55))!;
      expect((c.at, c.kind), (at(28, 7, 30), CheckKind.main));
      expect(nextCheck(_allOff(), at(25, 7)), isNull);
    });

    test('no re-check when it would not be after the main alarm', () {
      final tight = s.copyWith(notifyOffsetMin: 5);
      final a = nextCheck(tight, at(25, 7, 55))!;
      expect((a.at, a.kind), (at(28, 7, 55), CheckKind.main));
    });
  });

  group('messages', () {
    final nine = DateTime(2026, 9, 25, 9);
    final wet = Verdict(
      umbrella: true,
      wet: 27,
      members: 40,
      hours: [HourChance(start: nine, share: 0.6)],
    );

    test('umbrella with a wet span', () {
      final m = verdictMessage(wet, threshold: 0.3);
      expect(m.title, '☂️ Take umbrella');
      expect(m.body, '68% chance of rain, mostly 09:00–10:00');
    });

    test('umbrella without any hour at threshold', () {
      final m = verdictMessage(wet, threshold: 0.9);
      expect(m.body, '68% chance of rain');
    });

    test('dry, flipped, and stale variants', () {
      const dry = Verdict(umbrella: false, wet: 2, members: 40, hours: []);
      expect(verdictMessage(dry, threshold: 0.3), (
        title: 'No umbrella',
        body: '95% sure it stays dry',
      ));
      expect(
        verdictMessage(dry, threshold: 0.3, flipped: true).title,
        'Changed: No umbrella',
      );
      expect(
        verdictMessage(
          dry,
          threshold: 0.3,
          staleness: const Duration(hours: 13, minutes: 5),
        ).body,
        '95% sure it stays dry (offline: forecast from 13h ago)',
      );
      expect(
        verdictMessage(
          dry,
          threshold: 0.3,
          staleness: const Duration(minutes: 20),
        ).body,
        endsWith('from 20 min ago)'),
      );
    });

    test('fixed alerts say what to do', () {
      expect(cannotCheck.body, contains('Look outside'));
      expect(noHome.body, contains('home location'));
    });
  });

  group('settings', () {
    test('defaults: weekdays on, 08-17, 30 min, 30%', () {
      final d = Settings.defaults();
      expect(d.days.where((x) => x.enabled).length, 5);
      expect(d.notifyOffsetMin, 30);
      expect(d.thresholdPct, 30);
      expect(d.places, isEmpty);
    });

    test('json round trip with and without places', () {
      final s = settingsWith(home: home, destination: work);
      final back = Settings.fromJson(s.toJson());
      expect(back.toJson(), s.toJson());
      expect(back.places.map((p) => p.label), [home.label, work.label]);
      final none = Settings.fromJson(Settings.defaults().toJson());
      expect(none.home, isNull);
    });

    test('copyWith clears the destination only on request', () {
      final s = settingsWith(home: home, destination: work);
      expect(s.copyWith(thresholdPct: 50).destination, isNotNull);
      expect(s.copyWith(clearDestination: true).destination, isNull);
      final d = s.days.first.copyWith(enabled: false);
      expect((d.enabled, d.leaveMin, d.backMin), (false, 480, 1020));
    });
  });
}

Settings _allOff() => Settings.defaults().copyWith(
  days: [for (final d in Settings.defaults().days) d.copyWith(enabled: false)],
);
