import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/features/player/models/player_model.dart';

void main() {
  Map<String, dynamic> playerJson() => {
    'id': 'player-1',
    'room_id': 'room-1',
    'device_id': 'device-1',
    'name': 'Alex',
    'avatar_color': '#FF705D',
    'score': 15,
    'joined_at': '2026-08-13T00:00:00Z',
  };

  test('parses a negative bank independently from legacy playable score', () {
    final player = Player.fromJson({...playerJson(), 'bank_score': -30});

    expect(player.score, 15);
    expect(player.bankScore, -30);
    expect(player.toJson()['bank_score'], -30);
  });

  test('falls back to score for payloads from a pre-bank server', () {
    final player = Player.fromJson(playerJson());

    expect(player.bankScore, 15);
  });
}
