import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/features/party/utils/party_poll_deadline.dart';

void main() {
  final deadline = DateTime.utc(2000, 1, 1, 12);
  test(
    'countdown follows supplied server time even for a past device date',
    () {
      final result = partyPollDeadline(
        phaseEndsAt: deadline,
        serverNow: deadline.subtract(const Duration(milliseconds: 12500)),
      );
      expect(result.remaining, const Duration(milliseconds: 12500));
      expect(result.expired, isFalse);
    },
  );

  test('a subsecond remainder has not expired', () {
    final result = partyPollDeadline(
      phaseEndsAt: deadline,
      serverNow: deadline.subtract(const Duration(milliseconds: 1)),
    );
    expect(result.remaining, const Duration(milliseconds: 1));
    expect(result.expired, isFalse);
  });

  test('deadline expires exactly at authoritative server time', () {
    final result = partyPollDeadline(
      phaseEndsAt: deadline,
      serverNow: deadline,
    );
    expect(result.remaining, Duration.zero);
    expect(result.expired, isTrue);
  });

  test('elapsed deadline clamps remaining time to zero', () {
    final result = partyPollDeadline(
      phaseEndsAt: deadline,
      serverNow: deadline.add(const Duration(hours: 1)),
    );
    expect(result.remaining, Duration.zero);
    expect(result.expired, isTrue);
  });

  test('missing deadline has no countdown and cannot trigger transition', () {
    final result = partyPollDeadline(phaseEndsAt: null, serverNow: deadline);
    expect(result.remaining, Duration.zero);
    expect(result.expired, isFalse);
  });
}
