import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:witsgame/features/game/models/bet_model.dart';
import 'package:witsgame/features/game/models/guess_model.dart';
import 'package:witsgame/features/game/services/game_service.dart';

void main() {
  late GameService service;

  setUp(() {
    service = GameService(
      SupabaseClient('https://example.supabase.co', 'test-anon-key'),
    );
  });

  group('determineWinner', () {
    test('returns the closest guess without going over', () {
      final guesses = [
        _guess(id: 'a', value: 100),
        _guess(id: 'b', value: 140),
        _guess(id: 'c', value: 180),
      ];

      expect(service.determineWinner(guesses, 160)?.id, 'b');
    });

    test('returns null when every guess is over the answer', () {
      final guesses = [
        _guess(id: 'a', value: 100),
        _guess(id: 'b', value: 140),
      ];

      expect(service.determineWinner(guesses, 90), isNull);
    });
  });

  group('betting board', () {
    final guesses = [
      _guess(id: 'a', value: 10),
      _guess(id: 'b', value: 20),
      _guess(id: 'c', value: 30),
      _guess(id: 'd', value: 40),
    ];

    test('uses four sorted unique guesses as boundaries', () {
      expect(service.boardBoundaryValues(guesses.reversed.toList()), [
        10,
        20,
        30,
        40,
      ]);
    });

    test('keeps the current five-slot edge behavior', () {
      expect(service.determineWinningBetSlotIndex(guesses, 9), 0);
      expect(service.determineWinningBetSlotIndex(guesses, 10), 1);
      expect(service.determineWinningBetSlotIndex(guesses, 20), 2);
      expect(service.determineWinningBetSlotIndex(guesses, 30), 2);
      expect(service.determineWinningBetSlotIndex(guesses, 40), 3);
      expect(service.determineWinningBetSlotIndex(guesses, 41), 4);
    });

    test('creates four ascending boundaries when guesses are missing', () {
      final boundaries = service.boardBoundaryValues([
        _guess(id: 'a', value: 100),
        _guess(id: 'b', value: 200),
      ]);

      expect(boundaries, hasLength(4));
      expect(boundaries.toSet(), hasLength(4));
      expect(List<int>.from(boundaries)..sort(), boundaries);
      expect(boundaries.first, 100);
      expect(boundaries.last, 200);
    });
  });

  test('calculatePayouts aggregates winning bets by player', () {
    final guesses = [
      _guess(id: 'a', value: 10),
      _guess(id: 'b', value: 20),
      _guess(id: 'c', value: 30),
      _guess(id: 'd', value: 40),
    ];
    final bets = [
      _bet(id: 'bet-1', playerId: 'player-a', slotIndex: 2, chips: 2),
      _bet(id: 'bet-2', playerId: 'player-a', slotIndex: 2, chips: 1),
      _bet(id: 'bet-3', playerId: 'player-b', slotIndex: 4, chips: 3),
    ];

    expect(
      service.calculatePayouts(guesses: guesses, bets: bets, correctAnswer: 25),
      {'player-a': 6},
    );
  });

  test('round settlement result parses authoritative scores', () {
    final result = RoundSettlementResult.fromJson({
      'status': 'settled',
      'state_version': 12,
      'answer': 123,
      'winning_guess_id': 'guess-b',
      'winning_slot_index': 3,
      'scores': {'player-a': 45, 'player-b': '30'},
      'payouts': <String, int>{},
    });

    expect(result.didSettle, isTrue);
    expect(result.stateVersion, 12);
    expect(result.answer, 123);
    expect(result.winningGuessId, 'guess-b');
    expect(result.winningSlotIndex, 3);
    expect(result.scores, {'player-a': 45, 'player-b': 30});
  });
}

Guess _guess({required String id, required int value}) {
  return Guess(
    id: id,
    roomId: 'room-1',
    roundNumber: 1,
    playerId: 'player-$id',
    value: value,
  );
}

Bet _bet({
  required String id,
  required String playerId,
  required int slotIndex,
  required int chips,
}) {
  return Bet(
    id: id,
    roomId: 'room-1',
    roundNumber: 1,
    playerId: playerId,
    slotIndex: slotIndex,
    chips: chips,
    payoutMultiplier: 2,
  );
}
