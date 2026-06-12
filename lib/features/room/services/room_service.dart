import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/helpers.dart';
import '../models/room_model.dart';

/// Service for room CRUD operations via Supabase
class RoomService {
  final SupabaseClient _client;

  RoomService(this._client);

  /// Create a new room, returns the created Room
  Future<Room> createRoom(String hostId) async {
    for (var attempt = 0; attempt < 12; attempt++) {
      final code = Helpers.generateRoomCode();
      final existing = await _client
          .from('rooms')
          .select('id')
          .eq('code', code)
          .limit(1);

      if ((existing as List).isNotEmpty) continue;

      try {
        final response = await _client
            .from('rooms')
            .insert({
              'code': code,
              'host_id': hostId,
              'status': 'waiting',
              'current_round': 0,
              'max_rounds': 8,
              'round_phase': 'idle',
            })
            .select()
            .single();
        return Room.fromJson(response);
      } on PostgrestException catch (error) {
        if (error.code == '23505') continue;
        rethrow;
      }
    }

    throw StateError('Could not generate a unique room code.');
  }

  /// Find a room by its code
  Future<Room?> findRoomByCode(String code) async {
    final response = await _client
        .from('rooms')
        .select()
        .eq('code', code.toUpperCase())
        .order('created_at', ascending: false)
        .limit(20);
    final rows = response as List;
    if (rows.isEmpty) return null;

    final rooms = rows.map((row) => Room.fromJson(row as Map<String, dynamic>)).toList();
    return rooms.firstWhere(
      (room) => room.canJoinLobby,
      orElse: () => rooms.first,
    );
  }

  /// Get room by ID
  Future<Room> getRoom(String roomId) async {
    final response = await _client
        .from('rooms')
        .select()
        .eq('id', roomId)
        .single();
    return Room.fromJson(response);
  }

  /// Update room status
  Future<void> updateRoom(String roomId, Map<String, dynamic> data) async {
    await _client.from('rooms').update(data).eq('id', roomId);
  }

  /// Update round phase
  Future<void> updatePhase(String roomId, String phase, {int? round}) async {
    final data = <String, dynamic>{'round_phase': phase};
    if (round != null) data['current_round'] = round;
    await _client.from('rooms').update(data).eq('id', roomId);
  }

  /// Start the game
  Future<void> startGame(String roomId) async {
    await _client.from('rooms').update({
      'status': 'playing',
      'current_round': 1,
      'round_phase': 'question',
    }).eq('id', roomId);
  }

  /// End the game
  Future<void> endGame(String roomId) async {
    await _client.from('rooms').update({
      'status': 'finished',
      'round_phase': 'idle',
    }).eq('id', roomId);
  }

  /// Reset a room so players can return to the lobby after a game.
  Future<void> resetToLobby(String roomId) async {
    await _client.from('rooms').update({
      'status': 'waiting',
      'current_round': 0,
      'round_phase': 'idle',
    }).eq('id', roomId);
  }

  /// Delete room
  Future<void> deleteRoom(String roomId) async {
    await _client.from('rooms').delete().eq('id', roomId);
  }
}
