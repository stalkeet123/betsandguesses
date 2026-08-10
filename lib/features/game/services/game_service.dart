import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/question_model.dart';
import '../models/guess_model.dart';
import '../models/bet_model.dart';
import '../../../core/constants/game_constants.dart';
import '../../room/models/room_model.dart';

/// Service for game logic: questions, guesses, bets, scoring
class GameService {
  final SupabaseClient _client;

  GameService(this._client);

  // ── Questions ──

  static const _guessSelectColumns =
      'id, room_id, round_number, player_id, question_id, value, is_winner';
  static const _betSelectColumns =
      'id, room_id, round_number, player_id, target_guess_id, slot_index, '
      'chips, payout_multiplier, position_x, position_y';

  List<String>? _cachedQuestionCategories;

  Future<void> prefetchQuestions() async {
    if (_cachedQuestionCategories != null) return;
    try {
      await getQuestionCategories();
    } catch (_) {
      // The lobby remains usable if optional category prefetch fails.
    }
  }

  Future<List<String>> getQuestionCategories() async {
    final cached = _cachedQuestionCategories;
    if (cached != null) return cached;
    final response = await _client.rpc('get_question_categories_v2');
    final categories = (response as List).map((value) => '$value').toList();
    _cachedQuestionCategories = categories;
    return categories;
  }

  Future<Question?> getQuestionForRoom(String roomId) async {
    final response = await _client.rpc(
      'get_current_question_v2',
      params: {'p_room_id': roomId},
    );
    if (response == null) return null;
    return Question.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<SecureGameStart> startGameSecure({
    required String roomId,
    required int durationSeconds,
  }) async {
    final response = await _client.rpc(
      'start_game_v2',
      params: {'p_room_id': roomId, 'p_duration_seconds': durationSeconds},
    );
    return SecureGameStart.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<SecureRoundQuestion?> claimNextQuestion({
    required String roomId,
    required int roundNumber,
    required int durationSeconds,
  }) async {
    final response = await _client.rpc(
      'claim_next_question_v2',
      params: {
        'p_room_id': roomId,
        'p_round_number': roundNumber,
        'p_duration_seconds': durationSeconds,
      },
    );
    if (response == null) return null;
    return SecureRoundQuestion.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  // ── Guesses ──

  /// Submit a guess
  Future<Guess> submitGuess({
    required String roomId,
    required int roundNumber,
    required String playerId,
    required String questionId,
    required int value,
  }) async {
    final response = await _client.rpc(
      'submit_guess_v2',
      params: {'p_room_id': roomId, 'p_value': value},
    );
    return Guess.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Get all guesses for a round
  Future<List<Guess>> getGuesses(String roomId, int roundNumber) async {
    final response = await _client
        .from('guesses')
        .select(_guessSelectColumns)
        .eq('room_id', roomId)
        .eq('round_number', roundNumber)
        .order('value');
    return (response as List).map((e) => Guess.fromJson(e)).toList();
  }

  /// Determine the winning guess (closest without going over)
  Guess? determineWinner(List<Guess> guesses, int correctAnswer) {
    final sorted = List<Guess>.from(guesses)
      ..sort((a, b) {
        final byValue = a.value.compareTo(b.value);
        if (byValue != 0) return byValue;
        return a.id.compareTo(b.id);
      });

    // Find closest without going over
    Guess? winner;
    for (final guess in sorted.reversed) {
      if (guess.value <= correctAnswer) {
        winner = guess;
        break;
      }
    }

    // If all guesses are above the answer, the "Smaller" slot wins (no guess wins)
    return winner;
  }

  int? determineWinningBetSlotIndex(List<Guess> guesses, int correctAnswer) {
    final boundaries = boardBoundaryValues(guesses);
    if (boundaries.length < GameConstants.maxGuessSlots) return null;

    if (correctAnswer < boundaries[0]) return 0;
    if (correctAnswer < boundaries[1]) return 1;
    if (correctAnswer <= boundaries[2]) return 2;
    if (correctAnswer <= boundaries[3]) return 3;
    return 4;
  }

  /// Four ascending boundary numbers used to create five betting ranges.
  List<int> boardBoundaryValues(List<Guess> guesses) {
    final values = guesses.map((guess) => guess.value).toSet().toList()..sort();

    if (values.isEmpty) return const [25, 50, 75, 100];
    if (values.length == GameConstants.maxGuessSlots) return values;

    if (values.length > GameConstants.maxGuessSlots) {
      return _selectSpacedSubset(values, GameConstants.maxGuessSlots);
    }
    if (values.length == 1) return _fallbackSpread(values);

    final boundaries = [...values];
    while (boundaries.length < GameConstants.maxGuessSlots) {
      final insertIndex = _widestBoundaryGapIndex(boundaries);
      final generated = _roundedMidpoint(
        boundaries[insertIndex],
        boundaries[insertIndex + 1],
      );
      boundaries.insert(insertIndex + 1, generated);
      boundaries.sort();
      if (boundaries.toSet().length != boundaries.length) {
        return _fallbackSpread(values);
      }
    }

    return boundaries;
  }

  List<int> _selectSpacedSubset(List<int> values, int count) {
    if (values.length <= count) return values;

    final minVal = values.first;
    final maxVal = values.last;
    final step = (maxVal - minVal) / (count - 1);

    final result = <int>[minVal];
    final candidates = values.sublist(1, values.length - 1);

    for (int i = 1; i < count - 1; i++) {
      if (candidates.isEmpty) break;
      final target = minVal + step * i;
      int bestCandidate = candidates.first;
      double minDiff = (bestCandidate - target).abs();
      for (final c in candidates) {
        final diff = (c - target).abs();
        if (diff < minDiff) {
          minDiff = diff;
          bestCandidate = c;
        }
      }
      result.add(bestCandidate);
      candidates.remove(bestCandidate);
    }

    result.add(maxVal);
    result.sort();
    return result;
  }

  int _widestBoundaryGapIndex(List<int> values) {
    if (values.length == 1) return -1;

    var widestIndex = 0;
    var widestGap = values[1] - values[0];
    for (var i = 1; i < values.length - 1; i++) {
      final gap = values[i + 1] - values[i];
      if (gap > widestGap) {
        widestGap = gap;
        widestIndex = i;
      }
    }
    return widestIndex;
  }

  int _roundedMidpoint(int low, int high) {
    final raw = (low + high) / 2;
    final step = _niceStep((high - low).abs());
    if (step <= 1) return raw.round();
    return (raw / step).round() * step;
  }

  int _niceStep(int range) {
    if (range <= 12) return 1;
    final magnitude = pow(10, range.toString().length - 2).toInt();
    for (final multiplier in const [1, 2, 5, 10]) {
      final step = magnitude * multiplier;
      if (range / step <= 8) return step;
    }
    return magnitude * 10;
  }

  List<int> _fallbackSpread(List<int> values) {
    final low = values.first;
    final high = values.last;
    if (values.length == 1) {
      final step = max(1, _niceStep(max(10, low.abs())));
      return [low, low + step, low + step * 2, low + step * 3];
    }

    final range = high - low;
    if (range < 3) return [low, low + 1, low + 2, low + 3];

    final step = max(1, (range / 3).round());
    final result = [low, low + step, low + step * 2, high];
    for (var i = 1; i < result.length; i++) {
      if (result[i] <= result[i - 1]) result[i] = result[i - 1] + 1;
    }
    return result;
  }

  Future<RoundSettlementResult> settleRound({
    required String roomId,
    required int roundNumber,
  }) async {
    final response = await _client.rpc(
      'settle_game_round_v2',
      params: {'p_room_id': roomId, 'p_round_number': roundNumber},
    );
    return RoundSettlementResult.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  // ── Bets ──

  /// Place a bet
  Future<Bet> placeBet({
    required String roomId,
    required int roundNumber,
    required String playerId,
    required String? targetGuessId,
    required int slotIndex,
    required int chips,
    required String clientActionId,
    double? positionX,
    double? positionY,
  }) async {
    final response = await _client.rpc(
      'place_bet_v2',
      params: {
        'p_room_id': roomId,
        'p_slot_index': slotIndex,
        'p_chips': chips,
        'p_client_action_id': clientActionId,
        'p_position_x': positionX,
        'p_position_y': positionY,
      },
    );
    if (response == null) throw const BettingWindowClosedException();
    return Bet.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Move an existing bet without creating duplicate bet rows.
  Future<Bet> updateBet({
    required String betId,
    required String? targetGuessId,
    required int slotIndex,
    double? positionX,
    double? positionY,
  }) async {
    final response = await _client.rpc(
      'move_bet_v2',
      params: {
        'p_bet_id': betId,
        'p_slot_index': slotIndex,
        'p_position_x': positionX,
        'p_position_y': positionY,
      },
    );
    if (response == null) throw const BettingWindowClosedException();
    return Bet.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Get all bets for a round
  Future<List<Bet>> getBets(String roomId, int roundNumber) async {
    final response = await _client
        .from('bets')
        .select(_betSelectColumns)
        .eq('room_id', roomId)
        .eq('round_number', roundNumber);
    return (response as List).map((e) => Bet.fromJson(e)).toList();
  }

  /// Remove a bet
  Future<void> removeBet(String betId) async {
    await _client.rpc('remove_bet_v2', params: {'p_bet_id': betId});
  }

  // ── Scoring ──

  /// Calculate payouts for a round
  /// Returns a map of playerId -> points earned this round
  Map<String, int> calculatePayouts({
    required List<Guess> guesses,
    required List<Bet> bets,
    required int correctAnswer,
  }) {
    final payouts = <String, int>{};

    final winningSlotIndex = determineWinningBetSlotIndex(
      guesses,
      correctAnswer,
    );

    // Calculate bet payouts
    for (final bet in bets) {
      if (bet.slotIndex == winningSlotIndex) {
        final payout = bet.chips * bet.payoutMultiplier;
        payouts[bet.playerId] = (payouts[bet.playerId] ?? 0) + payout;
      }
    }

    return payouts;
  }

  // ── Used Questions ──
}

/// A late write is a normal client/server timer race, not a malformed bet.
/// The RPC returns null in that case so callers can recover without leaving an
/// optimistic chip stranded in local state.
class BettingWindowClosedException implements Exception {
  const BettingWindowClosedException();
}

class SecureGameStart {
  final Room room;
  final Question question;
  final Map<String, int> scores;

  const SecureGameStart({
    required this.room,
    required this.question,
    required this.scores,
  });

  factory SecureGameStart.fromJson(Map<String, dynamic> json) {
    return SecureGameStart(
      room: Room.fromJson(Map<String, dynamic>.from(json['room'] as Map)),
      question: Question.fromJson(
        Map<String, dynamic>.from(json['question'] as Map),
      ),
      scores: _intMap(json['scores']),
    );
  }
}

class SecureRoundQuestion {
  final Room room;
  final Question question;

  const SecureRoundQuestion({required this.room, required this.question});

  factory SecureRoundQuestion.fromJson(Map<String, dynamic> json) {
    return SecureRoundQuestion(
      room: Room.fromJson(Map<String, dynamic>.from(json['room'] as Map)),
      question: Question.fromJson(
        Map<String, dynamic>.from(json['question'] as Map),
      ),
    );
  }
}

class RoundSettlementResult {
  final bool didSettle;
  final int stateVersion;
  final int answer;
  final String? winningGuessId;
  final int winningSlotIndex;
  final Map<String, int> scores;
  final Map<String, int> payouts;
  final DateTime? phaseEndsAt;

  const RoundSettlementResult({
    required this.didSettle,
    required this.stateVersion,
    required this.answer,
    required this.winningGuessId,
    required this.winningSlotIndex,
    required this.scores,
    required this.payouts,
    required this.phaseEndsAt,
  });

  factory RoundSettlementResult.fromJson(Map<String, dynamic> json) {
    return RoundSettlementResult(
      didSettle: json['status'] == 'settled',
      stateVersion: (json['state_version'] as num?)?.toInt() ?? 0,
      answer: (json['answer'] as num).toInt(),
      winningGuessId: json['winning_guess_id'] as String?,
      winningSlotIndex: (json['winning_slot_index'] as num?)?.toInt() ?? 0,
      scores: _intMap(json['scores']),
      payouts: _intMap(json['payouts']),
      phaseEndsAt: json['phase_ends_at'] == null
          ? null
          : DateTime.tryParse('${json['phase_ends_at']}')?.toUtc(),
    );
  }
}

Map<String, int> _intMap(Object? value) {
  if (value is! Map) return <String, int>{};
  return value.map(
    (key, item) =>
        MapEntry('$key', item is int ? item : int.tryParse('$item') ?? 0),
  );
}
