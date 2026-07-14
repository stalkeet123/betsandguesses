import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/features/game/models/bet_model.dart';
import 'package:witsgame/features/game/models/guess_model.dart';
import 'package:witsgame/features/game/providers/game_providers.dart';
import 'package:witsgame/core/constants/game_constants.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  test('older phase events cannot roll game state back', () {
    final notifier = container.read(gameStateProvider.notifier);
    notifier.initialize(
      'room-1',
      'ABC123',
      5,
      currentRound: 2,
      phase: RoundPhase.betting,
      stateVersion: 8,
    );

    final applied = notifier.applyServerPhase(
      phase: RoundPhase.guessing,
      round: 1,
      stateVersion: 7,
    );

    final state = container.read(gameStateProvider);
    expect(applied, isFalse);
    expect(state.currentRound, 2);
    expect(state.phase, RoundPhase.betting);
    expect(state.stateVersion, 8);
  });

  test('new round atomically clears old guesses and bets', () {
    final notifier = container.read(gameStateProvider.notifier);
    notifier.initialize(
      'room-1',
      'ABC123',
      5,
      currentRound: 1,
      phase: RoundPhase.betting,
      stateVersion: 3,
      guesses: const [
        Guess(
          id: 'guess-1',
          roomId: 'room-1',
          roundNumber: 1,
          playerId: 'player-1',
          value: 42,
        ),
      ],
      bets: const [
        Bet(
          id: 'bet-1',
          roomId: 'room-1',
          roundNumber: 1,
          playerId: 'player-1',
          slotIndex: 2,
          chips: 5,
          payoutMultiplier: 2,
        ),
      ],
      hasSubmittedGuess: true,
    );

    final applied = notifier.applyServerPhase(
      phase: RoundPhase.guessing,
      round: 2,
      stateVersion: 4,
      resetRoundData: true,
    );

    final state = container.read(gameStateProvider);
    expect(applied, isTrue);
    expect(state.currentRound, 2);
    expect(state.guesses, isEmpty);
    expect(state.bets, isEmpty);
    expect(state.hasSubmittedGuess, isFalse);
  });

  test('confirmed bet survives a resync that removed its optimistic row', () {
    final notifier = container.read(gameStateProvider.notifier);
    notifier.initialize(
      'room-1',
      'ABC123',
      5,
      currentRound: 1,
      phase: RoundPhase.betting,
    );

    const optimistic = Bet(
      id: 'local-action-1',
      roomId: 'room-1',
      roundNumber: 1,
      playerId: 'player-1',
      slotIndex: 2,
      chips: 5,
      payoutMultiplier: 2,
      clientActionId: 'action-1',
    );
    const confirmed = Bet(
      id: 'bet-1',
      roomId: 'room-1',
      roundNumber: 1,
      playerId: 'player-1',
      slotIndex: 2,
      chips: 5,
      payoutMultiplier: 2,
      clientActionId: 'action-1',
    );

    notifier.addBet(optimistic);
    notifier.removeBetById(optimistic.id);
    notifier.replaceBet(optimistic.id, confirmed);
    notifier.replaceBet(optimistic.id, confirmed);

    final bets = container.read(gameStateProvider).bets;
    expect(bets, hasLength(1));
    expect(bets.single.id, confirmed.id);
  });
}
