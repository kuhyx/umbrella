import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:umbrella/core/settings.dart';
import 'package:umbrella/services/store.dart';
import 'package:umbrella/ui/place_tile.dart';
import 'package:umbrella/ui/settings_screen.dart';
import 'package:umbrella/ui/today_screen.dart';
import 'package:umbrella/ui/umbrella_glyph.dart';

import '../helpers.dart';

Future<Store> storeWith(Settings s) async {
  SharedPreferences.setMockInitialValues({});
  final store = await Store.open();
  await store.saveSettings(s);
  return store;
}

/// Every weekday, all day, so "now" is always inside an outing.
Settings allDay({Place? h}) =>
    settingsWith(home: h, leave: 0, back: 23 * 60 + 59, weekends: true);

Map<String, dynamic> wetNow({required bool wet}) {
  final now = DateTime.now();
  return openMeteo(
    firstEnd: DateTime(now.year, now.month, now.day - 1, 1),
    rain: List.generate(4, (_) => List.filled(96, wet ? 1.0 : 0.0)),
  );
}

Widget app(Widget home, {Key? key}) =>
    MaterialApp(key: key, theme: buildDarkTheme(), home: home);

void main() {
  var armed = 0;
  Future<void> arm(Store _) async => armed++;
  setUp(() => armed = 0);

  testWidgets('no home: asks for it and still arms', (t) async {
    final s = await storeWith(allDay());
    await t.pumpWidget(
      app(TodayScreen(store: s, fetch: (_) async => {}, arm: arm)),
    );
    await t.pumpAndSettle();
    expect(find.text('Where is home?'), findsOneWidget);
    expect(armed, 1);
  });

  testWidgets('nothing planned', (t) async {
    final off = Settings.defaults().copyWith(
      home: home,
      days: [
        for (final d in Settings.defaults().days) d.copyWith(enabled: false),
      ],
    );
    final s = await storeWith(off);
    await t.pumpWidget(
      app(TodayScreen(store: s, fetch: (_) async => {}, arm: arm)),
    );
    await t.pumpAndSettle();
    expect(find.text('No days planned'), findsOneWidget);
  });

  testWidgets('wet: big umbrella, percent, strip; refresh re-checks', (
    t,
  ) async {
    final s = await storeWith(allDay(h: home));
    await t.pumpWidget(
      app(
        TodayScreen(store: s, fetch: (_) async => wetNow(wet: true), arm: arm),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Take an umbrella'), findsOneWidget);
    expect(find.text('100% chance of rain'), findsOneWidget);
    expect(find.textContaining('4 forecast variants'), findsOneWidget);
    final glyph = t.widget<UmbrellaGlyph>(find.byType(UmbrellaGlyph));
    expect(glyph.crossed, isFalse);
    await t.tap(find.byTooltip('Check again'));
    await t.pumpAndSettle();
    expect(armed, 2);
  });

  testWidgets('dry from cache: crossed umbrella and offline footer', (t) async {
    final s = await storeWith(allDay(h: home));
    await s.saveForecast(home, wetNow(wet: false), DateTime.now());
    await t.pumpWidget(
      app(
        TodayScreen(
          store: s,
          fetch: (_) async => throw http.ClientException('offline'),
          arm: arm,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('No umbrella'), findsOneWidget);
    expect(find.text('100% sure it stays dry'), findsOneWidget);
    expect(find.textContaining('offline'), findsOneWidget);
    expect(t.widget<UmbrellaGlyph>(find.byType(UmbrellaGlyph)).crossed, true);
  });

  testWidgets('no data at all says so', (t) async {
    final s = await storeWith(allDay(h: home));
    await t.pumpWidget(
      app(
        TodayScreen(
          store: s,
          fetch: (_) async => throw http.ClientException('offline'),
          arm: arm,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('No connection'), findsOneWidget);
  });

  testWidgets('settings: GPS, typed coords, clear, days, sliders', (t) async {
    // Tall enough that the lazy list builds the sliders at the bottom.
    t.view.physicalSize = const Size(1080, 6000);
    addTearDown(t.view.reset);
    final s = await storeWith(Settings.defaults());
    var gpsFails = false;
    Future<Place> locate() async =>
        gpsFails ? throw StateError('denied') : home;
    await t.pumpWidget(
      app(
        TodayScreen(store: s, fetch: (_) async => wetNow(wet: false), arm: arm),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('open-settings')));
    await t.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(armed, 2, reason: 'closing settings re-arms');
    // A fresh app (new key) so the settings screen gets the fake locator.
    await t.pumpWidget(
      app(
        SettingsScreen(store: s, locate: locate),
        key: UniqueKey(),
      ),
    );
    await t.pumpAndSettle();

    await t.tap(find.byTooltip('Home: use current location'));
    await t.pumpAndSettle();
    expect(s.settings.home!.label, home.label);

    gpsFails = true;
    await t.tap(find.byTooltip('Destination (optional): use current location'));
    await t.pumpAndSettle();
    expect(find.textContaining("Couldn't get location"), findsOneWidget);

    Future<void> typeCoords(String text) async {
      await t.tap(find.byTooltip('Destination (optional): type coordinates'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('coords-field')), text);
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
    }

    await typeCoords('nonsense');
    expect(s.settings.destination, isNull);
    await typeCoords('52.2297 21.0122');
    expect(s.settings.destination!.lon, 21.0122);
    await t.tap(find.byTooltip('Destination (optional): type coordinates'));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Destination (optional): clear'));
    await t.pumpAndSettle();
    expect(s.settings.destination, isNull);

    await t.tap(find.byKey(const Key('day-0')));
    await t.pumpAndSettle();
    expect(s.settings.days.first.enabled, isFalse);

    await t.drag(find.byType(Slider).first, const Offset(400, 0));
    await t.pumpAndSettle();
    expect(s.settings.notifyOffsetMin, greaterThan(30));
    await t.drag(find.byType(Slider).last, const Offset(400, 0));
    await t.pumpAndSettle();
    expect(s.settings.thresholdPct, greaterThan(30));
  });

  testWidgets('settings: time pickers save leave and back', (t) async {
    final s = await storeWith(Settings.defaults());
    await t.pumpWidget(app(SettingsScreen(store: s)));
    await t.pumpAndSettle();
    for (final label in ['08:00', '17:00']) {
      await t.tap(find.text(label).first);
      await t.pumpAndSettle();
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
    }
    expect(s.settings.days.first.leaveMin, 480);
    await t.tap(find.text('08:00').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
  });

  test('parsePlace validates range and shape', () {
    expect(parsePlace('52.1, 21.0')!.lat, 52.1);
    expect(parsePlace('91 0'), isNull);
    expect(parsePlace('1 2 3'), isNull);
    expect(parsePlace('a b'), isNull);
  });
}
