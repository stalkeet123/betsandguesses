import '../../../core/constants/game_constants.dart';

/// Room model
class Room {
  final String id;
  final String code;
  final String hostId;
  final RoomStatus status;
  final int currentRound;
  final int maxRounds;
  final int maxPlayers;
  final String? category;
  final RoundPhase roundPhase;
  final String? currentQuestionId;
  final DateTime createdAt;

  const Room({
    required this.id,
    required this.code,
    required this.hostId,
    this.status = RoomStatus.waiting,
    this.currentRound = 0,
    this.maxRounds = GameConstants.defaultRounds,
    this.maxPlayers = GameConstants.freeMaxPlayers,
    this.category,
    this.roundPhase = RoundPhase.idle,
    this.currentQuestionId,
    required this.createdAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      code: json['code'] as String,
      hostId: json['host_id'] as String,
      status: RoomStatus.fromString(json['status'] as String? ?? 'waiting'),
      currentRound: json['current_round'] as int? ?? 0,
      maxRounds: json['max_rounds'] as int? ?? GameConstants.defaultRounds,
      maxPlayers: json['max_players'] as int? ?? GameConstants.freeMaxPlayers,
      category: json['category'] as String?,
      roundPhase: RoundPhase.fromString(
        json['round_phase'] as String? ?? 'idle',
      ),
      currentQuestionId: json['current_question_id'] as String?,
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
      'max_players': maxPlayers,
      'category': category,
      'round_phase': roundPhase.name,
      'current_question_id': currentQuestionId,
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
    int? maxPlayers,
    String? category,
    RoundPhase? roundPhase,
    String? currentQuestionId,
    DateTime? createdAt,
  }) {
    return Room(
      id: id ?? this.id,
      code: code ?? this.code,
      hostId: hostId ?? this.hostId,
      status: status ?? this.status,
      currentRound: currentRound ?? this.currentRound,
      maxRounds: maxRounds ?? this.maxRounds,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      category: category ?? this.category,
      roundPhase: roundPhase ?? this.roundPhase,
      currentQuestionId: currentQuestionId ?? this.currentQuestionId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
