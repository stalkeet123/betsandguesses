import '../../../core/constants/game_constants.dart';

/// Room model
class Room {
  final String id;
  final String code;
  final String hostId;
  final RoomStatus status;
  final int currentRound;
  final int maxRounds;
  final RoundPhase roundPhase;
  final DateTime createdAt;

  const Room({
    required this.id,
    required this.code,
    required this.hostId,
    this.status = RoomStatus.waiting,
    this.currentRound = 0,
    this.maxRounds = 8,
    this.roundPhase = RoundPhase.idle,
    required this.createdAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      code: json['code'] as String,
      hostId: json['host_id'] as String,
      status: RoomStatus.fromString(json['status'] as String? ?? 'waiting'),
      currentRound: json['current_round'] as int? ?? 0,
      maxRounds: json['max_rounds'] as int? ?? 8,
      roundPhase: RoundPhase.fromString(json['round_phase'] as String? ?? 'idle'),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'host_id': hostId,
      'status': status.name,
      'current_round': currentRound,
      'max_rounds': maxRounds,
      'round_phase': roundPhase.name,
    };
  }

  bool get canJoinLobby => status == RoomStatus.waiting;

  Room copyWith({
    String? id,
    String? code,
    String? hostId,
    RoomStatus? status,
    int? currentRound,
    int? maxRounds,
    RoundPhase? roundPhase,
    DateTime? createdAt,
  }) {
    return Room(
      id: id ?? this.id,
      code: code ?? this.code,
      hostId: hostId ?? this.hostId,
      status: status ?? this.status,
      currentRound: currentRound ?? this.currentRound,
      maxRounds: maxRounds ?? this.maxRounds,
      roundPhase: roundPhase ?? this.roundPhase,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
