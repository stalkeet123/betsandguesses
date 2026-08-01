import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/features/party/models/party_snapshot.dart';
import 'package:witsgame/features/party/providers/party_local_media_provider.dart';

void main() {
  test(
    'Party count snapshot reads authored boundaries and performer bonus',
    () {
      final snapshot = PartySnapshot.fromJson({
        'room': {
          'id': 'room-1',
          'code': 'ABC123',
          'host_id': 'player-1',
          'status': 'playing',
          'current_round': 1,
          'max_rounds': 3,
          'game_mode': 'party',
          'round_phase': 'revealAnswer',
          'created_at': '2026-07-25T00:00:00Z',
        },
        'state_version': 4,
        'turn_index': 0,
        'turn_count': 3,
        'round': {
          'number': 1,
          'phase': 'reveal',
          'phase_started_at': '2026-07-25T00:00:00Z',
          'phase_ends_at': '2026-07-25T00:00:07Z',
          'performer': {'id': 'player-1', 'name': 'Alex'},
          'witness': {'id': 'player-2', 'name': 'Sam'},
          'challenge': {
            'id': 'challenge-1',
            'text': 'How many push-ups can Alex complete?',
            'rules': 'Complete reps only.',
            'answer_unit': 'push-ups',
            'duration_seconds': 60,
            'max_result': 150,
            'bet_boundaries': [5, 12, 20, 30],
          },
          'submitted_guess_count': 0,
          'performer_ready': true,
          'own_guess': null,
          'guesses': [],
          'bets': [],
          'proposed_result': 32,
          'performer_bonus': 5,
        },
        'scores': {'player-1': 25},
      });

      expect(snapshot.round.challenge.betBoundaries, [5, 12, 20, 30]);
      expect(snapshot.round.ownGuess, isNull);
      expect(snapshot.round.performerBonus, 5);
    },
  );

  test('Party binary snapshot exposes manual YES or NO challenge metadata', () {
    final challenge = PartyChallenge.fromJson({
      'id': 'binary-1',
      'text': 'Can Alex balance on one leg?',
      'rules': 'The raised foot cannot touch the floor.',
      'answer_unit': 'result',
      'duration_seconds': 20,
      'max_result': 1,
      'bet_boundaries': [],
      'challenge_type': 'binary',
      'performer_success_bonus': 3,
    });

    expect(challenge.isBinary, isTrue);
    expect(challenge.betBoundaries, isEmpty);
    expect(challenge.durationSeconds, 20);
    expect(challenge.performerSuccessBonus, 3);
  });

  test(
    'Party attempt challenge maps success and failure to fixed bet slots',
    () {
      final challenge = PartyChallenge.fromJson({
        'id': 'attempt-1',
        'text': 'On which attempt will Alex land a bottle flip?',
        'rules': 'Five attempts. The bottle must remain upright.',
        'answer_unit': 'attempt',
        'duration_seconds': 60,
        'max_result': 5,
        'bet_boundaries': [],
        'challenge_type': 'attempt',
        'category': 'precision',
        'result_direction': 'lower',
        'performer_success_bonus': 5,
      });

      expect(challenge.isAttempt, isTrue);
      expect(challenge.isBinary, isFalse);
      expect(challenge.betBoundaries, isEmpty);
      expect(challenge.resultDirection, PartyResultDirection.lower);
      expect(challenge.betSlotForResult(1), 0);
      expect(challenge.betSlotForResult(2), 1);
      expect(challenge.betSlotForResult(3), 2);
      expect(challenge.betSlotForResult(4), 3);
      expect(challenge.betSlotForResult(5), 3);
      expect(challenge.betSlotForResult(0), 4);
      expect(challenge.betSlotForResult(6), isNull);
    },
  );
  test('local Party media remains inside its provider container', () {
    final firstDevice = ProviderContainer();
    final secondDevice = ProviderContainer();
    addTearDown(firstDevice.dispose);
    addTearDown(secondDevice.dispose);

    firstDevice
        .read(partyLocalMediaProvider.notifier)
        .add(
          roomId: 'room-1',
          roundNumber: 1,
          playerId: 'player-1',
          playerName: 'Alex',
          playerColor: '#E47A32',
          bytes: Uint8List.fromList([1, 2, 3]),
        );

    expect(firstDevice.read(partyLocalMediaProvider), hasLength(1));
    expect(secondDevice.read(partyLocalMediaProvider), isEmpty);
  });
}
