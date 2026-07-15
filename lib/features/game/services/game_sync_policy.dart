import '../../../core/constants/game_constants.dart';

class GameSyncPolicy {
  const GameSyncPolicy._();

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
}
