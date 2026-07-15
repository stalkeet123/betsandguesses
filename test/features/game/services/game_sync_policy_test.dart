import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/core/constants/game_constants.dart';
import 'package:witsgame/features/game/services/game_sync_policy.dart';

void main() {
  group('phase event ordering', () {
    test('rejects an event from an older round', () {
      expect(
        GameSyncPolicy.shouldApplyPhase(
          currentRound: 2,
          currentPhase: RoundPhase.betting,
          eventRound: 1,
          eventPhase: RoundPhase.guessing,
        ),
        isFalse,
      );
    });

    test('rejects a duplicate or backwards phase in the same round', () {
      expect(
        GameSyncPolicy.shouldApplyPhase(
          currentRound: 2,
          currentPhase: RoundPhase.betting,
          eventRound: 2,
          eventPhase: RoundPhase.betting,
        ),
        isFalse,
      );
      expect(
        GameSyncPolicy.shouldApplyPhase(
          currentRound: 2,
          currentPhase: RoundPhase.betting,
          eventRound: 2,
          eventPhase: RoundPhase.guessing,
        ),
        isFalse,
      );
    });

    test('accepts a forward phase and a new round', () {
      expect(
        GameSyncPolicy.shouldApplyPhase(
          currentRound: 2,
          currentPhase: RoundPhase.guessing,
          eventRound: 2,
          eventPhase: RoundPhase.betting,
        ),
        isTrue,
      );
      expect(
        GameSyncPolicy.shouldApplyPhase(
          currentRound: 2,
          currentPhase: RoundPhase.revealAnswer,
          eventRound: 3,
          eventPhase: RoundPhase.guessing,
        ),
        isTrue,
      );
    });
  });

  group('deadline timer', () {
    test('rounds partial seconds up for display', () {
      final now = DateTime.utc(2026, 7, 15, 12);

      expect(
        GameSyncPolicy.remainingSeconds(
          deadline: now.add(const Duration(milliseconds: 1501)),
          now: now,
        ),
        2,
      );
    });

    test('returns zero for expired deadlines', () {
      final now = DateTime.utc(2026, 7, 15, 12);

      expect(
        GameSyncPolicy.remainingSeconds(
          deadline: now.subtract(const Duration(seconds: 1)),
          now: now,
        ),
        0,
      );
    });
  });
}
