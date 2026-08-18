import 'package:supabase_flutter/supabase_flutter.dart';

import '../../room/models/room_model.dart';
import '../models/party_moment.dart';
import '../models/party_snapshot.dart';

class PartyGameService {
  final SupabaseClient _client;

  PartyGameService(this._client);

  Future<PartySnapshot> startGame({
    required String roomId,
    int bettingDurationSeconds = 30,
  }) async {
    final response = await _client.rpc(
      'start_party_game_v2',
      params: {
        'p_room_id': roomId,
        'p_betting_duration_seconds': bettingDurationSeconds,
      },
    );
    return PartySnapshot.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<PartySnapshot> getSnapshot(String roomId) async {
    final response = await _client.rpc(
      'get_party_snapshot_v1',
      params: {'p_room_id': roomId},
    );
    return PartySnapshot.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<PartySnapshot> advanceToBetting(
    String roomId, {
    int durationSeconds = 30,
  }) async {
    final response = await _client.rpc(
      'advance_party_to_betting_v1',
      params: {'p_room_id': roomId, 'p_duration_seconds': durationSeconds},
    );
    return _snapshot(response);
  }

  Future<PartySnapshot> placeBet({
    required String roomId,
    required int slotIndex,
    required int chips,
    required String clientActionId,
    double? positionX,
    double? positionY,
  }) async {
    await _client.rpc(
      'place_party_bet_v1',
      params: {
        'p_room_id': roomId,
        'p_slot_index': slotIndex,
        'p_chips': chips,
        'p_client_action_id': clientActionId,
        'p_position_x': positionX,
        'p_position_y': positionY,
      },
    );
    return getSnapshot(roomId);
  }

  Future<PartySnapshot> moveBet({
    required String roomId,
    required String betId,
    required int slotIndex,
    double? positionX,
    double? positionY,
  }) async {
    await _client.rpc(
      'move_party_bet_v1',
      params: {
        'p_room_id': roomId,
        'p_bet_id': betId,
        'p_slot_index': slotIndex,
        'p_position_x': positionX,
        'p_position_y': positionY,
      },
    );
    return getSnapshot(roomId);
  }

  Future<PartySnapshot> removeBet({
    required String roomId,
    required String betId,
  }) async {
    await _client.rpc(
      'remove_party_bet_v1',
      params: {'p_room_id': roomId, 'p_bet_id': betId},
    );
    return getSnapshot(roomId);
  }

  Future<PartySnapshot> rerollChallenge(String roomId) async {
    final response = await _client.rpc(
      'reroll_party_challenge_v1',
      params: {'p_room_id': roomId},
    );
    return _snapshot(response);
  }

  Future<PartySnapshot> beginPoll(String roomId) async {
    final response = await _client.rpc(
      'begin_party_poll_v1',
      params: {'p_room_id': roomId},
    );
    return _snapshot(response);
  }

  Future<PartySnapshot> beginChoice(String roomId) async {
    final response = await _client.rpc(
      'begin_party_choice_v1',
      params: {'p_room_id': roomId},
    );
    return _snapshot(response);
  }

  Future<PartySnapshot> submitChoice({
    required String roomId,
    required int choiceIndex,
  }) async {
    final response = await _client.rpc(
      'submit_party_choice_v1',
      params: {'p_room_id': roomId, 'p_choice': choiceIndex},
    );
    return _snapshot(response);
  }

  Future<PartySnapshot> beginReady(String roomId) async {
    final response = await _client.rpc(
      'begin_party_ready_v1',
      params: {'p_room_id': roomId},
    );
    return _snapshot(response);
  }

  Future<PartySnapshot> startAction(String roomId) async {
    final response = await _client.rpc(
      'start_party_action_v1',
      params: {'p_room_id': roomId},
    );
    return _snapshot(response);
  }

  Future<PartySnapshot> openResultEntry(String roomId) async {
    final response = await _client.rpc(
      'open_party_result_entry_v1',
      params: {'p_room_id': roomId},
    );
    return _snapshot(response);
  }

  Future<PartySnapshot> submitResult({
    required String roomId,
    required int result,
  }) async {
    final response = await _client.rpc(
      'submit_party_result_v1',
      params: {'p_room_id': roomId, 'p_result': result},
    );
    return _snapshot(response);
  }

  Future<PartySnapshot> confirmResult(String roomId) async {
    final response = await _client.rpc(
      'confirm_party_result_v1',
      params: {'p_room_id': roomId},
    );
    return _snapshot(response);
  }

  Future<PartySnapshot> disputeResult(String roomId) async {
    final response = await _client.rpc(
      'dispute_party_result_v1',
      params: {'p_room_id': roomId},
    );
    return _snapshot(response);
  }

  Future<Map<String, dynamic>> advanceRound(String roomId) async {
    final response = await _client.rpc(
      'advance_party_round_v2',
      params: {'p_room_id': roomId, 'p_betting_duration_seconds': 30},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<List<PartyRecapRound>> getRecap(String roomId) async {
    final response = await _client.rpc(
      'get_party_recap_v1',
      params: {'p_room_id': roomId},
    );
    return (response as List? ?? const [])
        .map(
          (value) =>
              PartyRecapRound.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList(growable: false);
  }

  Future<Room> resetToLobby(String roomId) async {
    final response = await _client.rpc(
      'reset_party_to_lobby_v1',
      params: {'p_room_id': roomId},
    );
    return Room.fromJson(Map<String, dynamic>.from(response as Map));
  }

  PartySnapshot _snapshot(Object? response) {
    return PartySnapshot.fromJson(Map<String, dynamic>.from(response as Map));
  }
}
