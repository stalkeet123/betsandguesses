import '../../room/models/room_model.dart';

enum PartyPollPhase {
  betting,
  reveal;

  static PartyPollPhase fromString(String value) {
    switch (value) {
      case 'betting':
        return PartyPollPhase.betting;
      case 'reveal':
        return PartyPollPhase.reveal;
      default:
        throw StateError('Unknown PartyPollPhase: $value');
    }
  }
}

class PartyPollPlayer {
  final int slotIndex;
  final String id;
  final String name;
  final String? avatarColor;
  const PartyPollPlayer({
    required this.slotIndex,
    required this.id,
    required this.name,
    this.avatarColor,
  });
  factory PartyPollPlayer.fromJson(Map<String, dynamic> json) =>
      PartyPollPlayer(
        slotIndex: _requireInt(
          json['slot_index'],
          'PartyPollPlayer.slot_index',
        ),
        id: _requireString(json['id'], 'PartyPollPlayer.id'),
        name: _requireString(json['name'], 'PartyPollPlayer.name'),
        avatarColor: _optionalString(
          json['avatar_color'],
          'PartyPollPlayer.avatar_color',
        ),
      );
}

class PartyPollQuestion {
  final String id;
  final String text;
  final String rules;
  const PartyPollQuestion({
    required this.id,
    required this.text,
    required this.rules,
  });
  factory PartyPollQuestion.fromJson(Map<String, dynamic> json) =>
      PartyPollQuestion(
        id: _requireString(json['id'], 'PartyPollQuestion.id'),
        text: _requireString(json['text'], 'PartyPollQuestion.text'),
        rules: _requireString(json['rules'], 'PartyPollQuestion.rules'),
      );
}

class PartyPollBet {
  final String id;
  final int roundNumber;
  final String? playerId;
  final String targetPlayerId;
  final int chips;
  final String? clientActionId;
  final double? positionX;
  final double? positionY;
  final bool? won;
  const PartyPollBet({
    required this.id,
    required this.roundNumber,
    required this.targetPlayerId,
    required this.chips,
    this.playerId,
    this.clientActionId,
    this.positionX,
    this.positionY,
    this.won,
  });
  factory PartyPollBet.fromJson(Map<String, dynamic> json) => PartyPollBet(
    id: _requireString(json['id'], 'PartyPollBet.id'),
    roundNumber: _requireInt(json['round_number'], 'PartyPollBet.round_number'),
    playerId: _optionalString(json['player_id'], 'PartyPollBet.player_id'),
    targetPlayerId: _requireString(
      json['target_player_id'],
      'PartyPollBet.target_player_id',
    ),
    chips: _requireInt(json['chips'], 'PartyPollBet.chips'),
    clientActionId: _optionalString(
      json['client_action_id'],
      'PartyPollBet.client_action_id',
    ),
    positionX: _optionalDouble(json['position_x'], 'PartyPollBet.position_x'),
    positionY: _optionalDouble(json['position_y'], 'PartyPollBet.position_y'),
    won: _optionalBool(json['won'], 'PartyPollBet.won'),
  );
}

class PartyPollRound {
  final int number;
  final PartyPollPhase phase;
  final DateTime phaseStartedAt;
  final DateTime? phaseEndsAt;
  final PartyPollQuestion question;
  final List<PartyPollPlayer> players;
  final List<PartyPollBet> bets;
  final List<String> winningPlayerIds;
  const PartyPollRound({
    required this.number,
    required this.phase,
    required this.phaseStartedAt,
    required this.question,
    required this.players,
    required this.bets,
    required this.winningPlayerIds,
    this.phaseEndsAt,
  });
  factory PartyPollRound.fromJson(Map<String, dynamic> json) {
    final rawWinningPlayerIds = json['winning_player_ids'];
    return PartyPollRound(
      number: _requireInt(json['number'], 'PartyPollRound.number'),
      phase: PartyPollPhase.fromString(
        _requireString(json['phase'], 'PartyPollRound.phase'),
      ),
      phaseStartedAt: _requireDateTime(
        json['phase_started_at'],
        'PartyPollRound.phase_started_at',
      ),
      phaseEndsAt: _optionalDateTime(
        json['phase_ends_at'],
        'PartyPollRound.phase_ends_at',
      ),
      question: PartyPollQuestion.fromJson(
        _requireMap(json['question'], 'PartyPollRound.question'),
      ),
      players: _requireList(json['players'], 'PartyPollRound.players')
          .map(
            (value) => PartyPollPlayer.fromJson(
              _requireMap(value, 'PartyPollRound.players item'),
            ),
          )
          .toList(growable: false),
      bets: _requireList(json['bets'], 'PartyPollRound.bets')
          .map(
            (value) => PartyPollBet.fromJson(
              _requireMap(value, 'PartyPollRound.bets item'),
            ),
          )
          .toList(growable: false),
      winningPlayerIds: rawWinningPlayerIds == null
          ? const []
          : _requireList(
                  rawWinningPlayerIds,
                  'PartyPollRound.winning_player_ids',
                )
                .map(
                  (value) => _requireString(
                    value,
                    'PartyPollRound.winning_player_ids item',
                  ),
                )
                .toList(growable: false),
    );
  }
}

class PartyPollMe {
  final String playerId;
  final int score;
  final int betLimit;
  final int betTotal;
  final int availableChips;
  const PartyPollMe({
    required this.playerId,
    required this.score,
    required this.betLimit,
    required this.betTotal,
    required this.availableChips,
  });
  factory PartyPollMe.fromJson(Map<String, dynamic> json) => PartyPollMe(
    playerId: _requireString(json['player_id'], 'PartyPollMe.player_id'),
    score: _requireInt(json['score'], 'PartyPollMe.score'),
    betLimit: _requireInt(json['bet_limit'], 'PartyPollMe.bet_limit'),
    betTotal: _requireInt(json['bet_total'], 'PartyPollMe.bet_total'),
    availableChips: _requireInt(
      json['available_chips'],
      'PartyPollMe.available_chips',
    ),
  );
}

class PartyPollSnapshot {
  final Room room;
  final String status;
  final int stateVersion;
  final PartyPollRound round;
  final Map<String, int> scores;
  final PartyPollMe me;
  const PartyPollSnapshot({
    required this.room,
    required this.status,
    required this.stateVersion,
    required this.round,
    required this.scores,
    required this.me,
  });
  factory PartyPollSnapshot.fromJson(Map<String, dynamic> json) {
    final rawScores = _requireMap(json['scores'], 'PartyPollSnapshot.scores');
    return PartyPollSnapshot(
      room: Room.fromJson(_requireMap(json['room'], 'PartyPollSnapshot.room')),
      status: _requireString(json['status'], 'PartyPollSnapshot.status'),
      stateVersion: _requireInt(
        json['state_version'],
        'PartyPollSnapshot.state_version',
      ),
      round: PartyPollRound.fromJson(
        _requireMap(json['round'], 'PartyPollSnapshot.round'),
      ),
      scores: rawScores.map(
        (key, value) =>
            MapEntry(key, _requireInt(value, 'PartyPollSnapshot.scores.$key')),
      ),
      me: PartyPollMe.fromJson(_requireMap(json['me'], 'PartyPollSnapshot.me')),
    );
  }
}

Map<String, dynamic> _requireMap(Object? value, String field) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  throw StateError('Invalid $field: expected map.');
}

List<dynamic> _requireList(Object? value, String field) {
  if (value is List) {
    return List<dynamic>.from(value);
  }
  throw StateError('Invalid $field: expected list.');
}

String _requireString(Object? value, String field) {
  if (value is String && value.isNotEmpty) return value;
  throw StateError('Invalid $field: expected non-empty string.');
}

String? _optionalString(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  throw StateError('Invalid $field: expected string or null.');
}

int _requireInt(Object? value, String field) {
  if (value is int) {
    return value;
  }
  throw StateError('Invalid $field: expected integer.');
}

double? _optionalDouble(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is num) return value.toDouble();
  throw StateError('Invalid $field: expected number or null.');
}

bool? _optionalBool(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is bool) return value;
  throw StateError('Invalid $field: expected boolean or null.');
}

DateTime _requireDateTime(Object? value, String field) {
  final parsed = _optionalDateTime(value, field);
  if (parsed != null) return parsed;
  throw StateError('Invalid $field: expected ISO-8601 date string.');
}

DateTime? _optionalDateTime(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw StateError('Invalid $field: expected ISO-8601 date string or null.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw StateError('Invalid $field: expected ISO-8601 date string.');
  }
  return parsed.toUtc();
}
