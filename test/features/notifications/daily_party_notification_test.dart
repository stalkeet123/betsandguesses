import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:witsgame/features/notifications/data/daily_party_questions.dart';
import 'package:witsgame/features/notifications/services/daily_party_notification_schedule.dart';
import 'package:witsgame/features/notifications/services/daily_party_notification_service.dart';

class _FakeNotificationBackend implements DailyPartyNotificationBackend {
  final bool permissionGranted;
  final Object? initializeError;
  final int? scheduleFailureId;
  final Set<int> cancelFailureIds;
  final List<DailyPartyNotificationScheduleEntry> scheduled = [];
  final List<int> cancelled = [];
  var initialized = false;
  var permissionRequests = 0;

  _FakeNotificationBackend({
    this.permissionGranted = true,
    this.initializeError,
    this.scheduleFailureId,
    this.cancelFailureIds = const {},
  });

  @override
  Future<void> cancel(int notificationId) async {
    cancelled.add(notificationId);
    if (cancelFailureIds.contains(notificationId)) {
      throw StateError('cancel failed for $notificationId');
    }
  }

  @override
  Future<void> initialize() async {
    if (initializeError != null) throw initializeError!;
    initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> schedule(DailyPartyNotificationScheduleEntry entry) async {
    if (entry.notificationId == scheduleFailureId) {
      throw StateError('schedule failed for ${entry.notificationId}');
    }
    scheduled.add(entry);
  }
}

void main() {
  late final tz.Location newYork;
  setUpAll(() {
    tz_data.initializeTimeZones();
    newYork = tz.getLocation('America/New_York');
  });

  group('daily Party questions', () {
    test('contains exactly 30 unique, non-empty questions', () {
      expect(dailyPartyQuestions, hasLength(30));
      expect(
        dailyPartyQuestions.map((question) => question.id).toSet(),
        hasLength(30),
      );
      expect(
        dailyPartyQuestions.every(
          (question) => question.text.trim().isNotEmpty,
        ),
        isTrue,
      );
      expect(dailyPartyQuestions.first.id, 'party_q_01');
      expect(dailyPartyQuestions.last.id, 'party_q_30');
    });

    test('rotates through every question before repeating on day 31', () {
      final firstThirty = List.generate(
        30,
        (offset) => dailyPartyQuestionForDate(
          dailyPartyQuestionAnchor.add(Duration(days: offset)),
        ).id,
      );
      expect(firstThirty.toSet(), hasLength(30));
      expect(
        dailyPartyQuestionForDate(
          dailyPartyQuestionAnchor.add(const Duration(days: 30)),
        ).id,
        'party_q_01',
      );
    });
  });

  group('daily Party schedule', () {
    test('starts today before 9 PM and tomorrow at or after 9 PM', () {
      expect(
        firstDailyPartyScheduleDate(tz.TZDateTime(newYork, 2026, 1, 2, 20, 59)),
        DateTime.utc(2026, 1, 2),
      );
      expect(
        firstDailyPartyScheduleDate(tz.TZDateTime(newYork, 2026, 1, 2, 21)),
        DateTime.utc(2026, 1, 3),
      );
    });

    test('builds 30 individual 9 PM entries with stable reserved IDs', () {
      final entries = buildDailyPartyNotificationSchedule(
        location: newYork,
        localNow: tz.TZDateTime(newYork, 2026, 1, 2, 20),
      );
      expect(entries, hasLength(30));
      expect(
        entries.map((entry) => entry.notificationId),
        List.generate(30, (offset) => dailyPartyNotificationIdStart + offset),
      );
      expect(entries.every((entry) => entry.scheduledAt.hour == 21), isTrue);
      expect(entries.first.question.id, 'party_q_02');
      expect(entries.first.payload, 'daily_party_question:party_q_02');
    });

    test('keeps 9 PM local time across America/New_York DST', () {
      final entries = buildDailyPartyNotificationSchedule(
        location: newYork,
        localNow: tz.TZDateTime(newYork, 2026, 3, 7, 20),
      );
      final dstEntries = entries
          .where(
            (entry) =>
                entry.scheduledAt.month == 3 && entry.scheduledAt.day <= 10,
          )
          .toList();
      expect(dstEntries, hasLength(4));
      expect(dstEntries.every((entry) => entry.scheduledAt.hour == 21), isTrue);
      expect(
        dstEntries.map((entry) => entry.question.id).toSet(),
        hasLength(4),
      );
    });

    test(
      'refresh decisions require enabled state and changed date or timezone',
      () {
        expect(
          shouldRefreshDailyPartySchedule(
            enabled: false,
            lastTimezone: null,
            lastScheduleDate: null,
            timezone: 'America/New_York',
            scheduleDate: '2026-01-01',
          ),
          isFalse,
        );
        expect(
          shouldRefreshDailyPartySchedule(
            enabled: true,
            lastTimezone: 'America/New_York',
            lastScheduleDate: '2026-01-01',
            timezone: 'America/New_York',
            scheduleDate: '2026-01-01',
          ),
          isFalse,
        );
        expect(
          shouldRefreshDailyPartySchedule(
            enabled: true,
            lastTimezone: 'America/New_York',
            lastScheduleDate: '2026-01-01',
            timezone: 'America/Los_Angeles',
            scheduleDate: '2026-01-01',
          ),
          isTrue,
        );
        expect(
          shouldRefreshDailyPartySchedule(
            enabled: true,
            lastTimezone: 'America/New_York',
            lastScheduleDate: '2026-01-01',
            timezone: 'America/New_York',
            scheduleDate: '2026-01-02',
          ),
          isTrue,
        );
      },
    );
  });

  group('daily Party notification service', () {
    test(
      'startup initialization never requests notification permission',
      () async {
        SharedPreferences.setMockInitialValues({});
        final backend = _FakeNotificationBackend();
        final service = DailyPartyNotificationService(
          preferences: await SharedPreferences.getInstance(),
          backend: backend,
          timezoneResolver: () async => 'America/New_York',
        );
        await service.initialize();
        await service.refreshIfNeeded();
        expect(backend.initialized, isTrue);
        expect(backend.permissionRequests, 0);
        expect(backend.scheduled, isEmpty);
      },
    );
    test(
      'schedules once per day/timezone and only cancels reserved IDs',
      () async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final backend = _FakeNotificationBackend();
        var timezone = 'America/New_York';
        var now = tz.TZDateTime(tz.getLocation(timezone), 2026, 1, 2, 20);
        final service = DailyPartyNotificationService(
          preferences: preferences,
          backend: backend,
          timezoneResolver: () async => timezone,
          localNow: (_) => now,
        );

        expect(await service.enable(), isTrue);
        expect(service.isEnabled, isTrue);
        expect(backend.initialized, isTrue);
        expect(backend.scheduled, hasLength(30));
        expect(
          backend.cancelled,
          List.generate(30, (offset) => 42000 + offset),
        );

        backend.scheduled.clear();
        backend.cancelled.clear();
        await service.refreshIfNeeded();
        expect(backend.scheduled, isEmpty);
        expect(backend.cancelled, isEmpty);

        now = tz.TZDateTime(tz.getLocation(timezone), 2026, 1, 3, 20);
        await service.refreshIfNeeded();
        expect(backend.scheduled, hasLength(30));
        expect(
          backend.cancelled,
          List.generate(30, (offset) => 42000 + offset),
        );

        backend.scheduled.clear();
        backend.cancelled.clear();
        timezone = 'America/Los_Angeles';
        now = tz.TZDateTime(tz.getLocation(timezone), 2026, 1, 3, 20);
        await service.refreshIfNeeded();
        expect(backend.scheduled, hasLength(30));
        expect(
          backend.cancelled,
          List.generate(30, (offset) => 42000 + offset),
        );

        backend.scheduled.clear();
        backend.cancelled.clear();
        await service.disable();
        expect(service.isEnabled, isFalse);
        expect(backend.scheduled, isEmpty);
        expect(
          backend.cancelled,
          List.generate(30, (offset) => 42000 + offset),
        );
      },
    );

    test(
      'returns false and persists off when backend initialization fails',
      () async {
        SharedPreferences.setMockInitialValues({
          dailyPartyNotificationsEnabledKey: true,
          dailyPartyNotificationsTimezoneKey: 'America/New_York',
          dailyPartyNotificationsScheduleDateKey: '2026-01-02',
        });
        final preferences = await SharedPreferences.getInstance();
        final backend = _FakeNotificationBackend(
          initializeError: StateError('backend unavailable'),
        );
        final service = DailyPartyNotificationService(
          preferences: preferences,
          backend: backend,
          timezoneResolver: () async => 'America/New_York',
        );

        expect(await service.enable(), isFalse);
        expect(service.isEnabled, isFalse);
        expect(
          preferences.getString(dailyPartyNotificationsTimezoneKey),
          isNull,
        );
        expect(
          preferences.getString(dailyPartyNotificationsScheduleDateKey),
          isNull,
        );
        expect(backend.permissionRequests, 0);
      },
    );

    test(
      'returns false and persists off when timezone resolution fails',
      () async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final backend = _FakeNotificationBackend();
        final service = DailyPartyNotificationService(
          preferences: preferences,
          backend: backend,
          timezoneResolver: () async =>
              throw StateError('timezone unavailable'),
        );

        expect(await service.enable(), isFalse);
        expect(service.isEnabled, isFalse);
        expect(
          preferences.getString(dailyPartyNotificationsTimezoneKey),
          isNull,
        );
        expect(
          preferences.getString(dailyPartyNotificationsScheduleDateKey),
          isNull,
        );
        expect(backend.scheduled, isEmpty);
      },
    );

    test('rolls back every reserved ID when schedule creation fails', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final backend = _FakeNotificationBackend(
        scheduleFailureId: dailyPartyNotificationIdStart + 10,
      );
      final service = DailyPartyNotificationService(
        preferences: preferences,
        backend: backend,
        timezoneResolver: () async => 'America/New_York',
        localNow: (_) => tz.TZDateTime(newYork, 2026, 1, 2, 20),
      );

      expect(await service.enable(), isFalse);
      expect(service.isEnabled, isFalse);
      expect(backend.scheduled, hasLength(10));
      expect(preferences.getString(dailyPartyNotificationsTimezoneKey), isNull);
      expect(
        preferences.getString(dailyPartyNotificationsScheduleDateKey),
        isNull,
      );
      expect(backend.cancelled, hasLength(60));
      expect(
        backend.cancelled.skip(30),
        List.generate(30, (offset) => dailyPartyNotificationIdStart + offset),
      );
    });

    test(
      'attempts every reserved cancellation even when one cancellation fails',
      () async {
        SharedPreferences.setMockInitialValues({
          dailyPartyNotificationsEnabledKey: true,
        });
        final preferences = await SharedPreferences.getInstance();
        final backend = _FakeNotificationBackend(
          cancelFailureIds: {dailyPartyNotificationIdStart + 10},
        );
        final service = DailyPartyNotificationService(
          preferences: preferences,
          backend: backend,
          timezoneResolver: () async => 'America/New_York',
        );

        await service.disable();

        expect(service.isEnabled, isFalse);
        expect(
          backend.cancelled,
          List.generate(30, (offset) => dailyPartyNotificationIdStart + offset),
        );
      },
    );
    test('keeps saved state off when permission is denied', () async {
      SharedPreferences.setMockInitialValues({});
      final service = DailyPartyNotificationService(
        preferences: await SharedPreferences.getInstance(),
        backend: _FakeNotificationBackend(permissionGranted: false),
        timezoneResolver: () async => 'America/New_York',
      );
      expect(await service.enable(), isFalse);
      expect(service.isEnabled, isFalse);
    });
  });
}
