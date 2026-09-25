import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:umbrella/core/settings.dart';
import 'package:umbrella/services/alarms.dart';
import 'package:umbrella/services/store.dart';

import '../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in ['umbrella/alarm', 'umbrella/bg']) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (c) async {
        calls.add(c);
        return null;
      });
    }
  });

  Future<Store> store(Settings s) async {
    SharedPreferences.setMockInitialValues({});
    final st = await Store.open();
    await st.saveSettings(s);
    return st;
  }

  test('armNext sends the next check to the native scheduler', () async {
    final s = await store(settingsWith(home: home));
    final next = await armNext(s, now: DateTime(2026, 9, 25, 7));
    expect(next!.at, DateTime(2026, 9, 25, 7, 30));
    expect(calls.single.method, 'arm');
    expect(calls.single.arguments, {
      'at': DateTime(2026, 9, 25, 7, 30).millisecondsSinceEpoch,
      'kind': 'main',
    });
  });

  test('armNext cancels when nothing is planned', () async {
    final off = Settings.defaults().copyWith(
      days: [
        for (final d in Settings.defaults().days) d.copyWith(enabled: false),
      ],
    );
    expect(await armNext(await store(off)), isNull);
    expect(calls.single.method, 'cancel');
  });

  test('rearm run skips the check, re-arms, and reports done', () async {
    await store(settingsWith(home: home));
    await runBackground(rearmKind);
    expect(calls.map((c) => c.method), ['arm', 'done']);
  });
}
