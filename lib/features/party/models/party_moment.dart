import 'dart:typed_data';

import 'party_snapshot.dart';

class PartyMoment {
  final String id;
  final String roomId;
  final int roundNumber;
  final String uploaderPlayerId;
  final String uploaderName;
  final String? uploaderColor;
  final Uint8List bytes;
  final DateTime createdAt;

  const PartyMoment({
    required this.id,
    required this.roomId,
    required this.roundNumber,
    required this.uploaderPlayerId,
    required this.uploaderName,
    required this.uploaderColor,
    required this.bytes,
    required this.createdAt,
  });
}

class PartyRecapRound {
  final int roundNumber;
  final String performerId;
  final String performerName;
  final String challengeText;
  final String answerUnit;
  final int result;
  final int? crowdGuess;
  final int? performerGuess;
  final String? closestPlayerName;
  final int? closestGuess;
  final int performerBonus;
  final PartyChallengeType challengeType;
  final int durationSeconds;

  const PartyRecapRound({
    required this.roundNumber,
    required this.performerId,
    required this.performerName,
    required this.challengeText,
    required this.answerUnit,
    required this.result,
    required this.crowdGuess,
    required this.performerGuess,
    required this.closestPlayerName,
    required this.closestGuess,
    required this.performerBonus,
    required this.challengeType,
    required this.durationSeconds,
  });

  factory PartyRecapRound.fromJson(Map<String, dynamic> json) {
    return PartyRecapRound(
      roundNumber: (json['round_number'] as num).toInt(),
      performerId: json['performer_id'] as String,
      performerName: json['performer_name'] as String,
      challengeText: json['challenge_text'] as String,
      answerUnit: json['answer_unit'] as String,
      result: (json['result'] as num).toInt(),
      crowdGuess: (json['crowd_guess'] as num?)?.toInt(),
      performerGuess: (json['performer_guess'] as num?)?.toInt(),
      closestPlayerName: json['closest_player_name'] as String?,
      closestGuess: (json['closest_guess'] as num?)?.toInt(),
      performerBonus: (json['performer_bonus'] as num?)?.toInt() ?? 0,
      challengeType: PartyChallengeType.fromString(
        json['challenge_type'] as String?,
      ),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 60,
    );
  }
}
