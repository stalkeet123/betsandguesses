import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/player_model.dart';

/// Service for player CRUD + realtime
class PlayerService {
  final SupabaseClient _client;

  PlayerService(this._client);

  /// Add a player to a room
  Future<Player> joinRoom({
    required String roomId,
    required String name,
    required String avatarColor,
    bool isHost = false,
  }) async {
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
    await _client
        .from('players')
        .update({'score': score})
        .eq('id', playerId);
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
    await _client.from('players').delete().eq('id', playerId);
  }

  /// Set connection status
  Future<void> setConnected(String playerId, bool connected) async {
    await _client
        .from('players')
        .update({'is_connected': connected})
        .eq('id', playerId);
  }
}
