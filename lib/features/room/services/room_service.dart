import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/game_constants.dart';
import '../../../core/utils/helpers.dart';
import '../models/room_model.dart';

/// Service for room CRUD operations via Supabase
class RoomService {
  final SupabaseClient _client;

  RoomService(this._client);

  /// Create a new room, returns the created Room
  Future<Room> createRoom(
    String hostId, {
    int maxRounds = GameConstants.defaultRounds,
    int maxPlayers = GameConstants.freeMaxPlayers,
    String? category,
  }) async {
    for (var attempt = 0; attempt < 12; attempt++) {
      final code = Helpers.generateRoomCode();
      final existing = await _client
          .from('rooms')
          .select('id')
          .eq('code', code)
          .limit(1);

      if ((existing as List).isNotEmpty) continue;

      try {
        final insertData = {
          'code': code,
          'host_id': hostId,
          'status': 'waiting',
          'current_round': 0,
          'max_rounds': maxRounds,
          'max_players': maxPlayers,
          'category': category == GameConstants.defaultCategory
              ? null
              : category,
          'round_phase': 'idle',
        };
        final response = await _insertRoom(insertData);
        return Room.fromJson(response);
      } on PostgrestException catch (error) {
        if (error.code == '23505') continue;
        if (_isMissingOptionalRoomColumn(error)) {
          final fallbackData = {
            'code': code,
            'host_id': hostId,
            'status': 'waiting',
            'current_round': 0,
            'max_rounds': maxRounds,
            'round_phase': 'idle',
          };
          final response = await _insertRoom(fallbackData);
          return Room.fromJson({
            ...response,
            'max_players': maxPlayers,
            'category': category == GameConstants.defaultCategory
                ? null
                : category,
          });
        }
        rethrow;
      }
    }

    throw StateError('Could not generate a unique room code.');
  }

  Future<Map<String, dynamic>> _insertRoom(Map<String, dynamic> data) async {
    final response = await _client.from('rooms').insert(data).select().single();
    return response;
  }

  bool _isMissingOptionalRoomColumn(PostgrestException error) {
    final message = error.message.toLowerCase();
    return message.contains('max_players') || message.contains('category');
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

    final rooms = rows
        .map((row) => Room.fromJson(row as Map<String, dynamic>))
        .toList();
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
  Future<void> updatePhase(
    String roomId,
    String phase, {
    int? round,
    String? currentQuestionId,
  }) async {
    final data = <String, dynamic>{'round_phase': phase};
    if (round != null) data['current_round'] = round;
    if (currentQuestionId != null) {
      data['current_question_id'] = currentQuestionId;
    }
    await _client.from('rooms').update(data).eq('id', roomId);
  }

  /// Start the game
  Future<void> startGame(String roomId, {String? currentQuestionId}) async {
    final data = {
      'status': 'playing',
      'current_round': 1,
      'round_phase': currentQuestionId == null
          ? RoundPhase.question.name
          : RoundPhase.guessing.name,
      if (currentQuestionId != null) 'current_question_id': currentQuestionId,
    };
    await _client.from('rooms').update(data).eq('id', roomId);
  }

  /// End the game
  Future<void> endGame(String roomId) async {
    await _client
        .from('rooms')
        .update({'status': 'finished', 'round_phase': 'idle'})
        .eq('id', roomId);
  }

  /// Reset a room so players can return to the lobby after a game.
  Future<void> resetToLobby(String roomId) async {
    await _client
        .from('rooms')
        .update({
          'status': 'waiting',
          'current_round': 0,
          'round_phase': 'idle',
        })
        .eq('id', roomId);
  }

  /// Delete room
  Future<void> deleteRoom(String roomId) async {
    await _client.from('rooms').delete().eq('id', roomId);
  }
}
