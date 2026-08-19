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

  const PartyPollSnapshot({
    required this.roundNumber,
    required this.phase,
    required this.bets,
    required this.scores,
    this.room,
    this.phaseEndsAt,
    this.proposedResult,
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
