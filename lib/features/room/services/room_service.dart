import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/game_constants.dart';
import '../../../core/errors/monetization_exceptions.dart';
import '../../../core/utils/helpers.dart';
import '../models/room_model.dart';

Exception? roomCreationExceptionFor(PostgrestException error) {
  if (isFreeHostLimitReachedMessage(error.message)) {
    return const FreeHostLimitReachedException();
  }
  final requirement = premiumSetupRequirementForMessage(error.message);
  if (requirement != null) {
    return PremiumSetupRequiredException(requirement);
  }
  return null;
}

/// Service for room CRUD operations via Supabase
class RoomService {
  final SupabaseClient _client;
  Duration _serverClockOffset = Duration.zero;
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
    _lastServerClockSyncAt = requestFinishedAt;
    return serverNow;
  }

  /// Create a new room, returns the created Room
  Future<Room> createRoom(
    String _, {
    int maxRounds = GameConstants.defaultRounds,
    int maxPlayers = GameConstants.freeMaxPlayers,
    String? category,
    GameMode gameMode = GameMode.classic,
  }) async {
    for (var attempt = 0; attempt < 12; attempt++) {
      final code = Helpers.generateRoomCode();
      try {
        final response = await _client.rpc(
          'create_room_v4',
          params: {
            'p_code': code,
            'p_max_rounds': maxRounds,
            'p_max_players': maxPlayers,
            'p_category': category == GameConstants.defaultCategory
                ? null
                : category,
            'p_game_mode': gameMode.name,
          },
        );
        return Room.fromJson(Map<String, dynamic>.from(response as Map));
      } on PostgrestException catch (error) {
        if (error.code == '23505') continue;
        final mappedException = roomCreationExceptionFor(error);
        if (mappedException != null) throw mappedException;
        rethrow;
      }
    }

    throw StateError('Could not generate a unique room code.');
  }

  Future<Room?> configurePartyItems({
    required String roomId,
    required List<String> availableItems,
  }) async {
    try {
      final response = await _client.rpc(
        'configure_party_room_items_v1',
        params: {'p_room_id': roomId, 'p_available_items': availableItems},
      );
      return Room.fromJson(Map<String, dynamic>.from(response as Map));
    } on PostgrestException catch (error) {
      // Keep Party room creation compatible during an additive backend rollout.
      // Item filtering becomes authoritative when the migration is installed.
      if (error.code == 'PGRST202') return null;
      rethrow;
    }
  }

  Future<Room> configurePartyRoom({
    required String roomId,
    required List<String> availableItems,
    required int challengesPerPlayer,
  }) async {
    try {
      final response = await _client.rpc(
        'configure_party_room_v2',
        params: {
          'p_room_id': roomId,
          'p_available_items': availableItems,
          'p_challenges_per_player': challengesPerPlayer,
        },
      );
      return Room.fromJson(Map<String, dynamic>.from(response as Map));
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST202') {
        final legacyRoom = await configurePartyItems(
          roomId: roomId,
          availableItems: availableItems,
        );
        if (legacyRoom != null) return legacyRoom;
        return getRoom(roomId);
      }
      rethrow;
    }
  }

  /// Find a room by its code
  Future<Room?> findRoomByCode(String code) async {
    final response = await _client.rpc(
      'find_room_by_code_v2',
      params: {'p_code': code},
    );
    if (response == null) return null;
    return Room.fromJson(Map<String, dynamic>.from(response as Map));
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

  Future<Room?> claimPhaseTransition({
    required String roomId,
    required int round,
    required String expectedPhase,
    required String nextPhase,
    int? durationSeconds,
    int? nextRound,
    String? currentQuestionId,
  }) async {
    final response = await _client.rpc(
      'claim_game_phase_v1',
      params: {
        'p_room_id': roomId,
        'p_round_number': round,
        'p_expected_phase': expectedPhase,
        'p_next_phase': nextPhase,
        'p_duration_seconds': durationSeconds,
        'p_next_round': nextRound,
        'p_current_question_id': currentQuestionId,
      },
    );
    if (response == null) return null;
    return Room.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<bool> finishGameIfCurrent({
    required String roomId,
    required int round,
  }) async {
    final response = await _client.rpc(
      'finish_game_v2',
      params: {'p_room_id': roomId, 'p_round_number': round},
    );
    return response == true;
  }

  Future<Room?> resetToLobbyAtomic(String roomId) async {
    final response = await _client.rpc(
      'reset_room_to_lobby_v1',
      params: {'p_room_id': roomId},
    );
    return Room.fromJson(Map<String, dynamic>.from(response as Map));
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
