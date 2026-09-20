import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'daily_party_notification_schedule.dart';

const dailyPartyNotificationsEnabledKey = 'daily_party_notifications_enabled';
const dailyPartyNotificationsTimezoneKey = 'daily_party_notifications_timezone';
const dailyPartyNotificationsScheduleDateKey =
    'daily_party_notifications_schedule_date';

bool get isDailyPartyNotificationSupportedPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

abstract interface class DailyPartyNotificationBackend {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<void> schedule(DailyPartyNotificationScheduleEntry entry);
  Future<void> cancel(int notificationId);
}

class FlutterDailyPartyNotificationBackend
    implements DailyPartyNotificationBackend {
  final FlutterLocalNotificationsPlugin _plugin;

  FlutterDailyPartyNotificationBackend([
    FlutterLocalNotificationsPlugin? plugin,
  ]) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_party_questions',
      'Daily Party Questions',
      channelDescription: 'One Party Question every evening.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: true,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    ),
  );

  @override
  Future<void> initialize() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
  }

  @override
  Future<bool> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: false, sound: true) ??
          false;
    }
    return false;
  }

  @override
  Future<void> schedule(DailyPartyNotificationScheduleEntry entry) {
    return _plugin.zonedSchedule(
      id: entry.notificationId,
      title: 'Tonight’s Party Question 👀',
      body: entry.question.text,
      payload: entry.payload,
      scheduledDate: entry.scheduledAt,
      notificationDetails: _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel(int notificationId) => _plugin.cancel(id: notificationId);
}

typedef DeviceTimezoneResolver = Future<String> Function();
typedef LocalTimeSource = tz.TZDateTime Function(tz.Location location);

class DailyPartyNotificationService {
  final SharedPreferences _preferences;
  final DailyPartyNotificationBackend _backend;
  final DeviceTimezoneResolver _timezoneResolver;
  final LocalTimeSource _localNow;
  bool _initialized = false;

  DailyPartyNotificationService({
    required SharedPreferences preferences,
    DailyPartyNotificationBackend? backend,
    DeviceTimezoneResolver? timezoneResolver,
    LocalTimeSource? localNow,
  }) : _preferences = preferences,
       _backend = backend ?? FlutterDailyPartyNotificationBackend(),
       _timezoneResolver =
           timezoneResolver ??
           (() async => (await FlutterTimezone.getLocalTimezone()).identifier),
       _localNow = localNow ?? tz.TZDateTime.now;

  bool get isEnabled =>
      _preferences.getBool(dailyPartyNotificationsEnabledKey) ?? false;

  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      tz_data.initializeTimeZones();
      await _backend.initialize();
      _initialized = true;
      return true;
    } catch (error, stackTrace) {
      debugPrint('Daily Party notification initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> enable() async {
    try {
      await _preferences.setBool(dailyPartyNotificationsEnabledKey, false);
      if (!await initialize()) {
        await _resetFailedEnableState();
        return false;
      }
      if (!await _backend.requestPermission()) {
        await _resetFailedEnableState();
        return false;
      }

      await _preferences.setBool(dailyPartyNotificationsEnabledKey, true);
      if (await refreshIfNeeded(force: true)) {
        return true;
      }

      await _resetFailedEnableState(cancelSchedules: false);
      return false;
    } catch (error, stackTrace) {
      debugPrint('Daily Party notification enable failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _resetFailedEnableState();
      return false;
    }
  }

  Future<void> disable() async {
    await _preferences.setBool(dailyPartyNotificationsEnabledKey, false);
    await _cancelDailyPartyNotifications();
  }

  Future<bool> refreshIfNeeded({bool force = false}) async {
    if (!isEnabled) return true;
    if (!await initialize()) return false;

    var scheduleCreationStarted = false;
    try {
      final timezone = await _timezoneResolver();
      final location = tz.getLocation(timezone);
      tz.setLocalLocation(location);
      final localNow = _localNow(location);
      final scheduleDate = dailyPartyScheduleDateKey(localNow);
      final needsRefresh =
          force ||
          shouldRefreshDailyPartySchedule(
            enabled: isEnabled,
            lastTimezone: _preferences.getString(
              dailyPartyNotificationsTimezoneKey,
            ),
            lastScheduleDate: _preferences.getString(
              dailyPartyNotificationsScheduleDateKey,
            ),
            timezone: timezone,
            scheduleDate: scheduleDate,
          );
      if (!needsRefresh) return true;

      if (!await _cancelDailyPartyNotifications()) return false;

      scheduleCreationStarted = true;
      final entries = buildDailyPartyNotificationSchedule(
        location: location,
        localNow: localNow,
      );
      for (final entry in entries) {
        await _backend.schedule(entry);
      }
      await _preferences.setString(
        dailyPartyNotificationsTimezoneKey,
        timezone,
      );
      await _preferences.setString(
        dailyPartyNotificationsScheduleDateKey,
        scheduleDate,
      );
      return true;
    } catch (error, stackTrace) {
      debugPrint('Daily Party notification refresh failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (scheduleCreationStarted) {
        await _cancelDailyPartyNotifications();
      }
      return false;
    }
  }

  Future<void> _resetFailedEnableState({bool cancelSchedules = true}) async {
    try {
      await _preferences.setBool(dailyPartyNotificationsEnabledKey, false);
    } catch (error, stackTrace) {
      debugPrint(
        'Could not persist disabled Daily Party notifications: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      await _preferences.remove(dailyPartyNotificationsTimezoneKey);
      await _preferences.remove(dailyPartyNotificationsScheduleDateKey);
    } catch (error, stackTrace) {
      debugPrint('Could not clear Daily Party notification metadata: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    if (cancelSchedules) {
      await _cancelDailyPartyNotifications();
    }
  }

  Future<bool> _cancelDailyPartyNotifications() async {
    final failures = <Object>[];
    for (
      var id = dailyPartyNotificationIdStart;
      id < dailyPartyNotificationIdStart + dailyPartyNotificationCount;
      id++
    ) {
      try {
        await _backend.cancel(id);
      } catch (error) {
        failures.add(error);
      }
    }

    if (failures.isNotEmpty) {
      debugPrint(
        'Failed to cancel ${failures.length} Daily Party notifications.',
      );
      return false;
    }

    return true;
  }
}
