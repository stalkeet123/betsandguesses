import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:witsgame/core/constants/game_constants.dart';
import 'package:witsgame/features/game/models/bet_model.dart';
import 'package:witsgame/features/game/models/game_state.dart';
import 'package:witsgame/features/game/models/guess_model.dart';
import 'package:witsgame/features/game/models/question_model.dart';
import 'package:witsgame/features/game/providers/game_providers.dart';

void main() {
  test('nextRound preserves identity and scores while clearing round data', () {
    const state = GameState(
      roomId: 'room-1',
      roomCode: 'ABC123',
      currentRound: 2,
      maxRounds: 6,
      phase: RoundPhase.scoring,
      currentQuestion: Question(
        id: 'question-1',
        textTr: 'Question',
        answer: 42,
      ),
      guesses: [
        Guess(
          id: 'guess-1',
          roomId: 'room-1',
          roundNumber: 2,
          playerId: 'player-1',
          value: 40,
        ),
      ],
      sortedGuesses: [],
      bets: [
        Bet(
          id: 'bet-1',
          roomId: 'room-1',
          roundNumber: 2,
          playerId: 'player-1',
          slotIndex: 2,
          chips: 1,
          payoutMultiplier: 2,
        ),
      ],
      scores: {'player-1': 21},
      correctAnswer: 42,
      winningGuessId: 'guess-1',
      hasSubmittedGuess: true,
    );

    final next = state.nextRound();

    expect(next.roomId, state.roomId);
    expect(next.roomCode, state.roomCode);
    expect(next.currentRound, 3);
    expect(next.maxRounds, 6);
    expect(next.phase, RoundPhase.question);
    expect(next.scores, {'player-1': 21});
    expect(next.currentQuestion, isNull);
    expect(next.guesses, isEmpty);
    expect(next.sortedGuesses, isEmpty);
    expect(next.bets, isEmpty);
    expect(next.correctAnswer, isNull);
    expect(next.winningGuessId, isNull);
    expect(next.hasSubmittedGuess, isFalse);
  });

  test('game over requires the final round and idle phase', () {
    const activeFinalRound = GameState(
      roomId: 'room-1',
      roomCode: 'ABC123',
      currentRound: 6,
      maxRounds: 6,
      phase: RoundPhase.scoring,
    );

    expect(activeFinalRound.isLastRound, isTrue);
    expect(activeFinalRound.isGameOver, isFalse);
    expect(
      activeFinalRound.copyWith(phase: RoundPhase.idle).isGameOver,
      isTrue,
    );
  });

  test('bet reconciliation updates by id and rejects an old round', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(gameStateProvider.notifier);
    notifier.initialize(
      'room-1',
      'ABC123',
      6,
      currentRound: 2,
      phase: RoundPhase.betting,
    );

    const bet = Bet(
      id: 'bet-1',
      roomId: 'room-1',
      roundNumber: 2,
      playerId: 'player-1',
      slotIndex: 2,
      chips: 1,
      payoutMultiplier: 2,
    );
    notifier.addBet(bet);
    notifier.addBet(bet.copyWith(chips: 3));
    notifier.addBet(
      const Bet(
        id: 'old-bet',
        roomId: 'room-1',
        roundNumber: 1,
        playerId: 'player-1',
        slotIndex: 1,
        chips: 1,
        payoutMultiplier: 3,
      ),
    );

    final bets = container.read(gameStateProvider).bets;
    expect(bets, hasLength(1));
    expect(bets.single.id, 'bet-1');
    expect(bets.single.chips, 3);
  });
}
