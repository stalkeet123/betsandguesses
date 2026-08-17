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
    expect(
      room.partyChallengesPerPlayer,
      GameConstants.partyDefaultChallengesPerPlayer,
    );
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
  test('room preserves Party available items from database json', () {
    final room = Room.fromJson({
      'id': 'room-1',
      'code': 'ABC123',
      'host_id': 'host-1',
      'status': 'waiting',
      'game_mode': 'party',
      'party_available_items': ['paper', 'cup'],
      'party_challenges_per_player': 3,
      'created_at': '2026-08-12T10:00:00.000Z',
    });

    expect(room.partyAvailableItems, ['paper', 'cup']);
    expect(room.partyChallengesPerPlayer, 3);
    expect(room.toJson()['party_available_items'], ['paper', 'cup']);
    expect(room.toJson()['party_challenges_per_player'], 3);
    expect(
      room.copyWith(partyChallengesPerPlayer: 4).partyChallengesPerPlayer,
      4,
    );
  });

  test('older room payloads default Party available items to empty', () {
    final room = Room.fromJson({
      'id': 'room-2',
      'code': 'XYZ789',
      'host_id': 'host-2',
      'status': 'waiting',
      'created_at': '2026-08-12T10:00:00.000Z',
    });

    expect(room.partyAvailableItems, isEmpty);
    expect(
      room.partyChallengesPerPlayer,
      GameConstants.partyDefaultChallengesPerPlayer,
    );
  });
}
