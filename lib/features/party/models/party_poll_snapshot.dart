import '../../room/models/room_model.dart';

enum PartyPollPhase {
  betting,
  reveal,
  finished;

  static PartyPollPhase fromJson(Object? value) {
    final name = value?.toString();
    return PartyPollPhase.values.firstWhere(
      (phase) => phase.name == name,
      orElse: () => PartyPollPhase.betting,
    );
  }
}

class PartyPollBet {
  final String id;
  final String? playerId;
  final String? targetPlayerId;
  final int chips;
  final String? clientActionId;
  final double? positionX;
  final double? positionY;

  const PartyPollBet({
    required this.id,
    required this.chips,
    this.playerId,
    this.targetPlayerId,
    this.clientActionId,
    this.positionX,
    this.positionY,
  });

  factory PartyPollBet.fromJson(Map<String, dynamic> json) {
    return PartyPollBet(
      id: _requiredString(json['id'], 'bet.id'),
      playerId: json['player_id'] as String?,
      targetPlayerId:
          (json['target_player_id'] ?? json['target_id']) as String?,
      chips: _requiredInt(json['chips'], 'bet.chips'),
      clientActionId: json['client_action_id'] as String?,
      positionX: (json['position_x'] as num?)?.toDouble(),
      positionY: (json['position_y'] as num?)?.toDouble(),
    );
  }
}

class PartyPollSnapshot {
  final Room? room;
  final int roundNumber;
  final PartyPollPhase phase;
  final DateTime? phaseEndsAt;
  final List<PartyPollBet> bets;
  final Map<String, int> scores;
  final int? proposedResult;
  final PartyPollRound? pollRound;
  final PartyPollMe? me;
  final List<PartyPollPlayer> players;
  final PartyPollQuestion? question;

  const PartyPollSnapshot({
    required this.roundNumber,
    required this.phase,
    required this.bets,
    required this.scores,
    this.room,
    this.phaseEndsAt,
    this.proposedResult,
    this.pollRound,
    this.me,
    this.players = const [],
    this.question,
  });

  factory PartyPollSnapshot.fromJson(Map<String, dynamic> json) {
    final round = json['round'] is Map
        ? Map<String, dynamic>.from(json['round'] as Map)
        : json;
    final rawScores = json['scores'] is Map
        ? Map<String, dynamic>.from(json['scores'] as Map)
        : const <String, dynamic>{};
    final rawBets = round['bets'] as List? ?? const [];
    final rawRoom = json['room'];
    // ignore: unused_local_variable`r`n    final parsedRound = PartyPollRound.fromJson(round);
    return PartyPollSnapshot(
      room: rawRoom is Map
          ? Room.fromJson(Map<String, dynamic>.from(rawRoom))
          : null,
      roundNumber:
          _asInt(
            round['round_number'] ?? round['number'] ?? json['current_round'],
          ) ??
          0,
      phase: PartyPollPhase.fromJson(round['phase'] ?? json['phase']),
      phaseEndsAt: _asDateTime(round['phase_ends_at'] ?? json['phase_ends_at']),
      bets: rawBets
          .whereType<Map>()
          .map((bet) => PartyPollBet.fromJson(Map<String, dynamic>.from(bet)))
          .toList(growable: false),
      scores: rawScores.map(
        (key, value) =>
            MapEntry(key.toString(), _requiredInt(value, 'scores.$key')),
      ),
      proposedResult: _asInt(
        round['proposed_result'] ?? json['proposed_result'],
      ),
    );
  }
}

String _requiredString(Object? value, String field) {
  if (value is String && value.isNotEmpty) return value;
  throw StateError('Invalid $field: expected a non-empty string.');
}

int _requiredInt(Object? value, String field) {
  if (value is num) return value.toInt();
  throw StateError('Invalid $field: expected a number.');
}

int? _asInt(Object? value) => value is num ? value.toInt() : null;

DateTime? _asDateTime(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;

class PartyPollPlayer {
  final String id;
  final String name;
  final int slotIndex;
  const PartyPollPlayer({
    required this.id,
    required this.name,
    this.slotIndex = 0,
  });
  factory PartyPollPlayer.fromJson(Map<String, dynamic> json) =>
      PartyPollPlayer(
        id: _requiredString(json['id'], 'player.id'),
        name: (json['name'] ?? json['display_name'] ?? '').toString(),
        slotIndex: _asInt(json['slot_index'] ?? json['slot']) ?? 0,
      );
}

class PartyPollQuestion {
  final String id;
  final String text;
  final String? category;
  const PartyPollQuestion({
    required this.id,
    required this.text,
    this.category,
  });
  factory PartyPollQuestion.fromJson(Map<String, dynamic> json) =>
      PartyPollQuestion(
        id: (json['id'] ?? json['question_id'] ?? '').toString(),
        text: (json['text'] ?? json['prompt'] ?? json['question'] ?? '')
            .toString(),
        category: json['category']?.toString(),
      );
}

class PartyPollMe {
  final String? playerId;
  final int score;
  final int availableChips;
  final int betTotal;
  const PartyPollMe({
    this.playerId,
    this.score = 0,
    this.availableChips = 0,
    this.betTotal = 0,
  });
  factory PartyPollMe.fromJson(Map<String, dynamic> json) => PartyPollMe(
    playerId: (json['player_id'] ?? json['id']) as String?,
    score: _asInt(json['score']) ?? 0,
    availableChips: _asInt(json['available_chips'] ?? json['chips']) ?? 0,
    betTotal: _asInt(json['bet_total'] ?? json['my_bet_total']) ?? 0,
  );
}

class PartyPollRound {
  final int number;
  final PartyPollPhase phase;
  final DateTime? phaseEndsAt;
  final PartyPollQuestion? question;
  final List<PartyPollPlayer> players;
  final List<PartyPollBet> bets;
  final String? winningPlayerId;
  final int? proposedResult;
  const PartyPollRound({
    required this.number,
    required this.phase,
    required this.players,
    required this.bets,
    this.phaseEndsAt,
    this.question,
    this.winningPlayerId,
    this.proposedResult,
  });
  factory PartyPollRound.fromJson(Map<String, dynamic> json) {
    final ps = json['players'] as List? ?? const [];
    final bs = json['bets'] as List? ?? const [];
    final q = json['question'];
    return PartyPollRound(
      number: _asInt(json['round_number'] ?? json['number']) ?? 0,
      phase: PartyPollPhase.fromJson(json['phase']),
      phaseEndsAt: _asDateTime(json['phase_ends_at']),
      question: q is Map
          ? PartyPollQuestion.fromJson(Map<String, dynamic>.from(q))
          : null,
      players: ps
          .whereType<Map>()
          .map((p) => PartyPollPlayer.fromJson(Map<String, dynamic>.from(p)))
          .toList(growable: false),
      bets: bs
          .whereType<Map>()
          .map((b) => PartyPollBet.fromJson(Map<String, dynamic>.from(b)))
          .toList(growable: false),
      winningPlayerId:
          (json['winning_player_id'] ?? json['winner_player_id']) as String?,
      proposedResult: _asInt(json['proposed_result']),
    );
  }
}
