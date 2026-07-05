import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/player_model.dart';

/// Service for player CRUD + realtime
class PlayerService {
  final SupabaseClient _client;

  PlayerService(this._client);

  /// Add a player to a room, or revive the same local player if they rejoin.
  Future<Player> joinRoom({
    required String roomId,
    required String name,
    required String avatarColor,
    bool isHost = false,
    String? previousPlayerId,
  }) async {
    final previousPlayer = await _findReusablePlayer(
      roomId: roomId,
      playerId: previousPlayerId,
      name: name,
    );

    if (previousPlayer != null) {
      final response = await _client
          .from('players')
          .update({
            'name': name,
            'avatar_color': previousPlayer.avatarColor,
            'is_connected': true,
          })
          .eq('id', previousPlayer.id)
          .select()
          .single();
      return Player.fromJson(response);
    }

    final response = await _client
        .from('players')
        .insert({
          'room_id': roomId,
          'name': name,
          'avatar_color': avatarColor,
          'is_host': isHost,
          'is_ready': isHost, // Host is always ready
          'is_connected': true,
        })
        .select()
        .single();
    return Player.fromJson(response);
  }

  Future<Player?> _findReusablePlayer({
    required String roomId,
    required String? playerId,
    required String name,
  }) async {
    if (playerId != null && playerId.trim().isNotEmpty) {
      final response = await _client
          .from('players')
          .select()
          .eq('id', playerId)
          .eq('room_id', roomId)
          .maybeSingle();

      if (response != null) {
        return Player.fromJson(response);
      }
    }

    final existingByName = await _client
        .from('players')
        .select()
        .eq('room_id', roomId)
        .eq('name', name)
        .eq('is_host', false)
        .order('joined_at', ascending: false)
        .limit(1);

    final rows = existingByName as List;
    if (rows.isEmpty) return null;
    return Player.fromJson(rows.first as Map<String, dynamic>);
  }

  /// Get all players in a room
  Future<List<Player>> getPlayers(String roomId) async {
    final response = await _client
        .from('players')
        .select()
        .eq('room_id', roomId)
        .order('joined_at');
    return (response as List).map((e) => Player.fromJson(e)).toList();
  }

  /// Stream players in a room (Supabase Realtime Postgres Changes)
  Stream<List<Map<String, dynamic>>> streamPlayers(String roomId) {
    return _client
        .from('players')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId);
  }

  /// Toggle ready state
  Future<void> toggleReady(String playerId, bool isReady) async {
    await _client
        .from('players')
        .update({'is_ready': isReady})
        .eq('id', playerId);
  }

  /// Update score
  Future<void> updateScore(String playerId, int score) async {
    await _client.from('players').update({'score': score}).eq('id', playerId);
  }

  /// Update multiple player scores at once
  Future<void> updateScores(Map<String, int> playerScores) async {
    for (final entry in playerScores.entries) {
      await _client
          .from('players')
          .update({'score': entry.value})
          .eq('id', entry.key);
    }
  }

  /// Remove player from room
  Future<void> leaveRoom(String playerId) async {
    try {
      await setConnected(playerId, false);
      await _client.from('players').delete().eq('id', playerId);
    } catch (_) {
      // Ignore if delete fails due to RLS or constraints
    }
  }

  /// Set connection status
  Future<void> setConnected(String playerId, bool connected) async {
    await _client
        .from('players')
        .update({'is_connected': connected})
        .eq('id', playerId);
  }
}
