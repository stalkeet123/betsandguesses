import '../../../core/constants/game_constants.dart';
import '../../room/models/room_model.dart';

enum PartyRoundPhase {
  guessing,
  betting,
  ready,
  action,
  resultEntry,
  resultConfirm,
  reveal;

  static PartyRoundPhase fromString(String value) {
    return PartyRoundPhase.values.firstWhere(
      (phase) => phase.name == value,
      orElse: () => PartyRoundPhase.guessing,
    );
  }
}

enum PartyChallengeType {
  count,
  binary, // Legacy-only: disabled for newly selected rounds.
  attempt,
  choice,
  versus,
  showdown,
  poll;

  static PartyChallengeType fromString(String? value) {
    return PartyChallengeType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => PartyChallengeType.count,
    );
  }
}

enum PartyChallengeCategory {
  personality,
  attempt,
  count,
  general,
  verbal,
  precision,
  physical,
  dare,
  skill,
  social,
  versus,
  showdown,
  poll;

  static PartyChallengeCategory fromString(String? value) {
    return PartyChallengeCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => PartyChallengeCategory.general,
    );
  }
}

enum PartyResultDirection {
  higher,
  lower,
  binary;

  static PartyResultDirection fromString(String? value) {
    return PartyResultDirection.values.firstWhere(
      (direction) => direction.name == value,
      orElse: () => PartyResultDirection.higher,
    );
  }
}

class PartyParticipant {
  final String id;
  final String name;
  final String? avatarColor;

  const PartyParticipant({
    required this.id,
    required this.name,
    this.avatarColor,
  });

  factory PartyParticipant.fromJson(Map<String, dynamic> json) {
    return PartyParticipant(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarColor: json['avatar_color'] as String?,
    );
  }
}

class PartyChallenge {
  final String id;
  final String text;
  final String rules;
  final String answerUnit;
  final int durationSeconds;
  final int maxResult;
  final List<int> betBoundaries;
  final PartyChallengeType type;
  final PartyChallengeCategory category;
  final PartyResultDirection resultDirection;
  final List<String> requiredItems;
  final String? optionA;
  final String? optionB;
  final int performerSuccessBonus;

  const PartyChallenge({
    required this.id,
    required this.text,
    required this.rules,
    required this.answerUnit,
    required this.durationSeconds,
    required this.maxResult,
    required this.betBoundaries,
    required this.type,
    this.category = PartyChallengeCategory.general,
    this.resultDirection = PartyResultDirection.higher,
    this.requiredItems = const [],
    this.optionA,
    this.optionB,
    required this.performerSuccessBonus,
  });

  bool get isBinary => type == PartyChallengeType.binary;
  bool get isAttempt => type == PartyChallengeType.attempt;
  bool get isChoice => type == PartyChallengeType.choice;
  bool get isVersus => type == PartyChallengeType.versus;
  bool get isShowdown => type == PartyChallengeType.showdown;
  bool get isPoll => type == PartyChallengeType.poll;
  bool get isPlayerSlotType => isVersus || isShowdown || isPoll;
  bool get usesTwoOptionBoard => isBinary || isChoice || isVersus;

  String? choiceLabel(int value) => switch (value) {
    0 => optionA,
    1 => optionB,
    _ => null,
  };

  int? betSlotForResult(int result) {
    if (usesTwoOptionBoard) {
      return (result == 0 || result == 1) ? result : null;
    }
    if (isShowdown || isPoll) {
      return (result >= 0 && result < 8) ? result : null;
    }
    if (!isAttempt) return null;
    return switch (result) {
      0 => 4,
      1 => 0,
      2 => 1,
      3 => 2,
      4 || 5 => 3,
      _ => null,
    };
  }

  factory PartyChallenge.fromJson(Map<String, dynamic> json) {
    final type = PartyChallengeType.fromString(
      json['challenge_type'] as String?,
    );
    final rawBoundaries = json['bet_boundaries'] as List?;
    return PartyChallenge(
      id: json['id'] as String,
      text: json['text'] as String,
      rules: json['rules'] as String,
      answerUnit: json['answer_unit'] as String,
      durationSeconds: (json['duration_seconds'] as num).toInt(),
      maxResult: (json['max_result'] as num).toInt(),
      betBoundaries:
          (rawBoundaries ??
                  (type == PartyChallengeType.count
                      ? const [25, 50, 75, 100]
                      : const []))
              .map((value) => (value as num).toInt())
              .toList(growable: false),
      type: type,
      category: PartyChallengeCategory.fromString(json['category'] as String?),
      resultDirection: PartyResultDirection.fromString(
        json['result_direction'] as String? ??
            switch (type) {
              PartyChallengeType.binary ||
              PartyChallengeType.choice ||
              PartyChallengeType.versus => 'binary',
              PartyChallengeType.attempt => 'lower',
              PartyChallengeType.count ||
              PartyChallengeType.showdown => 'higher',
            },
      ),
      requiredItems: (json['required_items'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      optionA: json['option_a'] as String?,
      optionB: json['option_b'] as String?,
      performerSuccessBonus:
          (json['performer_success_bonus'] as num?)?.toInt() ?? 3,
    );
  }
}

class PartyGuessSnapshot {
  final String id;
  final int value;
  final bool isPerformerPrediction;
  final String? playerId;
  final String? playerName;
  final String? playerColor;

  const PartyGuessSnapshot({
    required this.id,
    required this.value,
    required this.isPerformerPrediction,
    this.playerId,
    this.playerName,
    this.playerColor,
  });

  factory PartyGuessSnapshot.fromJson(Map<String, dynamic> json) {
    return PartyGuessSnapshot(
      id: json['id'] as String,
      value: (json['value'] as num).toInt(),
      isPerformerPrediction: json['is_performer_prediction'] as bool? ?? false,
      playerId: json['player_id'] as String?,
      playerName: json['player_name'] as String?,
      playerColor: json['player_color'] as String?,
    );
  }
}

class PartyBetSnapshot {
  final String id;
  final int slotIndex;
  final int chips;
  final String? playerId;
  final double? positionX;
  final double? positionY;

  const PartyBetSnapshot({
    required this.id,
    required this.slotIndex,
    required this.chips,
    this.playerId,
    this.positionX,
    this.positionY,
  });

  factory PartyBetSnapshot.fromJson(Map<String, dynamic> json) {
    return PartyBetSnapshot(
      id: json['id'] as String,
      slotIndex: (json['slot_index'] as num).toInt(),
      chips: (json['chips'] as num).toInt(),
      playerId: json['player_id'] as String?,
      positionX: (json['position_x'] as num?)?.toDouble(),
      positionY: (json['position_y'] as num?)?.toDouble(),
    );
  }
}

class PartyRoundSnapshot {
  final int number;
  final PartyRoundPhase phase;
  final DateTime phaseStartedAt;
  final DateTime? phaseEndsAt;
  final PartyParticipant performer;
  final PartyParticipant? witness;
  final PartyChallenge challenge;
  final int submittedGuessCount;
  final bool performerReady;
  final PartyGuessSnapshot? ownGuess;
  final List<PartyGuessSnapshot> guesses;
  final List<PartyBetSnapshot> bets;
  final int? proposedResult;
  final int performerBonus;

  const PartyRoundSnapshot({
    required this.number,
    required this.phase,
    required this.phaseStartedAt,
    required this.phaseEndsAt,
    required this.performer,
    required this.witness,
    required this.challenge,
    required this.submittedGuessCount,
    required this.performerReady,
    required this.ownGuess,
    required this.guesses,
    required this.bets,
    required this.proposedResult,
    required this.performerBonus,
  });

  factory PartyRoundSnapshot.fromJson(Map<String, dynamic> json) {
    final witnessJson = json['witness'];
    final ownGuessJson = json['own_guess'];
    return PartyRoundSnapshot(
      number: (json['number'] as num).toInt(),
      phase: PartyRoundPhase.fromString(json['phase'] as String),
      phaseStartedAt: DateTime.parse(
        json['phase_started_at'] as String,
      ).toUtc(),
      phaseEndsAt: json['phase_ends_at'] == null
          ? null
          : DateTime.parse(json['phase_ends_at'] as String).toUtc(),
      performer: PartyParticipant.fromJson(
        Map<String, dynamic>.from(json['performer'] as Map),
      ),
      witness: witnessJson is Map
          ? PartyParticipant.fromJson(Map<String, dynamic>.from(witnessJson))
          : null,
      challenge: PartyChallenge.fromJson(
        Map<String, dynamic>.from(json['challenge'] as Map),
      ),
      submittedGuessCount: (json['submitted_guess_count'] as num).toInt(),
      performerReady: json['performer_ready'] as bool? ?? false,
      ownGuess: ownGuessJson is Map
          ? PartyGuessSnapshot.fromJson(Map<String, dynamic>.from(ownGuessJson))
          : null,
      guesses: (json['guesses'] as List? ?? const [])
          .map(
            (value) => PartyGuessSnapshot.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(growable: false),
      bets: (json['bets'] as List? ?? const [])
          .map(
            (value) => PartyBetSnapshot.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(growable: false),
      proposedResult: (json['proposed_result'] as num?)?.toInt(),
      performerBonus: (json['performer_bonus'] as num?)?.toInt() ?? 0,
    );
  }
}

extension PartyRoundPhaseMapping on PartyRoundPhase {
  RoundPhase get gamePhase => switch (this) {
    PartyRoundPhase.guessing => RoundPhase.guessing,
    PartyRoundPhase.betting => RoundPhase.betting,
    PartyRoundPhase.ready => RoundPhase.partyReady,
    PartyRoundPhase.action => RoundPhase.partyAction,
    PartyRoundPhase.resultEntry => RoundPhase.partyResultEntry,
    PartyRoundPhase.resultConfirm => RoundPhase.partyResultConfirm,
    PartyRoundPhase.reveal => RoundPhase.revealAnswer,
  };
}

class PartySnapshot {
  final Room room;
  final int stateVersion;
  final int turnIndex;
  final int turnCount;
  final PartyRoundSnapshot round;
  final Map<String, int> scores;

  const PartySnapshot({
    required this.room,
    required this.stateVersion,
    required this.turnIndex,
    required this.turnCount,
    required this.round,
    required this.scores,
  });

  factory PartySnapshot.fromJson(Map<String, dynamic> json) {
    final rawScores = json['scores'] as Map? ?? const {};
    return PartySnapshot(
      room: Room.fromJson(Map<String, dynamic>.from(json['room'] as Map)),
      stateVersion: (json['state_version'] as num).toInt(),
      turnIndex: (json['turn_index'] as num).toInt(),
      turnCount: (json['turn_count'] as num).toInt(),
      round: PartyRoundSnapshot.fromJson(
        Map<String, dynamic>.from(json['round'] as Map),
      ),
      scores: rawScores.map(
        (key, value) => MapEntry('$key', (value as num).toInt()),
      ),
    );
  }
}
