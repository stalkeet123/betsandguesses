import '../../../core/constants/game_constants.dart';

enum ClassicTimerReconciliation { startNewLifecycle, updateDeadline, keepAlive }

enum ClassicPhaseEventAction { reject, reconcile, advance }

class GameSyncPolicy {
  const GameSyncPolicy._();

  static const classicScanInterval = Duration(milliseconds: 240);

  static bool shouldDeferBetSnapshot({
    required int snapshotRound,
    required RoundPhase snapshotPhase,
    required int currentRound,
    required RoundPhase currentPhase,
    required bool commandWasInFlight,
    required bool commandIsInFlight,
    required int revisionAtRead,
    required int currentRevision,
  }) =>
      snapshotRound == currentRound &&
      snapshotPhase == RoundPhase.betting &&
      currentPhase == RoundPhase.betting &&
      (commandWasInFlight ||
          commandIsInFlight ||
          revisionAtRead != currentRevision);

  static Duration elapsedSince(DateTime startedAt, DateTime now) =>
      now.isBefore(startedAt) ? Duration.zero : now.difference(startedAt);

  /// Late receivers catch up on the same reveal, rather than replaying it.
  static int classicRevealStep(Duration elapsed, int slotCount) =>
      (elapsed.inMicroseconds ~/ classicScanInterval.inMicroseconds).clamp(
        0,
        slotCount,
      );

  static bool shouldPresentPhaseEntry({
    required int? presentedRound,
    required RoundPhase? presentedPhase,
    required int eventRound,
    required RoundPhase eventPhase,
  }) {
    if (presentedRound == null || presentedPhase == null) return true;
    return shouldApplyPhase(
      currentRound: presentedRound,
      currentPhase: presentedPhase,
      eventRound: eventRound,
      eventPhase: eventPhase,
    );
  }

  /// A room-row update can announce guessing before its question-bearing
  /// broadcast or authoritative snapshot reaches this client. Keep the
  /// transition surface in place instead of briefly presenting an empty
  /// guessing screen and then presenting the same round again.
  static bool shouldWaitForClassicQuestion({
    required int currentRound,
    required RoundPhase currentPhase,
    required bool hasCurrentQuestion,
    required int incomingRound,
    required RoundPhase incomingPhase,
    required bool incomingHasQuestion,
  }) {
    final hasQuestionForIncomingRound =
        currentRound == incomingRound && hasCurrentQuestion;
    if (incomingPhase != RoundPhase.guessing ||
        incomingHasQuestion ||
        hasQuestionForIncomingRound ||
        incomingRound < currentRound) {
      return false;
    }

    return incomingRound > currentRound ||
        currentPhase == RoundPhase.question ||
        currentPhase == RoundPhase.guessing;
  }

  static bool shouldApplyPhase({
    required int currentRound,
    required RoundPhase currentPhase,
    required int eventRound,
    required RoundPhase eventPhase,
  }) {
    if (eventRound < currentRound) return false;
    if (eventRound > currentRound) return true;
    return eventPhase.index > currentPhase.index;
  }

  static bool shouldApplyClassicSnapshot({
    required int currentRound,
    required RoundPhase currentPhase,
    int? currentStateVersion,
    required int incomingRound,
    required RoundPhase incomingPhase,
    int? incomingStateVersion,
  }) {
    if (incomingRound < currentRound) return false;
    if (incomingRound > currentRound) return true;

    if (incomingPhase.index < currentPhase.index) return false;
    if (incomingPhase.index > currentPhase.index) return true;

    // Same-phase snapshots are useful reconciliations for data and deadline
    // corrections. A known older state version is the only stale tie-breaker.
    if (currentStateVersion != null &&
        incomingStateVersion != null &&
        incomingStateVersion < currentStateVersion) {
      return false;
    }
    return true;
  }

  /// A duplicate phase may still carry missing question data or a deadline.
  /// Data reconciliation must not be confused with replaying phase entry.
  static ClassicPhaseEventAction classicPhaseEventAction({
    required int currentRound,
    required RoundPhase currentPhase,
    int? currentStateVersion,
    required int eventRound,
    required RoundPhase eventPhase,
    int? eventStateVersion,
  }) {
    if (!shouldApplyClassicSnapshot(
      currentRound: currentRound,
      currentPhase: currentPhase,
      currentStateVersion: currentStateVersion,
      incomingRound: eventRound,
      incomingPhase: eventPhase,
      incomingStateVersion: eventStateVersion,
    )) {
      return ClassicPhaseEventAction.reject;
    }
    return shouldApplyPhase(
          currentRound: currentRound,
          currentPhase: currentPhase,
          eventRound: eventRound,
          eventPhase: eventPhase,
        )
        ? ClassicPhaseEventAction.advance
        : ClassicPhaseEventAction.reconcile;
  }

  /// Legacy broadcasts may omit the deadline. Only reuse a room deadline
  /// belonging to this round's reveal; never borrow the betting deadline.
  static DateTime? classicRevealDeadline({
    required int eventRound,
    DateTime? eventDeadline,
    required int roomRound,
    required RoundPhase roomPhase,
    DateTime? roomDeadline,
  }) {
    if (eventDeadline != null) return eventDeadline;
    if (roomRound != eventRound || roomPhase != RoundPhase.revealAnswer) {
      return null;
    }
    return roomDeadline;
  }

  static ClassicTimerReconciliation classicTimerReconciliation({
    required int? activeRound,
    required RoundPhase? activePhase,
    required DateTime? activeDeadline,
    required int eventRound,
    required RoundPhase eventPhase,
    required DateTime? eventDeadline,
  }) {
    if (activeRound != eventRound || activePhase != eventPhase) {
      return ClassicTimerReconciliation.startNewLifecycle;
    }
    if (activeDeadline != eventDeadline) {
      return ClassicTimerReconciliation.updateDeadline;
    }
    return ClassicTimerReconciliation.keepAlive;
  }

  static bool shouldTick({required int remainingSeconds}) {
    return remainingSeconds > 0 && remainingSeconds <= 10;
  }

  static bool shouldHandleTimerExpiration({
    required int? expiredRound,
    required RoundPhase? expiredPhase,
    required int eventRound,
    required RoundPhase eventPhase,
  }) {
    return expiredRound != eventRound || expiredPhase != eventPhase;
  }

  static bool isCurrentRound({
    required int currentRound,
    required int eventRound,
  }) {
    return eventRound == currentRound;
  }

  static int remainingSeconds({
    required DateTime deadline,
    required DateTime now,
  }) {
    final milliseconds = deadline.difference(now).inMilliseconds;
    if (milliseconds <= 0) return 0;
    return (milliseconds / Duration.millisecondsPerSecond).ceil();
  }

  static bool isInteractionWindowOpen({
    required DateTime? deadline,
    required DateTime now,
    Duration networkSafetyMargin = const Duration(milliseconds: 400),
  }) {
    if (deadline == null) return true;
    return now.isBefore(deadline.subtract(networkSafetyMargin));
  }

  static Duration partyWatchdogDelay(int attempt) {
    const delays = <Duration>[
      Duration(seconds: 5),
      Duration(seconds: 10),
      Duration(seconds: 20),
      Duration(seconds: 30),
    ];
    return delays[attempt.clamp(0, delays.length - 1)];
  }
}
