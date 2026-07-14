import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_state.dart';
import '../models/question_model.dart';
import '../models/guess_model.dart';
import '../models/bet_model.dart';
import '../../../core/constants/game_constants.dart';

// ── Game Timer Provider ──
final gameTimerProvider = NotifierProvider<GameTimerNotifier, int>(() {
  return GameTimerNotifier();
});

class GameTimerNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTimer(int seconds) => state = seconds;
}

// ── Game State Provider ──
final gameStateProvider = NotifierProvider<GameStateNotifier, GameState>(() {
  return GameStateNotifier();
});

class GameStateNotifier extends Notifier<GameState> {
  @override
  GameState build() {
    return const GameState(roomId: '', roomCode: '');
  }

  void initialize(
    String roomId,
    String roomCode,
    int maxRounds, {
    int? currentRound,
    RoundPhase? phase,
    Question? currentQuestion,
    Map<String, int>? scores,
    List<Guess>? guesses,
    List<Bet>? bets,
    bool? hasSubmittedGuess,
    int? stateVersion,
    DateTime? phaseEndsAt,
  }) {
    final sameRoom = state.roomId == roomId;
    state = GameState(
      roomId: roomId,
      roomCode: roomCode,
      maxRounds: maxRounds,
      currentRound: currentRound ?? (sameRoom ? state.currentRound : 0),
      phase: phase ?? (sameRoom ? state.phase : RoundPhase.idle),
      currentQuestion:
          currentQuestion ?? (sameRoom ? state.currentQuestion : null),
      scores: scores ?? (sameRoom ? state.scores : const {}),
      guesses: guesses ?? (sameRoom ? state.guesses : const []),
      sortedGuesses: guesses == null
          ? (sameRoom ? state.sortedGuesses : const [])
          : (List<Guess>.of(guesses)
              ..sort((a, b) => a.value.compareTo(b.value))),
      bets: bets ?? (sameRoom ? state.bets : const []),
      hasSubmittedGuess:
          hasSubmittedGuess ?? (sameRoom && state.hasSubmittedGuess),
      stateVersion: stateVersion ?? (sameRoom ? state.stateVersion : 0),
      phaseEndsAt: phaseEndsAt,
    );
  }

  void updatePhase(RoundPhase phase) {
    state = state.copyWith(phase: phase);
  }

  bool applyServerPhase({
    required RoundPhase phase,
    int? round,
    Question? question,
    int? stateVersion,
    DateTime? phaseEndsAt,
    bool resetRoundData = false,
  }) {
    final nextVersion = stateVersion ?? state.stateVersion;
    if (stateVersion != null && stateVersion < state.stateVersion) {
      return false;
    }

    final nextRound = round ?? state.currentRound;
    if (nextRound < state.currentRound) return false;

    final isNewRound = nextRound > state.currentRound || resetRoundData;
    final sorted = isNewRound
        ? const <Guess>[]
        : (List<Guess>.of(state.guesses)
            ..sort((a, b) => a.value.compareTo(b.value)));

    state = GameState(
      roomId: state.roomId,
      roomCode: state.roomCode,
      currentRound: nextRound,
      maxRounds: state.maxRounds,
      phase: phase,
      currentQuestion: question ?? state.currentQuestion,
      guesses: isNewRound ? const [] : state.guesses,
      sortedGuesses: sorted,
      bets: isNewRound ? const [] : state.bets,
      scores: state.scores,
      hasSubmittedGuess: isNewRound ? false : state.hasSubmittedGuess,
      stateVersion: nextVersion,
      phaseEndsAt: phaseEndsAt,
    );
    return true;
  }

  void setPhaseMetadata({
    int? stateVersion,
    DateTime? phaseEndsAt,
    bool clearPhaseEndsAt = false,
  }) {
    state = state.copyWith(
      stateVersion: stateVersion,
      phaseEndsAt: phaseEndsAt,
      clearPhaseEndsAt: clearPhaseEndsAt,
    );
  }

  void setRound(int round) {
    state = state.copyWith(currentRound: round);
  }

  void setQuestion(Question question) {
    state = state.copyWith(currentQuestion: question);
  }

  void startGame({
    required int round,
    required RoundPhase phase,
    required Question question,
    Map<String, int>? scores,
  }) {
    state = state.copyWith(
      currentRound: round,
      phase: phase,
      currentQuestion: question,
      scores: scores ?? state.scores,
    );
  }

  void setGuesses(List<Guess> guesses) {
    final sorted = List<Guess>.of(guesses)
      ..sort((a, b) => a.value.compareTo(b.value));
    state = state.copyWith(guesses: guesses, sortedGuesses: sorted);
  }

  void addGuessIndicator() {
    // Just mark that someone submitted (we don't reveal values yet)
  }

  void setBets(List<Bet> bets) {
    state = state.copyWith(bets: bets);
  }

  void addBet(Bet bet) {
    if (bet.roundNumber != state.currentRound) return;

    final existingIndex = state.bets.indexWhere((b) => b.id == bet.id);
    if (existingIndex == -1) {
      state = state.copyWith(bets: [...state.bets, bet]);
      return;
    }

    final updatedBets = [...state.bets];
    updatedBets[existingIndex] = bet;
    state = state.copyWith(bets: updatedBets);
  }

  void replaceBet(String oldId, Bet bet) {
    final alreadyExists = state.bets.any((b) => b.id == bet.id && b.id != oldId);
    if (alreadyExists) {
      state = state.copyWith(
        bets: state.bets.where((b) => b.id != oldId).toList(),
      );
      return;
    }
    final hasOptimisticBet = state.bets.any((b) => b.id == oldId);
    final updatedBets = hasOptimisticBet
        ? state.bets.map((b) => b.id == oldId ? bet : b).toList()
        : [...state.bets, bet];
    state = state.copyWith(bets: updatedBets);
  }

  void removeBetById(String betId) {
    state = state.copyWith(
      bets: state.bets.where((b) => b.id != betId).toList(),
    );
  }

  void removeBetForSlot(String playerId, int slotIndex) {
    state = state.copyWith(
      bets: state.bets
          .where((b) => !(b.playerId == playerId && b.slotIndex == slotIndex))
          .toList(),
    );
  }

  void setScores(Map<String, int> scores) {
    state = state.copyWith(scores: scores);
  }

  void setCorrectAnswer(int answer, String? winningGuessId) {
    state = state.copyWith(
      correctAnswer: answer,
      winningGuessId: winningGuessId,
    );
  }

  void revealAnswer({
    required int answer,
    required String? winningGuessId,
    List<Bet>? bets,
    Map<String, int>? scores,
  }) {
    state = GameState(
      roomId: state.roomId,
      roomCode: state.roomCode,
      currentRound: state.currentRound,
      maxRounds: state.maxRounds,
      phase: RoundPhase.revealAnswer,
      currentQuestion: state.currentQuestion,
      guesses: state.guesses,
      sortedGuesses: state.sortedGuesses,
      bets: bets ?? state.bets,
      scores: scores ?? state.scores,
      correctAnswer: answer,
      winningGuessId: winningGuessId,
      hasSubmittedGuess: state.hasSubmittedGuess,
      stateVersion: state.stateVersion,
      phaseEndsAt: state.phaseEndsAt,
    );
  }

  void setGuessSubmitted(bool submitted) {
    state = state.copyWith(hasSubmittedGuess: submitted);
  }

  void nextRound() {
    state = state.nextRound();
  }

  void resetForNewRound() {
    state = GameState(
      roomId: state.roomId,
      roomCode: state.roomCode,
      currentRound: state.currentRound,
      maxRounds: state.maxRounds,
      phase: state.phase,
      currentQuestion: state.currentQuestion,
      scores: state.scores,
      stateVersion: state.stateVersion,
      phaseEndsAt: state.phaseEndsAt,
    );
  }

  void reset() {
    state = const GameState(roomId: '', roomCode: '');
  }
}
