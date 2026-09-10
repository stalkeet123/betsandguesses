import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/features/game/models/classic_snapshot.dart';

Map<String, dynamic> payload() => {
  'room': <String, dynamic>{
    'id': 'room-a',
    'code': 'ABCDEF',
    'host_id': 'host',
    'status': 'playing',
    'game_mode': 'classic',
    'current_round': 2,
    'round_phase': 'guessing',
    'state_version': 12,
    'current_question_id': 'q2',
    'created_at': '2026-09-10T00:00:00Z',
    'phase_started_at': '2026-09-10T00:00:01Z',
    'phase_ends_at': '2026-09-10T00:00:21Z',
  },
  'question': {'id': 'q2', 'text_tr': 'How many?', 'answer': null},
  'players': <dynamic>[],
  'guesses': <dynamic>[],
  'bets': <dynamic>[],
};

void main() {
  test('one snapshot retains question, round, version and server deadline', () {
    final snapshot = ClassicSnapshot.fromResponse(payload());
    expect(snapshot.room.currentRound, 2);
    expect(snapshot.room.stateVersion, 12);
    expect(snapshot.room.phaseEndsAt, DateTime.utc(2026, 9, 10, 0, 0, 21));
    expect(snapshot.question!.id, 'q2');
    expect(snapshot.question!.answer, isNull);
  });
  test('transition without a selected question is valid', () {
    final data = payload();
    (data['room'] as Map)['current_question_id'] = null;
    (data['room'] as Map)['round_phase'] = 'question';
    data['question'] = null;
    expect(ClassicSnapshot.fromResponse(data).question, isNull);
  });
  test('a question from another round cannot be combined with the room', () {
    final data = payload();
    (data['question'] as Map)['id'] = 'q3';
    expect(() => ClassicSnapshot.fromResponse(data), throwsStateError);
  });
  test('a delayed previous round bet cannot enter the board', () {
    final data = payload();
    data['bets'] = [
      {
        'id': 'bet',
        'room_id': 'room-a',
        'round_number': 1,
        'player_id': 'p',
        'slot_index': 2,
        'chips': 5,
        'payout_multiplier': 2,
      },
    ];
    expect(() => ClassicSnapshot.fromResponse(data), throwsStateError);
  });
  test('cross-room player data is rejected', () {
    final data = payload();
    data['players'] = [
      {
        'id': 'p',
        'room_id': 'other',
        'name': 'Player',
        'joined_at': '2026-09-10T00:00:00Z',
      },
    ];
    expect(() => ClassicSnapshot.fromResponse(data), throwsStateError);
  });
  for (final field in ['room', 'players', 'guesses', 'bets']) {
    test('missing $field gives an explicit contract error', () {
      final data = payload()..remove(field);
      expect(() => ClassicSnapshot.fromResponse(data), throwsStateError);
    });
  }
  test('null RPC response gives an explicit contract error', () {
    expect(() => ClassicSnapshot.fromResponse(null), throwsStateError);
  });
}
