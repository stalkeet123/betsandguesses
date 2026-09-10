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

  group('classic authoritative snapshot freshness', () {
    test('rejects question after guessing in the same round', () {
      expect(
        GameSyncPolicy.shouldApplyClassicSnapshot(
          currentRound: 2,
          currentPhase: RoundPhase.guessing,
          incomingRound: 2,
          incomingPhase: RoundPhase.question,
        ),
        isFalse,
      );
    });

    test('rejects guessing after betting in the same round', () {
      expect(
        GameSyncPolicy.shouldApplyClassicSnapshot(
          currentRound: 2,
          currentPhase: RoundPhase.betting,
          incomingRound: 2,
          incomingPhase: RoundPhase.guessing,
        ),
        isFalse,
      );
    });

    test('accepts a newer same-phase reconciliation', () {
      expect(
        GameSyncPolicy.shouldApplyClassicSnapshot(
          currentRound: 2,
          currentPhase: RoundPhase.guessing,
          currentStateVersion: 15,
          incomingRound: 2,
          incomingPhase: RoundPhase.guessing,
          incomingStateVersion: 16,
        ),
        isTrue,
      );
    });

    test('accepts question when it belongs to a newer round', () {
      expect(
        GameSyncPolicy.shouldApplyClassicSnapshot(
          currentRound: 1,
          currentPhase: RoundPhase.revealAnswer,
          incomingRound: 2,
          incomingPhase: RoundPhase.question,
        ),
        isTrue,
      );
    });

    test('accepts guessing after question in the same round', () {
      expect(
        GameSyncPolicy.shouldApplyClassicSnapshot(
          currentRound: 2,
          currentPhase: RoundPhase.question,
          incomingRound: 2,
          incomingPhase: RoundPhase.guessing,
        ),
        isTrue,
      );
    });

    test('rejects a resync that completes after local phase advancement', () {
      expect(
        GameSyncPolicy.shouldApplyClassicSnapshot(
          currentRound: 2,
          currentPhase: RoundPhase.guessing,
          currentStateVersion: 15,
          incomingRound: 2,
          incomingPhase: RoundPhase.question,
          incomingStateVersion: 20,
        ),
        isFalse,
      );
    });

    test('rejects an older same-phase state version', () {
      expect(
        GameSyncPolicy.shouldApplyClassicSnapshot(
          currentRound: 2,
          currentPhase: RoundPhase.guessing,
          currentStateVersion: 16,
          incomingRound: 2,
          incomingPhase: RoundPhase.guessing,
          incomingStateVersion: 15,
        ),
        isFalse,
      );
    });

    test('accepts same-phase reconciliation without version metadata', () {
      expect(
        GameSyncPolicy.shouldApplyClassicSnapshot(
          currentRound: 2,
          currentPhase: RoundPhase.guessing,
          currentStateVersion: 16,
          incomingRound: 2,
          incomingPhase: RoundPhase.guessing,
        ),
        isTrue,
      );
    });
  });

  group('classic phase presentation identity', () {
    test('presents the first phase entry', () {
      expect(
        GameSyncPolicy.shouldPresentPhaseEntry(
          presentedRound: null,
          presentedPhase: null,
          eventRound: 2,
          eventPhase: RoundPhase.guessing,
        ),
        isTrue,
      );
    });

    test('dedupes the same logical phase from another transport', () {
      expect(
        GameSyncPolicy.shouldPresentPhaseEntry(
          presentedRound: 2,
          presentedPhase: RoundPhase.guessing,
          eventRound: 2,
          eventPhase: RoundPhase.guessing,
        ),
        isFalse,
      );
    });

    test('accepts a newer phase and a newer round', () {
      expect(
        GameSyncPolicy.shouldPresentPhaseEntry(
          presentedRound: 2,
          presentedPhase: RoundPhase.guessing,
          eventRound: 2,
          eventPhase: RoundPhase.betting,
        ),
        isTrue,
      );
      expect(
        GameSyncPolicy.shouldPresentPhaseEntry(
          presentedRound: 2,
          presentedPhase: RoundPhase.revealAnswer,
          eventRound: 3,
          eventPhase: RoundPhase.question,
        ),
        isTrue,
      );
    });

    test('rejects an older phase or round', () {
      expect(
        GameSyncPolicy.shouldPresentPhaseEntry(
          presentedRound: 2,
          presentedPhase: RoundPhase.betting,
          eventRound: 2,
          eventPhase: RoundPhase.guessing,
        ),
        isFalse,
      );
      expect(
        GameSyncPolicy.shouldPresentPhaseEntry(
          presentedRound: 3,
          presentedPhase: RoundPhase.question,
          eventRound: 2,
          eventPhase: RoundPhase.revealAnswer,
        ),
        isFalse,
      );
    });
  });

  group('classic timer reconciliation', () {
    final deadline = DateTime.utc(2026, 9, 10, 12, 0, 20);

    test('same logical timer and deadline keeps the lifecycle alive', () {
      expect(
        GameSyncPolicy.classicTimerReconciliation(
          activeRound: 3,
          activePhase: RoundPhase.betting,
          activeDeadline: deadline,
          eventRound: 3,
          eventPhase: RoundPhase.betting,
          eventDeadline: deadline,
        ),
        ClassicTimerReconciliation.keepAlive,
      );
    });

    test('same logical timer accepts a deadline correction', () {
      expect(
        GameSyncPolicy.classicTimerReconciliation(
          activeRound: 3,
          activePhase: RoundPhase.betting,
          activeDeadline: deadline,
          eventRound: 3,
          eventPhase: RoundPhase.betting,
          eventDeadline: deadline.add(const Duration(seconds: 2)),
        ),
        ClassicTimerReconciliation.updateDeadline,
      );
    });

    test('new phase starts a new timer lifecycle', () {
      expect(
        GameSyncPolicy.classicTimerReconciliation(
          activeRound: 3,
          activePhase: RoundPhase.guessing,
          activeDeadline: deadline,
          eventRound: 3,
          eventPhase: RoundPhase.betting,
          eventDeadline: deadline,
        ),
        ClassicTimerReconciliation.startNewLifecycle,
      );
    });

    test('new round starts a new timer lifecycle', () {
      expect(
        GameSyncPolicy.classicTimerReconciliation(
          activeRound: 3,
          activePhase: RoundPhase.betting,
          activeDeadline: deadline,
          eventRound: 4,
          eventPhase: RoundPhase.guessing,
          eventDeadline: deadline,
        ),
        ClassicTimerReconciliation.startNewLifecycle,
      );
    });

    test('ticking follows the entire final ten-second window', () {
      expect(GameSyncPolicy.shouldTick(remainingSeconds: 11), isFalse);
      expect(GameSyncPolicy.shouldTick(remainingSeconds: 10), isTrue);
      expect(GameSyncPolicy.shouldTick(remainingSeconds: 8), isTrue);
      expect(GameSyncPolicy.shouldTick(remainingSeconds: 0), isFalse);
    });

    test('handles expiration once for the same logical phase', () {
      expect(
        GameSyncPolicy.shouldHandleTimerExpiration(
          expiredRound: null,
          expiredPhase: null,
          eventRound: 3,
          eventPhase: RoundPhase.betting,
        ),
        isTrue,
      );
      expect(
        GameSyncPolicy.shouldHandleTimerExpiration(
          expiredRound: 3,
          expiredPhase: RoundPhase.betting,
          eventRound: 3,
          eventPhase: RoundPhase.betting,
        ),
        isFalse,
      );
      expect(
        GameSyncPolicy.shouldHandleTimerExpiration(
          expiredRound: 3,
          expiredPhase: RoundPhase.betting,
          eventRound: 4,
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

    test('locks interactions before the server deadline safety margin', () {
      final now = DateTime.utc(2026, 7, 15, 12);

      expect(
        GameSyncPolicy.isInteractionWindowOpen(
          deadline: now.add(const Duration(milliseconds: 401)),
          now: now,
        ),
        isTrue,
      );
      expect(
        GameSyncPolicy.isInteractionWindowOpen(
          deadline: now.add(const Duration(milliseconds: 400)),
          now: now,
        ),
        isFalse,
      );
      expect(
        GameSyncPolicy.isInteractionWindowOpen(deadline: null, now: now),
        isTrue,
      );
    });
  });

  group('party snapshot watchdog', () {
    test('backs off and caps at thirty seconds', () {
      expect(GameSyncPolicy.partyWatchdogDelay(0), const Duration(seconds: 5));
      expect(GameSyncPolicy.partyWatchdogDelay(1), const Duration(seconds: 10));
      expect(GameSyncPolicy.partyWatchdogDelay(2), const Duration(seconds: 20));
      expect(GameSyncPolicy.partyWatchdogDelay(3), const Duration(seconds: 30));
      expect(
        GameSyncPolicy.partyWatchdogDelay(99),
        const Duration(seconds: 30),
      );
    });
  });
}
