import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_state.dart';
import '../models/question_model.dart';
import '../models/guess_model.dart';
import '../models/bet_model.dart';
import '../../../core/constants/game_constants.dart';

// ── Game State Provider ──
final gameStateProvider = NotifierProvider<GameStateNotifier, GameState>(() {
  return GameStateNotifier();
});

class GameStateNotifier extends Notifier<GameState> {
  @override
  GameState build() {
    return const GameState(roomId: '', roomCode: '');
  }

  void initialize(String roomId, String roomCode, int maxRounds) {
    state = GameState(
      roomId: roomId,
      roomCode: roomCode,
      maxRounds: maxRounds,
    );
  }

  void updatePhase(RoundPhase phase) {
    state = state.copyWith(phase: phase);
  }

  void setRound(int round) {
    state = state.copyWith(currentRound: round);
  }

  void setQuestion(Question question) {
    state = state.copyWith(currentQuestion: question);
  }

  void setGuesses(List<Guess> guesses) {
    final sorted = List<Guess>.of(guesses)..sort((a, b) => a.value.compareTo(b.value));
    state = state.copyWith(guesses: guesses, sortedGuesses: sorted);
  }

  void addGuessIndicator() {
    // Just mark that someone submitted (we don't reveal values yet)
  }

  void setBets(List<Bet> bets) {
    state = state.copyWith(bets: bets);
  }

  void addBet(Bet bet) {
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
    final updatedBets = state.bets.map((b) => b.id == oldId ? bet : b).toList();
    state = state.copyWith(bets: updatedBets);
  }

  void removeBetById(String betId) {
    state = state.copyWith(
      bets: state.bets.where((b) => b.id != betId).toList(),
    );
  }

  void removeBetForSlot(String playerId, int slotIndex) {
    state = state.copyWith(
      bets: state.bets.where((b) => !(b.playerId == playerId && b.slotIndex == slotIndex)).toList(),
    );
  }

  void setScores(Map<String, int> scores) {
    state = state.copyWith(scores: scores);
  }

  void setCorrectAnswer(int answer, String? winningGuessId) {
    state = state.copyWith(correctAnswer: answer, winningGuessId: winningGuessId);
  }

  void setGuessSubmitted(bool submitted) {
    state = state.copyWith(hasSubmittedGuess: submitted);
  }

  void setBetsPlaced(bool placed) {
    state = state.copyWith(hasPlacedBets: placed);
  }

  void setTimer(int seconds) {
    state = state.copyWith(timerSeconds: seconds);
  }

  void nextRound() {
    state = state.nextRound();
  }

  void reset() {
    state = const GameState(roomId: '', roomCode: '');
  }
}
