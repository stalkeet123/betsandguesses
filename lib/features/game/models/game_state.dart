import '../../../core/constants/game_constants.dart';
import 'question_model.dart';
import 'guess_model.dart';
import 'bet_model.dart';

/// Complete game state for a room — used by the GameStateNotifier
class GameState {
  final String roomId;
  final String roomCode;
  final int currentRound;
  final int maxRounds;
  final RoundPhase phase;
  final Question? currentQuestion;
  final List<Guess> guesses;        // current round's guesses
  final List<Guess> sortedGuesses;  // sorted ascending for the board
  final List<Bet> bets;             // current round's bets
  final Map<String, int> scores;    // playerId -> total score
  final int? correctAnswer;
  final String? winningGuessId;
  final int timerSeconds;
  final bool hasSubmittedGuess;
  final bool hasPlacedBets;

  const GameState({
    required this.roomId,
    required this.roomCode,
    this.currentRound = 0,
    this.maxRounds = 8,
    this.phase = RoundPhase.idle,
    this.currentQuestion,
    this.guesses = const [],
    this.sortedGuesses = const [],
    this.bets = const [],
    this.scores = const {},
    this.correctAnswer,
    this.winningGuessId,
    this.timerSeconds = 0,
    this.hasSubmittedGuess = false,
    this.hasPlacedBets = false,
  });

  bool get isLastRound => currentRound >= maxRounds;
  bool get isGameOver => phase == RoundPhase.idle && currentRound >= maxRounds;

  GameState copyWith({
    String? roomId,
    String? roomCode,
    int? currentRound,
    int? maxRounds,
    RoundPhase? phase,
    Question? currentQuestion,
    List<Guess>? guesses,
    List<Guess>? sortedGuesses,
    List<Bet>? bets,
    Map<String, int>? scores,
    int? correctAnswer,
    String? winningGuessId,
    int? timerSeconds,
    bool? hasSubmittedGuess,
    bool? hasPlacedBets,
  }) {
    return GameState(
      roomId: roomId ?? this.roomId,
      roomCode: roomCode ?? this.roomCode,
      currentRound: currentRound ?? this.currentRound,
      maxRounds: maxRounds ?? this.maxRounds,
      phase: phase ?? this.phase,
      currentQuestion: currentQuestion ?? this.currentQuestion,
      guesses: guesses ?? this.guesses,
      sortedGuesses: sortedGuesses ?? this.sortedGuesses,
      bets: bets ?? this.bets,
      scores: scores ?? this.scores,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      winningGuessId: winningGuessId ?? this.winningGuessId,
      timerSeconds: timerSeconds ?? this.timerSeconds,
      hasSubmittedGuess: hasSubmittedGuess ?? this.hasSubmittedGuess,
      hasPlacedBets: hasPlacedBets ?? this.hasPlacedBets,
    );
  }

  /// Reset for a new round, keeping scores
  GameState nextRound() {
    return GameState(
      roomId: roomId,
      roomCode: roomCode,
      currentRound: currentRound + 1,
      maxRounds: maxRounds,
      phase: RoundPhase.question,
      scores: scores,
    );
  }
}
