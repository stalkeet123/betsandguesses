import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/question_model.dart';
import '../models/guess_model.dart';
import '../models/bet_model.dart';
import '../../../core/constants/game_constants.dart';

/// Service for game logic: questions, guesses, bets, scoring
class GameService {
  final SupabaseClient _client;

  GameService(this._client);

  // ── Questions ──

  List<Question>? _cachedQuestions;

  /// Fetch all questions once and cache them
  Future<void> prefetchQuestions() async {
    if (_cachedQuestions != null) return;
    try {
      final response = await _client.from('questions').select();
      _cachedQuestions = (response as List)
          .map((e) => Question.fromJson(e))
          .toList();
    } catch (e) {
      // Ignore, we will try again
    }
  }

  /// Get a random question not yet used in this room
  Future<Question?> getRandomQuestion(
    String roomId,
    List<String> usedQuestionIds,
  ) async {
    await prefetchQuestions();

    if (_cachedQuestions == null || _cachedQuestions!.isEmpty) {
      // Fallback: fetch directly if cache failed or is empty
      var query = _client.from('questions').select();
      final response = await query;
      _cachedQuestions = (response as List)
          .map((e) => Question.fromJson(e))
          .toList();
      if (_cachedQuestions!.isEmpty) return null;
    }

    final available = _cachedQuestions!
        .where((q) => !usedQuestionIds.contains(q.id))
        .toList();

    if (available.isEmpty) return null;
    available.shuffle(Random());
    return available.first;
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
    final response = await _client
        .from('guesses')
        .insert({
          'room_id': roomId,
          'round_number': roundNumber,
          'player_id': playerId,
          'question_id': questionId,
          'value': value,
        })
        .select()
        .single();
    return Guess.fromJson(response);
  }

  /// Get all guesses for a round
  Future<List<Guess>> getGuesses(String roomId, int roundNumber) async {
    final response = await _client
        .from('guesses')
        .select()
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

    if (values.isEmpty) return const [];
    if (values.length >= GameConstants.maxGuessSlots) {
      return _selectBalancedValues(values);
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

  List<int> _selectBalancedValues(List<int> values) {
    if (values.length == GameConstants.maxGuessSlots) return values;

    if (values.length == GameConstants.maxGuessSlots + 1) {
      final lowGap = values[1] - values[0];
      final highGap = values[values.length - 1] - values[values.length - 2];
      if (highGap > lowGap) {
        return values.take(GameConstants.maxGuessSlots).toList();
      }
      return values.skip(1).toList();
    }

    final last = values.length - 1;
    final selectedIndices = const [0.2, 0.4, 0.6, 0.8]
        .map((percentile) => (last * percentile).round().clamp(1, last - 1))
        .toSet()
        .toList();

    selectedIndices.sort();
    return selectedIndices
        .take(GameConstants.maxGuessSlots)
        .map((index) => values[index])
        .toList();
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

  /// Mark the winning guess in DB
  Future<void> markWinner(String guessId) async {
    await _client.from('guesses').update({'is_winner': true}).eq('id', guessId);
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
    double? positionX,
    double? positionY,
  }) async {
    final multiplier = GameConstants.boardOdds[slotIndex];
    final payload = {
      'room_id': roomId,
      'round_number': roundNumber,
      'player_id': playerId,
      'target_guess_id': targetGuessId,
      'slot_index': slotIndex,
      'chips': chips,
      'payout_multiplier': multiplier,
      if (positionX != null) 'position_x': positionX,
      if (positionY != null) 'position_y': positionY,
    };

    final response = await _insertBetWithPositionFallback(payload);
    return Bet.fromJson(response);
  }

  /// Move an existing bet without creating duplicate bet rows.
  Future<Bet> updateBet({
    required String betId,
    required String? targetGuessId,
    required int slotIndex,
    required double? positionX,
    required double? positionY,
  }) async {
    final multiplier = GameConstants.boardOdds[slotIndex];
    final payload = {
      'target_guess_id': targetGuessId,
      'slot_index': slotIndex,
      'payout_multiplier': multiplier,
      'position_x': positionX,
      'position_y': positionY,
    };

    final response = await _updateBetWithPositionFallback(betId, payload);
    return Bet.fromJson(response);
  }

  Future<Map<String, dynamic>> _insertBetWithPositionFallback(
    Map<String, dynamic> payload,
  ) async {
    try {
      return await _client.from('bets').insert(payload).select().single();
    } on PostgrestException catch (error) {
      if (!_isMissingPositionColumn(error)) rethrow;
      final fallbackPayload = Map<String, dynamic>.from(payload)
        ..remove('position_x')
        ..remove('position_y');
      return await _client
          .from('bets')
          .insert(fallbackPayload)
          .select()
          .single();
    }
  }

  Future<Map<String, dynamic>> _updateBetWithPositionFallback(
    String betId,
    Map<String, dynamic> payload,
  ) async {
    try {
      return await _client
          .from('bets')
          .update(payload)
          .eq('id', betId)
          .select()
          .single();
    } on PostgrestException catch (error) {
      if (!_isMissingPositionColumn(error)) rethrow;
      final fallbackPayload = Map<String, dynamic>.from(payload)
        ..remove('position_x')
        ..remove('position_y');
      return await _client
          .from('bets')
          .update(fallbackPayload)
          .eq('id', betId)
          .select()
          .single();
    }
  }

  bool _isMissingPositionColumn(PostgrestException error) {
    final message = error.message.toLowerCase();
    return message.contains('position_x') || message.contains('position_y');
  }

  /// Get all bets for a round
  Future<List<Bet>> getBets(String roomId, int roundNumber) async {
    final response = await _client
        .from('bets')
        .select()
        .eq('room_id', roomId)
        .eq('round_number', roundNumber);
    return (response as List).map((e) => Bet.fromJson(e)).toList();
  }

  /// Remove a bet
  Future<void> removeBet(String betId) async {
    await _client.from('bets').delete().eq('id', betId);
  }

  /// Remove all bets for a player in a round
  Future<void> removePlayerBets(
    String roomId,
    int roundNumber,
    String playerId,
  ) async {
    await _client
        .from('bets')
        .delete()
        .eq('room_id', roomId)
        .eq('round_number', roundNumber)
        .eq('player_id', playerId);
  }

  /// Remove all bets for a player on a specific slot in a round
  Future<void> removePlayerBetForSlot(
    String roomId,
    int roundNumber,
    String playerId,
    int slotIndex,
  ) async {
    await _client
        .from('bets')
        .delete()
        .eq('room_id', roomId)
        .eq('round_number', roundNumber)
        .eq('player_id', playerId)
        .eq('slot_index', slotIndex);
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

  /// Get question IDs already used in this room
  Future<List<String>> getUsedQuestionIds(String roomId) async {
    final response = await _client
        .from('guesses')
        .select('question_id')
        .eq('room_id', roomId);
    final ids = (response as List)
        .map((e) => e['question_id'] as String?)
        .where((id) => id != null)
        .cast<String>()
        .toSet()
        .toList();
    return ids;
  }
}
