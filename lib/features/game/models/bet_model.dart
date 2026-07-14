/// Bet model — a player's chip placement on a betting slot
class Bet {
  final String id;
  final String roomId;
  final int roundNumber;
  final String playerId;
  final String? targetGuessId;
  final int slotIndex;    // 0-6 on the board
  final int chips;
  final int payoutMultiplier;
  final bool won;
  final String? playerName;
  final String? playerColor;
  final double? positionX;
  final double? positionY;

  const Bet({
    required this.id,
    required this.roomId,
    required this.roundNumber,
    required this.playerId,
    this.targetGuessId,
    required this.slotIndex,
    this.chips = 1,
    required this.payoutMultiplier,
    this.won = false,
    this.playerName,
    this.playerColor,
    this.positionX,
    this.positionY,
  });

  factory Bet.fromJson(Map<String, dynamic> json) {
    return Bet(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      roundNumber: json['round_number'] as int,
      playerId: json['player_id'] as String,
      targetGuessId: json['target_guess_id'] as String?,
      slotIndex: json['slot_index'] as int,
      chips: json['chips'] as int? ?? 1,
      payoutMultiplier: json['payout_multiplier'] as int,
      won: json['won'] as bool? ?? false,
      playerName: json['player_name'] as String?,
      playerColor: json['player_color'] as String?,
      positionX: (json['position_x'] as num?)?.toDouble(),
      positionY: (json['position_y'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'round_number': roundNumber,
      'player_id': playerId,
      'target_guess_id': targetGuessId,
      'slot_index': slotIndex,
      'chips': chips,
      'payout_multiplier': payoutMultiplier,
      if (positionX != null) 'position_x': positionX,
      if (positionY != null) 'position_y': positionY,
    };
  }

  Bet copyWith({
    String? id,
    String? roomId,
    int? roundNumber,
    String? playerId,
    String? targetGuessId,
    int? slotIndex,
    int? chips,
    int? payoutMultiplier,
    bool? won,
    String? playerName,
    String? playerColor,
    double? positionX,
    double? positionY,
  }) {
    return Bet(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      roundNumber: roundNumber ?? this.roundNumber,
      playerId: playerId ?? this.playerId,
      targetGuessId: targetGuessId ?? this.targetGuessId,
      slotIndex: slotIndex ?? this.slotIndex,
      chips: chips ?? this.chips,
      payoutMultiplier: payoutMultiplier ?? this.payoutMultiplier,
      won: won ?? this.won,
      playerName: playerName ?? this.playerName,
      playerColor: playerColor ?? this.playerColor,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
    );
  }
}
