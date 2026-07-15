import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/game_constants.dart';
import '../../../core/utils/helpers.dart';
import '../models/room_model.dart';

/// Service for room CRUD operations via Supabase
class RoomService {
  final SupabaseClient _client;
  Duration _serverClockOffset = Duration.zero;
  bool _hasServerClock = false;
  DateTime? _lastServerClockSyncAt;

  static const _serverClockCacheDuration = Duration(minutes: 1);

  RoomService(this._client);

  DateTime get serverNow => DateTime.now().toUtc().add(_serverClockOffset);

  Future<DateTime> synchronizeServerClock({bool force = false}) async {
    final lastSync = _lastServerClockSyncAt;
    if (!force &&
        lastSync != null &&
        DateTime.now().toUtc().difference(lastSync) <
            _serverClockCacheDuration) {
      return serverNow;
    }

    final requestStartedAt = DateTime.now().toUtc();
    final response = await _client.rpc('game_server_time');
    final requestFinishedAt = DateTime.now().toUtc();
    final serverTime = _parseServerTime(response);
    final midpoint = requestStartedAt.add(
      requestFinishedAt.difference(requestStartedAt) ~/ 2,
    );
    _serverClockOffset = serverTime.difference(midpoint);
    _hasServerClock = true;
    _lastServerClockSyncAt = requestFinishedAt;
    return serverNow;
  }

  /// Create a new room, returns the created Room
  Future<Room> createRoom(
    String hostId, {
    int maxRounds = GameConstants.defaultRounds,
    int maxPlayers = GameConstants.freeMaxPlayers,
    String? category,
  }) async {
    for (var attempt = 0; attempt < 12; attempt++) {
      final code = Helpers.generateRoomCode();
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

  Stream<List<Map<String, dynamic>>> streamRoom(String roomId) {
    return _client.from('rooms').stream(primaryKey: ['id']).eq('id', roomId);
  }

  /// Update room status
  Future<void> updateRoom(String roomId, Map<String, dynamic> data) async {
    await _client.from('rooms').update(data).eq('id', roomId);
  }

  /// Update round phase
  Future<DateTime?> updatePhase(
    String roomId,
    String phase, {
    int? round,
    String? currentQuestionId,
    int? durationSeconds,
  }) async {
    final data = <String, dynamic>{'round_phase': phase};
    if (round != null) data['current_round'] = round;
    if (currentQuestionId != null) {
      data['current_question_id'] = currentQuestionId;
    }
    final deadline = await _addPhaseTiming(data, durationSeconds);
    await _updateRoomWithTimingFallback(roomId, data);
    return deadline;
  }

  Future<Room?> claimPhaseTransition({
    required String roomId,
    required int round,
    required String expectedPhase,
    required String nextPhase,
    int? durationSeconds,
    int? nextRound,
    String? currentQuestionId,
  }) async {
    final data = <String, dynamic>{
      'round_phase': nextPhase,
      if (nextRound != null) 'current_round': nextRound,
      if (currentQuestionId != null) 'current_question_id': currentQuestionId,
    };
    await _addPhaseTiming(data, durationSeconds);

    try {
      final response = await _client
          .from('rooms')
          .update(data)
          .eq('id', roomId)
          .eq('current_round', round)
          .eq('round_phase', expectedPhase)
          .select()
          .maybeSingle();
      return response == null ? null : Room.fromJson(response);
    } on PostgrestException catch (error) {
      if (!_isMissingTimingColumn(error)) rethrow;
      final legacyData = Map<String, dynamic>.from(data)
        ..remove('phase_started_at')
        ..remove('phase_ends_at');
      final response = await _client
          .from('rooms')
          .update(legacyData)
          .eq('id', roomId)
          .eq('current_round', round)
          .eq('round_phase', expectedPhase)
          .select()
          .maybeSingle();
      return response == null ? null : Room.fromJson(response);
    }
  }

  Future<bool> finishGameIfCurrent({
    required String roomId,
    required int round,
  }) async {
    final response = await _client
        .from('rooms')
        .update({
          'status': 'finished',
          'round_phase': 'idle',
          'phase_ends_at': null,
        })
        .eq('id', roomId)
        .eq('current_round', round)
        .eq('round_phase', RoundPhase.revealAnswer.name)
        .select('id');
    return (response as List).isNotEmpty;
  }

  /// Start the game
  Future<DateTime?> startGame(
    String roomId, {
    String? currentQuestionId,
    int? durationSeconds,
  }) async {
    final data = <String, dynamic>{
      'status': 'playing',
      'current_round': 1,
      'round_phase': currentQuestionId == null
          ? RoundPhase.question.name
          : RoundPhase.guessing.name,
      if (currentQuestionId != null) 'current_question_id': currentQuestionId,
    };
    final deadline = await _addPhaseTiming(data, durationSeconds);
    await _updateRoomWithTimingFallback(roomId, data);
    return deadline;
  }

  /// End the game
  Future<void> endGame(String roomId) async {
    await _client
        .from('rooms')
        .update({
          'status': 'finished',
          'round_phase': 'idle',
          'phase_ends_at': null,
        })
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
          'current_question_id': null,
          'phase_started_at': null,
          'phase_ends_at': null,
        })
        .eq('id', roomId);
  }

  /// Delete room
  Future<void> deleteRoom(String roomId) async {
    await _client.from('rooms').delete().eq('id', roomId);
  }

  Future<DateTime?> _addPhaseTiming(
    Map<String, dynamic> data,
    int? durationSeconds,
  ) async {
    DateTime now;
    try {
      now = await synchronizeServerClock();
    } catch (_) {
      now = _hasServerClock ? serverNow : DateTime.now().toUtc();
    }

    final deadline = durationSeconds == null
        ? null
        : now.add(Duration(seconds: durationSeconds));
    data['phase_started_at'] = now.toIso8601String();
    data['phase_ends_at'] = deadline?.toIso8601String();
    return deadline;
  }

  Future<void> _updateRoomWithTimingFallback(
    String roomId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _client.from('rooms').update(data).eq('id', roomId);
    } on PostgrestException catch (error) {
      if (!_isMissingTimingColumn(error)) rethrow;
      final legacyData = Map<String, dynamic>.from(data)
        ..remove('phase_started_at')
        ..remove('phase_ends_at');
      await _client.from('rooms').update(legacyData).eq('id', roomId);
    }
  }

  bool _isMissingTimingColumn(PostgrestException error) {
    final message = error.message.toLowerCase();
    return message.contains('phase_started_at') ||
        message.contains('phase_ends_at');
  }

  DateTime _parseServerTime(Object? value) {
    if (value is DateTime) return value.toUtc();
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.toUtc();
    }
    if (value is Map) {
      for (final entry in value.values) {
        try {
          return _parseServerTime(entry);
        } on FormatException {
          continue;
        }
      }
    }
    if (value is List && value.isNotEmpty) {
      return _parseServerTime(value.first);
    }
    throw const FormatException('Invalid game_server_time response.');
  }
}
