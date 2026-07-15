import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/player_model.dart';

/// Service for player CRUD + realtime.
class PlayerService {
  final SupabaseClient _client;

  static const _playerSelectColumns =
      'id, room_id, device_id, name, avatar_color, score, is_host, '
      'is_ready, is_connected, last_seen, joined_at';

  PlayerService(this._client);

  /// Join is an atomic upsert on (room_id, device_id). This prevents duplicate
  /// player rows for the same device even if leave/delete fails or retries race.
  Future<Player> joinRoom({
    required String roomId,
    required String deviceId,
    required String name,
    required String avatarColor,
    bool isHost = false,
  }) async {
    final response = await _client.rpc(
      'join_room_v2',
      params: {
        'p_room_id': roomId,
        'p_device_id': deviceId,
        'p_name': name,
        'p_avatar_color': avatarColor,
      },
    );
    return Player.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<List<Player>> getPlayers(String roomId) async {
    final response = await _client
        .from('players')
        .select(_playerSelectColumns)
        .eq('room_id', roomId)
        .order('joined_at');
    return (response as List).map((e) => Player.fromJson(e)).toList();
  }

  Stream<List<Map<String, dynamic>>> streamPlayers(String roomId) {
    return _client
        .from('players')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId);
  }

  List<Player> collapseDuplicateConnectedPlayers(List<Player> players) {
    final output = <Player>[];
    final seen = <String, Player>{};

    for (final player in players) {
      if (!player.isConnected) {
        output.add(player);
        continue;
      }

      final key = player.deviceId;
      final current = seen[key];
      if (current == null) {
        seen[key] = player;
        output.add(player);
        continue;
      }

      final shouldReplace =
          (!current.isHost && player.isHost) ||
          (current.isHost == player.isHost &&
              player.joinedAt.isAfter(current.joinedAt));
      if (!shouldReplace) continue;

      final index = output.indexWhere((item) => item.id == current.id);
      if (index != -1) output[index] = player;
      seen[key] = player;
    }

    output.sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    return output;
  }

  Future<void> toggleReady(String playerId, bool isReady) async {
    await _client.rpc(
      'set_player_ready_v2',
      params: {'p_player_id': playerId, 'p_is_ready': isReady},
    );
  }

  Future<void> leaveRoom(String playerId) async {
    await setConnected(playerId, false);
  }

  Future<void> setConnected(String playerId, bool connected) async {
    await _client.rpc(
      'set_player_connected_v2',
      params: {'p_player_id': playerId, 'p_connected': connected},
    );
  }
}
