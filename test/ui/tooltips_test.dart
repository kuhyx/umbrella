import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:umbrella/core/settings.dart';
import 'package:umbrella/services/store.dart';
import 'package:umbrella/ui/settings_screen.dart';
import 'package:umbrella/ui/today_screen.dart';
import 'package:umbrella/ui/verdict_view.dart';

import '../helpers.dart';

Widget app(Widget home, {Key? key}) =>
    MaterialApp(key: key, theme: buildDarkTheme(), home: home);

void main() {
  var armed = 0;
  Future<void> arm(Store _) async => armed++;
  setUp(() => armed = 0);

  testWidgets('today screen has settings and refresh tooltips', (t) async {
    final s = await storeWith(allDay(h: home));
    await t.pumpWidget(
      app(
        TodayScreen(store: s, fetch: (_) async => wetNow(wet: false), arm: arm),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byTooltip('settings'), findsOneWidget);
    expect(find.byTooltip('refresh'), findsOneWidget);
  });

  testWidgets('wet verdict shows sun tooltip', (t) async {
    final s = await storeWith(allDay(h: home));
    await t.pumpWidget(
      app(
        TodayScreen(store: s, fetch: (_) async => wetNow(wet: true), arm: arm),
      ),
    );
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 2));
    expect(find.byTooltip('sun'), findsOneWidget);
  });

  testWidgets('dry verdict shows umbrella tooltip', (t) async {
    final s = await storeWith(allDay(h: home));
    await t.pumpWidget(
      app(
        TodayScreen(store: s, fetch: (_) async => wetNow(wet: false), arm: arm),
      ),
    );
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 2));
    expect(find.byTooltip('umbrella'), findsOneWidget);
  });

  testWidgets('settings screen has places tooltip', (t) async {
    final s = await storeWith(Settings.defaults());
    await t.pumpWidget(app(SettingsScreen(store: s)));
    await t.pumpAndSettle();
    expect(find.byTooltip('places'), findsOneWidget);
  });

  testWidgets('long press tooltip shows message', (t) async {
    final s = await storeWith(allDay(h: home));
    await t.pumpWidget(
      app(
        TodayScreen(store: s, fetch: (_) async => wetNow(wet: false), arm: arm),
      ),
    );
    await t.pumpAndSettle();
    await t.longPress(find.byTooltip('settings'));
    await t.pumpAndSettle();
    expect(find.text('settings'), findsOneWidget);
  });
}
