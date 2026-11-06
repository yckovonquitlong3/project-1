import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Shared wrapper around `flutter_local_notifications`.
///
/// Supports immediate alerts and inexact scheduled reminders. Tap payloads use
/// the form `subscription:<id>`.
class LocalNotificationService {
  LocalNotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  static const String reminderChannelId = 'subscription_reminders';
  static const String alertChannelId = 'subscription_alerts';
  static const String payloadPrefix = 'subscription:';

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<String> _taps = StreamController<String>.broadcast();

  Future<void>? _initializing;
  bool _initialized = false;
  String? _pendingTap;

  Stream<String> get subscriptionTapIds => _taps.stream;

  String? takePendingTap() {
    final String? value = _pendingTap;
    _pendingTap = null;
    return value;
  }

  Future<void> initialize() {
    if (_initialized) {
      return Future<void>.value();
    }
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    tz.initializeTimeZones();
    final TimezoneInfo zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handlePayload(response.payload);
      },
    );

    final NotificationAppLaunchDetails? launch =
        await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _handlePayload(launch?.notificationResponse?.payload);
    }

    _initialized = true;
    _initializing = null;
  }

  Future<bool> requestPermission() async {
    await initialize();
    final AndroidFlutterLocalNotificationsPlugin? android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<bool> notificationsEnabled() async {
    await initialize();
    final AndroidFlutterLocalNotificationsPlugin? android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? true;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    await initialize();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          alertChannelId,
          'Subscription alerts',
          channelDescription: 'Subscription payment results and warnings',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: payload,
    );
  }

  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) async {
    await initialize();
    if (!when.isAfter(DateTime.now())) {
      return;
    }
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          reminderChannelId,
          'Subscription reminders',
          channelDescription: 'Upcoming and due subscription reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<void> cancelAllScheduled() async {
    await initialize();
    await _plugin.cancelAllPendingNotifications();
  }

  void _handlePayload(String? payload) {
    if (payload == null || !payload.startsWith(payloadPrefix)) {
      return;
    }
    final String id = payload.substring(payloadPrefix.length);
    if (id.isEmpty) {
      return;
    }
    _pendingTap = id;
    if (!_taps.isClosed) {
      _taps.add(id);
    }
  }

  Future<void> dispose() async {
    await _taps.close();
  }
}
