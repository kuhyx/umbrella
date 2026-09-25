import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:umbrella/core/message.dart';
import 'package:umbrella/core/schedule.dart';
import 'package:umbrella/core/settings.dart';
import 'package:umbrella/core/verdict.dart';
import 'package:umbrella/services/check_runner.dart';
import 'package:umbrella/services/open_meteo.dart';
import 'package:umbrella/services/store.dart';

import '../helpers.dart';

/// Friday 07:30, the main check for an 08:00-17:00 outing.
final DateTime mainAt = DateTime(2026, 9, 25, 7, 30);

/// All members wet in every hour (or dry) for Friday 00:00 .. +48h.
Map<String, dynamic> payload({required bool wet, int members = 4}) => openMeteo(
  firstEnd: friday.add(const Duration(hours: 1)),
  rain: List.generate(members, (_) => List.filled(48, wet ? 1.0 : 0.0)),
);

Future<Store> freshStore([Settings? s]) async {
  SharedPreferences.setMockInitialValues({});
  final store = await Store.open();
  if (s != null) await store.saveSettings(s);
  return store;
}

void main() {
  late List<Alert> sent;
  Future<void> notify(Alert m) async => sent.add(m);
  Fetch returns(Map<String, dynamic> json) =>
      (_) async => json;
  Future<Map<String, dynamic>> fails(Place _) async =>
      throw http.ClientException('offline');

  setUp(() => sent = []);

  Future<void> run(Store s, Fetch fetch, {CheckKind kind = CheckKind.main}) =>
      runCheck(kind: kind, now: mainAt, store: s, fetch: fetch, notify: notify);

  test('main check notifies a live verdict and caches it', () async {
    final s = await freshStore(settingsWith(home: home));
    await run(s, returns(payload(wet: true)));
    expect(sent.single.title, '☂️ Take umbrella');
    expect(sent.single.body, startsWith('100% chance of rain'));
    expect(s.lastVerdict!.leave, DateTime(2026, 9, 25, 8));
    expect(s.lastVerdict!.stale, isFalse);
    expect(s.cachedForecast(home)!.fetchedAt, mainAt);
  });

  test('offline falls back to the cache and says how old it is', () async {
    final s = await freshStore(settingsWith(home: home));
    await s.saveForecast(
      home,
      payload(wet: false),
      mainAt.subtract(const Duration(hours: 10)),
    );
    await run(s, fails);
    expect(
      sent.single.body,
      '100% sure it stays dry '
      '(offline: forecast from 10h ago)',
    );
    expect(s.lastVerdict!.stale, isTrue);
  });

  test('offline without cache says so, never silence', () async {
    final s = await freshStore(settingsWith(home: home));
    await run(s, fails);
    expect(sent.single, cannotCheck);
    sent.clear();
    await run(s, fails, kind: CheckKind.recheck);
    expect(sent.single, cannotCheck);
  });

  test('re-check is quiet unless the answer flipped', () async {
    final s = await freshStore(settingsWith(home: home));
    await run(s, returns(payload(wet: false)));
    sent.clear();
    await run(s, returns(payload(wet: false)), kind: CheckKind.recheck);
    expect(sent, isEmpty);
    await run(s, fails, kind: CheckKind.recheck);
    expect(sent, isEmpty, reason: 'cached answer unchanged');
    await run(s, returns(payload(wet: true)), kind: CheckKind.recheck);
    expect(sent.single.title, 'Changed: ☂️ Take umbrella');
  });

  test('re-check without an earlier answer notifies normally', () async {
    final s = await freshStore(settingsWith(home: home));
    await run(s, returns(payload(wet: true)), kind: CheckKind.recheck);
    expect(sent.single.title, '☂️ Take umbrella');
  });

  test('no home: main asks for it, re-check stays quiet', () async {
    final s = await freshStore(settingsWith());
    await run(s, returns(payload(wet: true)));
    expect(sent.single, noHome);
    sent.clear();
    await run(s, returns(payload(wet: true)), kind: CheckKind.recheck);
    expect(sent, isEmpty);
  });

  test('nothing planned: nothing sent', () async {
    final off = Settings.defaults().copyWith(
      home: home,
      days: [
        for (final d in Settings.defaults().days) d.copyWith(enabled: false),
      ],
    );
    final s = await freshStore(off);
    await run(s, returns(payload(wet: true)));
    expect(sent, isEmpty);
  });

  test('destination counts: dry home, wet work -> umbrella', () async {
    final s = await freshStore(settingsWith(home: home, destination: work));
    await run(s, (p) async => payload(wet: p == work));
    expect(sent.single.title, '☂️ Take umbrella');
  });

  group('store', () {
    test(
      'defaults on first run; corrupt saved verdict reads as absent',
      () async {
        final s = await freshStore();
        expect(s.settings.home, isNull);
        expect(s.lastVerdict, isNull);
        expect(s.cachedForecast(home), isNull);
        await s.prefs.setString('last_verdict', '{"verdict":{"share":0.5}}');
        expect(s.lastVerdict, isNull);
        const v = Verdict(umbrella: false, wet: 0, members: 1, hours: []);
        await s.saveVerdict(v, mainAt, mainAt, stale: false);
        expect(s.lastVerdict!.decidedAt, mainAt);
      },
    );
  });

  group('open_meteo', () {
    test('builds a keyless ICON ensemble request', () {
      final u = ensembleUri(home);
      expect(u.host, 'ensemble-api.open-meteo.com');
      expect(u.queryParameters, {
        'latitude': '52.2342',
        'longitude': '20.9767',
        'hourly': 'rain,showers',
        'models': 'icon_seamless',
        'timeformat': 'unixtime',
        'forecast_days': '4',
      });
    });

    test('returns JSON on 200 and throws otherwise', () async {
      final ok = MockClient((_) async => http.Response('{"a":1}', 200));
      expect(await fetchEnsemble(ok, home), {'a': 1});
      final bad = MockClient((_) async => http.Response('nope', 429));
      expect(fetchEnsemble(bad, home), throwsA(isA<http.ClientException>()));
      expect(jsonEncode(await fetchEnsemble(ok, home)), '{"a":1}');
    });
  });
}
