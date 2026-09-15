import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/core/constants/game_constants.dart';
import 'package:witsgame/features/game/services/game_sync_policy.dart';

void main() {
  test('delayed clients catch up to the same server reveal step', () {
    final start = DateTime.utc(2026, 9, 10);
    final now = start.add(const Duration(milliseconds: 1200));
    // A late receiver does not start at zero on message/audio arrival.
    final early = GameSyncPolicy.classicRevealStep(
      GameSyncPolicy.elapsedSince(start, now),
      11,
    );
    final late = GameSyncPolicy.classicRevealStep(
      GameSyncPolicy.elapsedSince(start, now),
      11,
    );
    expect(early, 5);
    expect(late, early);
    expect(
      GameSyncPolicy.classicRevealStep(const Duration(milliseconds: 239), 11),
      0,
    );
    expect(
      GameSyncPolicy.classicRevealStep(const Duration(milliseconds: 240), 11),
      1,
    );
  });
  test('returning after impact shows the winner, never replays the scan', () {
    expect(
      GameSyncPolicy.classicRevealStep(const Duration(seconds: 5), 11),
      11,
    );
    expect(
      GameSyncPolicy.classicRevealStep(const Duration(milliseconds: 2640), 11),
      11,
    );
  });
  test('clock uncertainty before start cannot produce a negative slot', () {
    final start = DateTime.utc(2026, 9, 10);
    expect(
      GameSyncPolicy.elapsedSince(
        start,
        start.subtract(const Duration(seconds: 1)),
      ),
      Duration.zero,
    );
  });
  bool defer({
    int round = 2,
    RoundPhase phase = RoundPhase.betting,
    bool was = false,
    bool active = false,
    int revision = 7,
  }) => GameSyncPolicy.shouldDeferBetSnapshot(
    snapshotRound: round,
    snapshotPhase: phase,
    currentRound: 2,
    currentPhase: RoundPhase.betting,
    commandWasInFlight: was,
    commandIsInFlight: active,
    revisionAtRead: 7,
    currentRevision: revision,
  );
  test('a snapshot started before a completed chip command cannot undo it', () {
    expect(defer(revision: 9), isTrue);
  });
  test('snapshot across an active placement, move or removal is deferred', () {
    expect(defer(was: true), isTrue);
    expect(defer(active: true), isTrue);
  });
  test('a settled reveal advances even while a chip command is finishing', () {
    expect(defer(phase: RoundPhase.revealAnswer, active: true), isFalse);
    expect(defer(round: 3, active: true), isFalse);
  });
  test('an unchanged idle command cursor accepts the authoritative board', () {
    expect(defer(), isFalse);
  });
}
