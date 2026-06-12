/// Guess model — a player's numeric answer for a round
class Guess {
  final String id;
  final String roomId;
  final int roundNumber;
  final String playerId;
  final String? questionId;
  final int value;
  final bool isWinner;
  final String? playerName;   // joined from players table or broadcast
  final String? playerColor;  // joined from players table or broadcast

  const Guess({
    required this.id,
    required this.roomId,
    required this.roundNumber,
    required this.playerId,
    this.questionId,
    required this.value,
    this.isWinner = false,
    this.playerName,
    this.playerColor,
  });

  factory Guess.fromJson(Map<String, dynamic> json) {
    return Guess(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      roundNumber: json['round_number'] as int,
      playerId: json['player_id'] as String,
      questionId: json['question_id'] as String?,
      value: json['value'] as int,
      isWinner: json['is_winner'] as bool? ?? false,
      playerName: json['player_name'] as String?,
      playerColor: json['player_color'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'round_number': roundNumber,
      'player_id': playerId,
      'question_id': questionId,
      'value': value,
    };
  }

  Guess copyWith({
    String? id,
    String? roomId,
    int? roundNumber,
    String? playerId,
    String? questionId,
    int? value,
    bool? isWinner,
    String? playerName,
    String? playerColor,
  }) {
    return Guess(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      roundNumber: roundNumber ?? this.roundNumber,
      playerId: playerId ?? this.playerId,
      questionId: questionId ?? this.questionId,
      value: value ?? this.value,
      isWinner: isWinner ?? this.isWinner,
      playerName: playerName ?? this.playerName,
      playerColor: playerColor ?? this.playerColor,
    );
  }
}
