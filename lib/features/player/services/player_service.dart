import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/player_model.dart';

/// Service for player CRUD + realtime.
class PlayerService {
  final SupabaseClient _client;

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
    final existingPlayers = await getPlayers(roomId);
    final normalizedName = _normalizeName(name);
    final sameNameDifferentDevice = existingPlayers.any(
      (player) =>
          player.isConnected &&
          player.deviceId != deviceId &&
          _normalizeName(player.name) == normalizedName,
    );
    if (sameNameDifferentDevice) {
      throw StateError('That name is already taken in this lobby.');
    }

    final existingForDevice = _findPlayerForDevice(existingPlayers, deviceId);
    final now = DateTime.now().toIso8601String();

    final response = await _client
        .from('players')
        .upsert({
          'room_id': roomId,
          'device_id': deviceId,
          'name': name,
          'avatar_color': existingForDevice?.avatarColor ?? avatarColor,
          'is_host': existingForDevice?.isHost == true || isHost,
          'is_ready': existingForDevice?.isHost == true || isHost,
          'is_connected': true,
          'last_seen': now,
        }, onConflict: 'room_id,device_id')
        .select()
        .single();

    return Player.fromJson(response);
  }

  Future<List<Player>> getPlayers(String roomId) async {
    final response = await _client
        .from('players')
        .select()
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
    await _client
        .from('players')
        .update({'is_ready': isReady})
        .eq('id', playerId);
  }

  Future<void> updateScore(String playerId, int score) async {
    await _client.from('players').update({'score': score}).eq('id', playerId);
  }

  Future<void> updateScores(Map<String, int> playerScores) async {
    for (final entry in playerScores.entries) {
      await _client
          .from('players')
          .update({'score': entry.value})
          .eq('id', entry.key);
    }
  }

  Future<void> leaveRoom(String playerId) async {
    await setConnected(playerId, false);
  }

  Future<void> setConnected(String playerId, bool connected) async {
    await _client
        .from('players')
        .update({
          'is_connected': connected,
          'last_seen': DateTime.now().toIso8601String(),
        })
        .eq('id', playerId);
  }

  String _normalizeName(String name) => name.trim().toLowerCase();

  Player? _findPlayerForDevice(List<Player> players, String deviceId) {
    for (final player in players) {
      if (player.deviceId == deviceId) return player;
    }
    return null;
  }
}
