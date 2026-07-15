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

  static const _questionSelectColumns =
      'id, text_tr, text_en, answer, answer_unit, category, difficulty, source';
  static const _questionCandidateSelectColumns = 'id, category';
  static const _guessSelectColumns =
      'id, room_id, round_number, player_id, question_id, value, is_winner';
  static const _betSelectColumns =
      'id, room_id, round_number, player_id, target_guess_id, slot_index, '
      'chips, payout_multiplier';

  List<_QuestionCandidate>? _cachedQuestionCandidates;

  /// Fetch lightweight question candidates once and cache them.
  Future<void> prefetchQuestions() async {
    if (_cachedQuestionCandidates != null) return;
    try {
      final response = await _client
          .from('questions')
          .select(_questionCandidateSelectColumns);
      _cachedQuestionCandidates = (response as List)
          .map((e) => _QuestionCandidate.fromJson(e))
          .toList();
    } catch (e) {
      // Ignore, we will try again
    }
  }

  /// Get a random question not yet used in this room
  Future<Question?> getRandomQuestion(
    String roomId,
    List<String> usedQuestionIds, {
    String? category,
  }) async {
    await prefetchQuestions();

    if (_cachedQuestionCandidates == null ||
        _cachedQuestionCandidates!.isEmpty) {
      // Fallback: fetch candidates directly if cache failed or is empty.
      final response = await _client
          .from('questions')
          .select(_questionCandidateSelectColumns);
      _cachedQuestionCandidates = (response as List)
          .map((e) => _QuestionCandidate.fromJson(e))
          .toList();
      if (_cachedQuestionCandidates!.isEmpty) return null;
    }

    final normalizedCategory = category?.trim();
    final useCategory =
        normalizedCategory != null &&
        normalizedCategory.isNotEmpty &&
        normalizedCategory != GameConstants.defaultCategory;

    final usedIds = usedQuestionIds.toSet();
    var available = _cachedQuestionCandidates!
        .where((q) => !usedIds.contains(q.id))
        .toList();

    if (useCategory) {
      final categoryQuestions = available
          .where((q) => q.category?.trim() == normalizedCategory)
          .toList();
      if (categoryQuestions.isNotEmpty) {
        available = categoryQuestions;
      }
    }

    if (available.isEmpty) return null;
    available.shuffle(Random());
    for (final candidate in available) {
      final question = await getQuestionById(candidate.id);
      if (question != null) return question;
    }
    return null;
  }

  Future<List<String>> getQuestionCategories() async {
    await prefetchQuestions();
    if (_cachedQuestionCandidates == null ||
        _cachedQuestionCandidates!.isEmpty) {
      return [];
    }

    final categories =
        _cachedQuestionCandidates!
            .map((q) => q.category?.trim())
            .whereType<String>()
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return categories;
  }

  Future<Question?> getQuestionById(String questionId) async {
    final response = await _client
        .from('questions')
        .select(_questionSelectColumns)
        .eq('id', questionId)
        .maybeSingle();
    if (response == null) return null;
    return Question.fromJson(response);
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
    try {
      final response = await _client
          .from('guesses')
          .insert({
            'room_id': roomId,
            'round_number': roundNumber,
            'player_id': playerId,
            'question_id': questionId,
            'value': value,
          })
          .select(_guessSelectColumns)
          .single();
      return Guess.fromJson(response);
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      final existing = await _client
          .from('guesses')
          .select(_guessSelectColumns)
          .eq('room_id', roomId)
          .eq('round_number', roundNumber)
          .eq('player_id', playerId)
          .maybeSingle();
      if (existing == null) rethrow;
      return Guess.fromJson(existing);
    }
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

  /// Mark the winning guess in DB
  Future<void> markWinner(String guessId) async {
    await _client.from('guesses').update({'is_winner': true}).eq('id', guessId);
  }

  /// Settles a round in one Postgres transaction when the v1 RPC is installed.
  /// Returns null only when the migration is not installed, allowing old and
  /// new deployments to coexist during rollout.
  Future<RoundSettlementResult?> settleRound({
    required String roomId,
    required int roundNumber,
    required String? winningGuessId,
    required int winningSlotIndex,
    required Map<String, int> scores,
  }) async {
    try {
      final response = await _client.rpc(
        'settle_game_round_v1',
        params: {
          'p_room_id': roomId,
          'p_round_number': roundNumber,
          'p_winning_guess_id': winningGuessId,
          'p_winning_slot_index': winningSlotIndex,
          'p_scores': scores,
        },
      );
      return RoundSettlementResult.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST202' || error.code == '42883') return null;
      rethrow;
    }
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
      'client_action_id': clientActionId,
    };

    final response = await _client
        .from('bets')
        .insert(payload)
        .select(_betSelectColumns)
        .single();
    return Bet.fromJson(response);
  }

  /// Move an existing bet without creating duplicate bet rows.
  Future<Bet> updateBet({
    required String betId,
    required String? targetGuessId,
    required int slotIndex,
  }) async {
    final multiplier = GameConstants.boardOdds[slotIndex];
    final payload = {
      'target_guess_id': targetGuessId,
      'slot_index': slotIndex,
      'payout_multiplier': multiplier,
    };

    final response = await _client
        .from('bets')
        .update(payload)
        .eq('id', betId)
        .select(_betSelectColumns)
        .single();
    return Bet.fromJson(response);
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

  Future<void> clearRoomGameData(String roomId) async {
    await _client.from('bets').delete().eq('room_id', roomId);
    await _client.from('guesses').delete().eq('room_id', roomId);
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

class _QuestionCandidate {
  final String id;
  final String? category;

  const _QuestionCandidate({required this.id, this.category});

  factory _QuestionCandidate.fromJson(Map<String, dynamic> json) {
    return _QuestionCandidate(
      id: json['id'] as String,
      category: json['category'] as String?,
    );
  }
}

class RoundSettlementResult {
  final bool didSettle;
  final int stateVersion;
  final String? winningGuessId;
  final int winningSlotIndex;
  final Map<String, int> scores;

  const RoundSettlementResult({
    required this.didSettle,
    required this.stateVersion,
    required this.winningGuessId,
    required this.winningSlotIndex,
    required this.scores,
  });

  factory RoundSettlementResult.fromJson(Map<String, dynamic> json) {
    final rawScores = json['scores'];
    final scores = rawScores is Map
        ? rawScores.map(
            (key, value) =>
                MapEntry('$key', value is int ? value : int.parse('$value')),
          )
        : <String, int>{};

    return RoundSettlementResult(
      didSettle: json['status'] == 'settled',
      stateVersion: (json['state_version'] as num?)?.toInt() ?? 0,
      winningGuessId: json['winning_guess_id'] as String?,
      winningSlotIndex: (json['winning_slot_index'] as num?)?.toInt() ?? 0,
      scores: scores,
    );
  }
}
