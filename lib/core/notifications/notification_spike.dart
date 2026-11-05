import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Temporary Phase 0 spike.
///
/// Schedules one notification two minutes ahead so we can verify on the real
/// phone whether it fires while the app is closed and after a reboot.
/// This file and its debug button are removed or replaced in Phase 3.
abstract final class NotificationSpike {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<String> scheduleTest() async {
    try {
      await _initialize();

      final AndroidFlutterLocalNotificationsPlugin? android =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final bool? granted =
          await android?.requestNotificationsPermission();
      if (granted == false) {
        return 'Notification permission was not granted.';
      }

      final tz.TZDateTime when =
          tz.TZDateTime.now(tz.local).add(const Duration(minutes: 2));
      final String time = '${when.hour.toString().padLeft(2, '0')}:'
          '${when.minute.toString().padLeft(2, '0')}';
      final int id = DateTime.now().millisecondsSinceEpoch.remainder(1000000);

      await _plugin.cancelAll();
      await _plugin.zonedSchedule(
        id: id,
        title: 'Notification spike',
        body: 'Scheduled for $time. If you can read this with the app closed, '
            'the spike passed.',
        scheduledDate: when,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'spike_channel',
            'Notification spike',
            channelDescription: 'Temporary Phase 0 test notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'notification-spike',
      );

      debugPrint('Notification spike #$id scheduled for $time ($when)');
      return 'Scheduled #$id for $time. Close the app and wait.';
    } catch (error) {
      debugPrint('Notification spike failed: $error');
      return 'Could not schedule: $error';
    }
  }

  static Future<void> _initialize() async {
    if (_initialized) {
      return;
    }
    tz.initializeTimeZones();
    final TimezoneInfo zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification spike tapped: ${response.payload}');
      },
    );
    _initialized = true;
    debugPrint('Notification spike initialized in ${zone.identifier}');
  }
}
