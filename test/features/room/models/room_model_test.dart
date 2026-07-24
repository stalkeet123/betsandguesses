import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/core/constants/game_constants.dart';
import 'package:witsgame/features/room/models/room_model.dart';

void main() {
  Map<String, dynamic> roomJson({String? gameMode}) => {
    'id': 'room-1',
    'code': 'ABC123',
    'host_id': 'host-1',
    'status': 'waiting',
    'current_round': 0,
    'max_rounds': 8,
    'max_players': 6,
    if (gameMode != null) 'game_mode': gameMode,
    'round_phase': 'idle',
    'state_version': 0,
    'created_at': '2026-07-24T00:00:00Z',
  };

  test('old room payloads remain classic by default', () {
    final room = Room.fromJson(roomJson());

    expect(room.gameMode, GameMode.classic);
    expect(room.toJson()['game_mode'], 'classic');
  });

  test('party room payload keeps its explicit mode', () {
    final room = Room.fromJson(roomJson(gameMode: 'party'));

    expect(room.gameMode, GameMode.party);
    expect(
      room.copyWith(gameMode: GameMode.classic).gameMode,
      GameMode.classic,
    );
  });
}
