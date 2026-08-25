import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/monetization_exceptions.dart';
import '../constants/party_poll_rules.dart';
import '../models/party_poll_snapshot.dart';

class PartyPollBetPlacement {
  final PartyPollBet bet;
  final PartyPollSnapshot snapshot;

  const PartyPollBetPlacement({required this.bet, required this.snapshot});
}

class PartyPollService {
  final SupabaseClient _client;

  PartyPollService(this._client);

  Future<PartyPollSnapshot> startGame({
    required String roomId,
    int bettingDurationSeconds = 30,
  }) async {
    try {
      return await _snapshotRpc('start_party_poll_v2', {
        'p_room_id': roomId,
        'p_betting_duration_seconds': bettingDurationSeconds,
      });
    } on PostgrestException catch (error) {
      if (isFreeHostLimitReachedMessage(error.message)) {
        throw const FreeHostLimitReachedException();
      }
      rethrow;
    }
  }

  Future<PartyPollSnapshot> getSnapshot(String roomId) =>
      _snapshotRpc('get_party_poll_snapshot_v1', {'p_room_id': roomId});

  Future<PartyPollBetPlacement> placeBet({
    required String roomId,
    required String targetPlayerId,
    required int chips,
    required String clientActionId,
    double? positionX,
    double? positionY,
  }) async {
    if (!PartyPollRules.isValidChip(chips)) {
      throw ArgumentError.value(
        chips,
        'chips',
        'Expected one of ${PartyPollRules.chipValues}.',
      );
    }

    final response = await _client.rpc(
      'place_party_poll_bet_v1',
      params: {
        'p_room_id': roomId,
        'p_target_player_id': targetPlayerId,
        'p_chips': chips,
        'p_client_action_id': clientActionId,
        'p_position_x': positionX,
        'p_position_y': positionY,
      },
    );
    final root = _requireMap(response, 'place_party_poll_bet_v1 response');
    final bet = PartyPollBet.fromJson(
      _requireMap(root['bet'], 'place_party_poll_bet_v1 response.bet'),
    );
    final snapshot = PartyPollSnapshot.fromJson(
      _requireMap(
        root['snapshot'],
        'place_party_poll_bet_v1 response.snapshot',
      ),
    );
    return PartyPollBetPlacement(bet: bet, snapshot: snapshot);
  }

  Future<PartyPollSnapshot> moveBet({
    required String roomId,
    required String betId,
    required String targetPlayerId,
    double? positionX,
    double? positionY,
  }) => _snapshotRpc('move_party_poll_bet_v1', {
    'p_room_id': roomId,
    'p_bet_id': betId,
    'p_target_player_id': targetPlayerId,
    'p_position_x': positionX,
    'p_position_y': positionY,
  });

  Future<PartyPollSnapshot> removeBet({
    required String roomId,
    required String betId,
  }) => _snapshotRpc('remove_party_poll_bet_v1', {
    'p_room_id': roomId,
    'p_bet_id': betId,
  });
  Future<PartyPollSnapshot> settleRound(String roomId) =>
      _snapshotRpc('settle_party_poll_round_v1', {'p_room_id': roomId});

  Future<Map<String, dynamic>> advanceRound(
    String roomId, {
    int bettingDurationSeconds = 30,
  }) async {
    final response = await _client.rpc(
      'advance_party_poll_round_v1',
      params: {
        'p_room_id': roomId,
        'p_betting_duration_seconds': bettingDurationSeconds,
      },
    );
    return _requireMap(response, 'advance_party_poll_round_v1 response');
  }

  Future<PartyPollSnapshot> _snapshotRpc(
    String function,
    Map<String, dynamic> params,
  ) async {
    final response = await _client.rpc(function, params: params);
    return PartyPollSnapshot.fromJson(
      _requireMap(response, '$function response'),
    );
  }

  Map<String, dynamic> _requireMap(Object? response, String context) {
    if (response == null) {
      throw StateError('$context was null.');
    }
    if (response is! Map) {
      throw StateError('$context must be a Map, got ${response.runtimeType}.');
    }
    return Map<String, dynamic>.from(response);
  }
}
