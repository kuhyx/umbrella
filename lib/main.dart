/// Umbrella? -- one answer a day: take an umbrella or not, and how sure.
library;

import 'dart:ui';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:umbrella/services/alarms.dart';
import 'package:umbrella/services/notifier.dart';
import 'package:umbrella/services/open_meteo.dart';
import 'package:umbrella/services/store.dart';
import 'package:umbrella/ui/today_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notifier = Notifier();
  await notifier.init();
  // Asked up front: the whole point of the app is the notification.
  await notifier.requestPermission();
  final store = await Store.open();
  final client = http.Client();
  runApp(
    MaterialApp(
      title: 'Umbrella?',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      home: TodayScreen(
        store: store,
        fetch: (p) => fetchEnsemble(client, p),
        arm: armNext,
      ),
    ),
  );
}

/// Entry point for CheckService's headless engine (see alarms.dart).
@pragma('vm:entry-point')
Future<void> backgroundMain(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await runBackground(args.isEmpty ? rearmKind : args.first);
}
