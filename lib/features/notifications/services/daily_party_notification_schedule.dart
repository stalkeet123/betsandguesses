import 'package:timezone/timezone.dart' as tz;

import '../data/daily_party_questions.dart';

const dailyPartyNotificationIdStart = 42000;
const dailyPartyNotificationCount = 30;
final dailyPartyQuestionAnchor = DateTime.utc(2026, 1, 1);

class DailyPartyNotificationScheduleEntry {
  final int notificationId;
  final DailyPartyQuestion question;
  final tz.TZDateTime scheduledAt;

  const DailyPartyNotificationScheduleEntry({
    required this.notificationId,
    required this.question,
    required this.scheduledAt,
  });

  String get payload => 'daily_party_question:${question.id}';
}

DateTime dailyPartyCalendarDate(DateTime localDateTime) =>
    DateTime.utc(localDateTime.year, localDateTime.month, localDateTime.day);

DailyPartyQuestion dailyPartyQuestionForDate(DateTime localDateTime) {
  final day = dailyPartyCalendarDate(localDateTime);
  final dayIndex = day.difference(dailyPartyQuestionAnchor).inDays;
  return dailyPartyQuestions[dayIndex % dailyPartyQuestions.length];
}

DateTime firstDailyPartyScheduleDate(DateTime localNow) {
  final localDate = dailyPartyCalendarDate(localNow);
  return localNow.hour >= 21
      ? localDate.add(const Duration(days: 1))
      : localDate;
}

List<DailyPartyNotificationScheduleEntry> buildDailyPartyNotificationSchedule({
  required tz.Location location,
  required DateTime localNow,
}) {
  final firstDate = firstDailyPartyScheduleDate(localNow);
  return List<DailyPartyNotificationScheduleEntry>.generate(
    dailyPartyNotificationCount,
    (offset) {
      final date = firstDate.add(Duration(days: offset));
      return DailyPartyNotificationScheduleEntry(
        notificationId: dailyPartyNotificationIdStart + offset,
        question: dailyPartyQuestionForDate(date),
        scheduledAt: tz.TZDateTime(
          location,
          date.year,
          date.month,
          date.day,
          21,
        ),
      );
    },
    growable: false,
  );
}

String dailyPartyScheduleDateKey(DateTime localDateTime) {
  final date = dailyPartyCalendarDate(localDateTime);
  return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

bool shouldRefreshDailyPartySchedule({
  required bool enabled,
  required String? lastTimezone,
  required String? lastScheduleDate,
  required String timezone,
  required String scheduleDate,
}) {
  return enabled &&
      (lastTimezone != timezone || lastScheduleDate != scheduleDate);
}
