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
    // Sort ascending
    final sorted = List<Guess>.from(guesses)
      ..sort((a, b) => a.value.compareTo(b.value));

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
      return await _client.from('bets').insert(fallbackPayload).select().single();
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
    required Guess? winningGuess,
  }) {
    final payouts = <String, int>{};

    // Find the winning slot index
    int? winningSlotIndex;
    if (winningGuess == null) {
      // All guesses were too high → slot 0 ("Smaller") wins
      winningSlotIndex = 0;
    } else {
      final sortedGuesses = List<Guess>.from(guesses)
        ..sort((a, b) => a.value.compareTo(b.value));
      final idx = sortedGuesses.indexWhere((g) => g.id == winningGuess.id);
      if (idx >= 0) {
        // Slot mapping: slot 0 = "Smaller", slots 1-N = guesses, last slot = "Larger"
        winningSlotIndex = idx + 1; // +1 because slot 0 is "Smaller"
      }
    }

    // Calculate bet payouts
    for (final bet in bets) {
      if (bet.slotIndex == winningSlotIndex) {
        final payout = bet.chips * bet.payoutMultiplier;
        payouts[bet.playerId] = (payouts[bet.playerId] ?? 0) + payout;
      }
    }

    // Guess bonus: the player who wrote the winning guess gets bonus
    if (winningGuess != null) {
      payouts[winningGuess.playerId] =
          (payouts[winningGuess.playerId] ?? 0) + GameConstants.guessBonus;
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
