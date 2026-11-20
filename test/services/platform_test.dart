import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:platform_location/platform_location.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:umbrella/core/message.dart';
import 'package:umbrella/core/schedule.dart';
import 'package:umbrella/core/settings.dart';
import 'package:umbrella/services/alarms.dart';
import 'package:umbrella/services/check_runner.dart';
import 'package:umbrella/services/notifier.dart';
import 'package:umbrella/services/store.dart';
import 'package:umbrella/ui/place_tile.dart';

import '../helpers.dart';

const _notifications = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);

class FakeGeo extends PlatformLocation {
  FakeGeo(this.first, this.afterRequest);

  final LocationPermissionState first;
  final LocationPermissionState afterRequest;
  bool? precise;
  int reads = 0;

  @override
  Future<bool> isLocationEnabled() async => true;

  @override
  Future<LocationPermissionState> checkPermission() async => first;

  @override
  Future<LocationPermissionState> requestPermission({
    bool precise = true,
  }) async {
    this.precise = precise;
    return afterRequest;
  }

  @override
  Future<LocationFix> currentLocation() async {
    reads++;
    return LocationFix(
      time: DateTime.utc(2026),
      latitude: home.lat,
      longitude: home.lon,
      accuracy: 1000,
    );
  }

  @override
  Stream<LocationFix> fixes({Duration interval = Duration.zero}) =>
      const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final ch in [
      _notifications,
      const MethodChannel('umbrella/alarm'),
      const MethodChannel('umbrella/bg'),
    ]) {
      messenger.setMockMethodCallHandler(ch, (c) async {
        calls.add(c);
        return ch == _notifications ? true : null;
      });
    }
  });

  test('Notifier initialises, asks permission and posts one id', () async {
    final n = Notifier();
    await n.init();
    expect(await n.requestPermission(), isTrue);
    await n.show((title: 'T', body: 'B'));
    final show = calls.lastWhere((c) => c.method == 'show');
    final args = show.arguments as Map<Object?, Object?>;
    expect((args['id'], args['title'], args['body']), (1, 'T', 'B'));
  });

  test(
    'runBackground main: fetches, notifies, re-arms, reports done',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = await Store.open();
      await store.saveSettings(
        settingsWith(home: home, leave: 0, back: 23 * 60 + 59, weekends: true),
      );
      final client = MockClient((_) async => http.Response('nope', 500));
      await runBackground('main', notifier: Notifier(), client: client);
      final methods = calls.map((c) => c.method).toList();
      expect(
        methods,
        containsAllInOrder(['initialize', 'show', 'arm', 'done']),
      );
      final show = calls.firstWhere((c) => c.method == 'show');
      expect((show.arguments as Map)['title'], cannotCheck.title);
      // Default notifier path (the real plugin, on the mocked channel).
      calls.clear();
      await runBackground('main', client: client);
      expect(calls.map((c) => c.method), contains('show'));
    },
  );

  group('locateWithGps', () {
    final original = PlatformLocation.instance;
    tearDown(() => PlatformLocation.instance = original);

    test('granted after asking for coarse only', () async {
      final geo = FakeGeo(
        LocationPermissionState.denied,
        LocationPermissionState.granted,
      );
      PlatformLocation.instance = geo;
      expect(await locateWithGps(), home);
      expect(geo.precise, isFalse);
    });

    test('already granted does not ask', () async {
      final geo = FakeGeo(
        LocationPermissionState.granted,
        LocationPermissionState.denied,
      );
      PlatformLocation.instance = geo;
      expect(await locateWithGps(), home);
      expect(geo.precise, isNull);
    });

    test('refused never reads a fix', () async {
      for (final refusal in [
        LocationPermissionState.denied,
        LocationPermissionState.deniedForever,
      ]) {
        final geo = FakeGeo(LocationPermissionState.denied, refusal);
        PlatformLocation.instance = geo;
        await expectLater(locateWithGps(), throwsStateError);
        expect(geo.reads, 0);
      }
    });
  });

  test('platform_location default is the method-channel one', () {
    expect(PlatformLocation.instance, isA<MethodChannelPlatformLocation>());
  });

  test('Place equality is by value', () {
    expect(const Place(lat: 1, lon: 2), const Place(lat: 1, lon: 2));
    expect(
      const Place(lat: 1, lon: 2).hashCode,
      const Place(lat: 1, lon: 2).hashCode,
    );
    expect(const Place(lat: 1, lon: 2), isNot(const Place(lat: 2, lon: 1)));
  });

  test('offline at two places reports the older cache', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await Store.open();
    final s = settingsWith(home: home, destination: work);
    final now = DateTime(2026, 9, 25, 7, 30);
    Map<String, dynamic> dry() => openMeteo(
      firstEnd: friday.add(const Duration(hours: 1)),
      rain: [List.filled(48, 0.0)],
    );
    await store.saveForecast(
      home,
      dry(),
      now.subtract(const Duration(hours: 2)),
    );
    await store.saveForecast(
      work,
      dry(),
      now.subtract(const Duration(hours: 9)),
    );
    final r = await evaluate(
      settings: s,
      outing: _outing(),
      now: now,
      fetch: (_) async => throw http.ClientException('offline'),
      store: store,
    );
    expect(r!.staleness, const Duration(hours: 9));
    // Same again with the older one first, so both comparisons are taken.
    await store.saveForecast(
      home,
      dry(),
      now.subtract(const Duration(hours: 12)),
    );
    final r2 = await evaluate(
      settings: s,
      outing: _outing(),
      now: now,
      fetch: (_) async => throw http.ClientException('offline'),
      store: store,
    );
    expect(r2!.staleness, const Duration(hours: 12));
  });
}

Outing _outing() =>
    Outing(leave: DateTime(2026, 9, 25, 8), back: DateTime(2026, 9, 25, 17));
