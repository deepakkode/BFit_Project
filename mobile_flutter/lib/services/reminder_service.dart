import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/reminder_schedule_logic.dart';

class ReminderSettings {
  const ReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  final bool enabled;
  final int hour;
  final int minute;
}

class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void>? _initialization;
  Future<void>? _pluginInitialization;
  static const _enabledKey = 'bfit.reminder.enabled';
  static const _hourKey = 'bfit.reminder.hour';
  static const _minuteKey = 'bfit.reminder.minute';
  static const _timezoneKey = 'bfit.reminder.timezone';
  String? initializationError;

  Future<void> initialize() {
    final inProgress = _initialization;
    if (inProgress != null) return inProgress;
    final task = _initializeAndReconcile();
    _initialization = task;
    return task.whenComplete(() {
      if (identical(_initialization, task)) _initialization = null;
    });
  }

  Future<void> _initializeAndReconcile() async {
    try {
      await _initializePlugin();
      final zoneName = await _setLocalTimezone();
      final prefs = await SharedPreferences.getInstance();
      final previousZone = prefs.getString(_timezoneKey);
      final enabled = prefs.getBool(_enabledKey) ?? false;
      if (enabled && previousZone != zoneName) {
        await _schedule(
          prefs.getInt(_hourKey) ?? 18,
          prefs.getInt(_minuteKey) ?? 0,
        );
      }
      await prefs.setString(_timezoneKey, zoneName);
      initializationError = null;
    } catch (error) {
      initializationError = error.toString().replaceFirst('Bad state: ', '');
      rethrow;
    }
  }

  Future<void> initializeSafely() async {
    try {
      await initialize();
    } catch (_) {
      // The profile screen exposes initialization failures beside the reminder.
    }
  }

  Future<void> _initializePlugin() {
    if (_initialized) return Future<void>.value();
    final inProgress = _pluginInitialization;
    if (inProgress != null) return inProgress;
    final task = _initializePluginOnce();
    _pluginInitialization = task;
    return task.whenComplete(() {
      if (identical(_pluginInitialization, task)) _pluginInitialization = null;
    });
  }

  Future<void> _initializePluginOnce() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_notification'),
      iOS: DarwinInitializationSettings(),
    );
    await _notifications.initialize(settings);
    const channel = AndroidNotificationChannel(
      'bfit_daily_movement',
      'Daily movement reminder',
      description: 'A gentle, optional reminder to move a little.',
      importance: Importance.defaultImportance,
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    _initialized = true;
  }

  Future<String> _setLocalTimezone() async {
    final dynamic localZone = await FlutterTimezone.getLocalTimezone();
    final String zoneName =
        localZone is String ? localZone : localZone.identifier as String;
    tz.setLocalLocation(tz.getLocation(zoneName));
    return zoneName;
  }

  Future<ReminderSettings> readSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return ReminderSettings(
      enabled: prefs.getBool(_enabledKey) ?? false,
      hour: prefs.getInt(_hourKey) ?? 18,
      minute: prefs.getInt(_minuteKey) ?? 0,
    );
  }

  Future<void> setEnabled(bool enabled, {int? hour, int? minute}) async {
    await _initializePlugin();
    final prefs = await SharedPreferences.getInstance();
    final old = await readSettings();
    final selectedHour = hour ?? old.hour;
    final selectedMinute = minute ?? old.minute;
    if (enabled) {
      final zoneName = await _setLocalTimezone();
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      final ios = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final iosGranted = await ios?.requestPermissions(
        alert: true,
        badge: false,
        sound: true,
      );
      if (granted == false || iosGranted == false) {
        throw StateError(
          'Notifications were not enabled. Allow BFit notifications in device settings and try again.',
        );
      }
      await _schedule(selectedHour, selectedMinute);
      await prefs.setString(_timezoneKey, zoneName);
    } else {
      await _notifications.cancel(1);
    }
    await prefs.setBool(_enabledKey, enabled);
    await prefs.setInt(_hourKey, selectedHour);
    await prefs.setInt(_minuteKey, selectedMinute);
  }

  Future<void> _schedule(int hour, int minute) async {
    final now = tz.TZDateTime.now(tz.local);
    final next = nextLocalReminder(now, hour: hour, minute: minute);
    await _notifications.zonedSchedule(
      1,
      'A little movement, when it suits you',
      'Take a short walk or stretch. Small moments add up.',
      next,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'bfit_daily_movement',
          'Daily movement reminder',
          channelDescription: 'A gentle, optional reminder to move a little.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
