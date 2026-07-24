import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/core/constants/game_constants.dart';
import 'package:witsgame/features/party/models/party_snapshot.dart';

void main() {
  Map<String, dynamic> snapshotJson() => {
    'room': {
      'id': 'room-1',
      'code': 'ABC123',
      'host_id': 'host-1',
      'status': 'playing',
      'current_round': 1,
      'max_rounds': 4,
      'max_players': 6,
      'game_mode': 'party',
      'round_phase': 'guessing',
      'state_version': 0,
      'created_at': '2026-07-24T00:00:00Z',
    },
    'state_version': 1,
    'turn_index': 0,
    'turn_count': 4,
    'round': {
      'number': 1,
      'phase': 'betting',
      'phase_started_at': '2026-07-24T00:00:00Z',
      'phase_ends_at': '2026-07-24T00:00:30Z',
      'performer': {'id': 'john-id', 'name': 'John', 'avatar_color': '#FF705D'},
      'witness': {'id': 'maya-id', 'name': 'Maya'},
      'challenge': {
        'id': 'challenge-1',
        'text': 'How many push-ups can John complete in 60 seconds?',
        'rules': 'Only complete reps count.',
        'answer_unit': 'push-ups',
        'duration_seconds': 60,
        'max_result': 150,
      },
      'submitted_guess_count': 4,
      'performer_ready': true,
      'own_guess': {
        'id': 'guess-me',
        'value': 24,
        'is_performer_prediction': false,
        'player_id': 'me',
      },
      'guesses': [
        {'id': 'guess-1', 'value': 20, 'is_performer_prediction': false},
      ],
      'bets': [
        {'id': 'bet-me', 'slot_index': 2, 'chips': 1, 'player_id': 'me'},
      ],
      'proposed_result': null,
    },
    'scores': {'me': 15, 'john-id': 15},
  };

  test('parses a Party snapshot without requiring leaked guess owners', () {
    final snapshot = PartySnapshot.fromJson(snapshotJson());

    expect(snapshot.room.gameMode, GameMode.party);
    expect(snapshot.round.phase, PartyRoundPhase.betting);
    expect(snapshot.round.phase.gamePhase, RoundPhase.betting);
    expect(snapshot.round.challenge.durationSeconds, 60);
    expect(snapshot.round.performerReady, isTrue);
    expect(snapshot.round.guesses.single.playerId, isNull);
    expect(snapshot.round.bets.single.playerId, 'me');
    expect(snapshot.scores['john-id'], 15);
  });

  test('maps every authoritative Party phase to the shared game surface', () {
    expect(PartyRoundPhase.guessing.gamePhase, RoundPhase.guessing);
    expect(PartyRoundPhase.betting.gamePhase, RoundPhase.betting);
    expect(PartyRoundPhase.ready.gamePhase, RoundPhase.partyReady);
    expect(PartyRoundPhase.action.gamePhase, RoundPhase.partyAction);
    expect(PartyRoundPhase.resultEntry.gamePhase, RoundPhase.partyResultEntry);
    expect(
      PartyRoundPhase.resultConfirm.gamePhase,
      RoundPhase.partyResultConfirm,
    );
    expect(PartyRoundPhase.reveal.gamePhase, RoundPhase.revealAnswer);
  });
}
