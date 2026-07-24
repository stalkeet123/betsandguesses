class PartyMoment {
  final String id;
  final String roomId;
  final int roundNumber;
  final String uploaderPlayerId;
  final String uploaderName;
  final String? uploaderColor;
  final String storagePath;
  final DateTime createdAt;
  final String? signedUrl;

  const PartyMoment({
    required this.id,
    required this.roomId,
    required this.roundNumber,
    required this.uploaderPlayerId,
    required this.uploaderName,
    required this.uploaderColor,
    required this.storagePath,
    required this.createdAt,
    this.signedUrl,
  });

  factory PartyMoment.fromJson(Map<String, dynamic> json) {
    return PartyMoment(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      roundNumber: (json['round_number'] as num).toInt(),
      uploaderPlayerId: json['uploader_player_id'] as String,
      uploaderName: json['uploader_name'] as String? ?? 'Player',
      uploaderColor: json['uploader_color'] as String?,
      storagePath: json['storage_path'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
      signedUrl: json['signed_url'] as String?,
    );
  }

  PartyMoment copyWith({String? signedUrl}) {
    return PartyMoment(
      id: id,
      roomId: roomId,
      roundNumber: roundNumber,
      uploaderPlayerId: uploaderPlayerId,
      uploaderName: uploaderName,
      uploaderColor: uploaderColor,
      storagePath: storagePath,
      createdAt: createdAt,
      signedUrl: signedUrl ?? this.signedUrl,
    );
  }
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
    );
  }
}
