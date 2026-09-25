/// Posts the daily notification. Works from the alarm's background isolate.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:umbrella/core/message.dart';

const _channel = AndroidNotificationDetails(
  'umbrella_daily',
  'Daily umbrella check',
  channelDescription: 'Once a day, shortly before you leave home.',
  importance: Importance.high,
  priority: Priority.high,
  icon: 'ic_stat_umbrella',
);

/// One id: a newer answer for the same day replaces the older one.
const int _notificationId = 1;

/// Sends notifications; the only place that touches the plugin.
class Notifier {
  /// Wraps [plugin] (injectable for tests).
  Notifier([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Must run once per isolate before [show].
  Future<void> init() => _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_umbrella'),
    ),
  );

  /// Asks for POST_NOTIFICATIONS (Android 13+). True if granted.
  Future<bool> requestPermission() async =>
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission() ??
      false;

  /// Posts [m], replacing any earlier umbrella notification.
  Future<void> show(Alert m) => _plugin.show(
    id: _notificationId,
    title: m.title,
    body: m.body,
    notificationDetails: const NotificationDetails(android: _channel),
  );
}
