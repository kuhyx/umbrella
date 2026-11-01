import 'dart:ui' as ui;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:umbrella/ui/today_screen.dart';

import '../helpers.dart';

/// Horizontal extent (logical px) of [ink]-coloured pixels between the app
/// bar and the verdict title, read from what was actually painted.
Future<(int, int)> inkSpan(WidgetTester t, GlobalKey shot, Color ink) async {
  final top = t.getBottomLeft(find.byType(AppBar)).dy.ceil();
  final bottom = t.getTopLeft(find.byKey(const Key('verdict-title'))).dy;
  final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(shot));
  final (w, bytes) = (await t.runAsync(() async {
    final img = await boundary.toImage();
    final raw = await img.toByteData();
    return (img.width, raw!);
  }))!;
  int ch(double v) => (v * 255).round();
  var (lo, hi) = (w, -1);
  for (var y = top; y < bottom; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final near =
          (bytes.getUint8(i) - ch(ink.r)).abs() < 8 &&
          (bytes.getUint8(i + 1) - ch(ink.g)).abs() < 8 &&
          (bytes.getUint8(i + 2) - ch(ink.b)).abs() < 8;
      if (near) (lo, hi) = (x < lo ? x : lo, x > hi ? x : hi);
    }
  }
  return (lo, hi);
}

void main() {
  for (final wet in [false, true]) {
    testWidgets('glyph (wet: $wet) fits a phone: margins, <=60% wide', (
      t,
    ) async {
      t.view
        ..physicalSize = const Size(1080, 2400)
        ..devicePixelRatio = 2.625
        ..padding = const FakeViewPadding(top: 105);
      addTearDown(t.view.reset);
      // A real 08-17 outing: 24 bars of Ahem digits overflow a 13 px column.
      final s = await storeWith(settingsWith(home: home, weekends: true));
      await s.saveForecast(home, wetNow(wet: wet), DateTime.now());
      final shot = GlobalKey();
      final theme = buildDarkTheme();
      await t.pumpWidget(
        RepaintBoundary(
          key: shot,
          child: MaterialApp(
            theme: theme,
            home: TodayScreen(
              store: s,
              fetch: (_) async => throw http.ClientException('offline'),
              arm: (_) async {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final ink = wet
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurfaceVariant;
      final (lo, hi) = await inkSpan(t, shot, ink);
      final width = t.view.physicalSize.width / t.view.devicePixelRatio;
      expect(hi, greaterThan(lo), reason: 'glyph not found');
      expect(lo, greaterThanOrEqualTo(24), reason: 'left edge at $lo');
      expect(hi, lessThanOrEqualTo(width - 24), reason: 'right edge at $hi');
      expect(hi - lo, lessThanOrEqualTo(width * 0.6), reason: 'too wide');
    });
  }
}
