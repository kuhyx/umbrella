import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
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

class FakeGeo extends GeolocatorPlatform with MockPlatformInterfaceMixin {
  FakeGeo(this.first, this.afterRequest);

  final LocationPermission first;
  final LocationPermission afterRequest;

  @override
  Future<LocationPermission> checkPermission() async => first;

  @override
  Future<LocationPermission> requestPermission() async => afterRequest;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
    latitude: home.lat,
    longitude: home.lon,
    timestamp: DateTime(2026),
    accuracy: 1000,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
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
    test('granted after asking', () async {
      GeolocatorPlatform.instance = FakeGeo(
        LocationPermission.denied,
        LocationPermission.whileInUse,
      );
      expect(await locateWithGps(), home);
    });

    test('refused', () async {
      GeolocatorPlatform.instance = FakeGeo(
        LocationPermission.denied,
        LocationPermission.denied,
      );
      expect(locateWithGps(), throwsStateError);
      GeolocatorPlatform.instance = FakeGeo(
        LocationPermission.deniedForever,
        LocationPermission.deniedForever,
      );
      expect(locateWithGps(), throwsStateError);
    });
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
