import 'package:flutter/material.dart';
import '../../../core/utils/helpers.dart';

/// Player model
class Player {
  final String id;
  final String roomId;
  final String name;
  final String avatarColor;
  final int score;
  final bool isHost;
  final bool isReady;
  final bool isConnected;
  final DateTime joinedAt;

  const Player({
    required this.id,
    required this.roomId,
    required this.name,
    this.avatarColor = '#FF6B9D',
    this.score = 0,
    this.isHost = false,
    this.isReady = false,
    this.isConnected = true,
    required this.joinedAt,
  });

  Color get color => Color(Helpers.colorFromHex(avatarColor));

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      name: json['name'] as String,
      avatarColor: json['avatar_color'] as String? ?? '#FF6B9D',
      score: json['score'] as int? ?? 0,
      isHost: json['is_host'] as bool? ?? false,
      isReady: json['is_ready'] as bool? ?? false,
      isConnected: json['is_connected'] as bool? ?? true,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'name': name,
      'avatar_color': avatarColor,
      'score': score,
      'is_host': isHost,
      'is_ready': isReady,
      'is_connected': isConnected,
    };
  }

  /// Insert-only JSON (no id, let DB generate it)
  Map<String, dynamic> toInsertJson() {
    return {
      'room_id': roomId,
      'name': name,
      'avatar_color': avatarColor,
      'is_host': isHost,
    };
  }

  Player copyWith({
    String? id,
    String? roomId,
    String? name,
    String? avatarColor,
    int? score,
    bool? isHost,
    bool? isReady,
    bool? isConnected,
    DateTime? joinedAt,
  }) {
    return Player(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      name: name ?? this.name,
      avatarColor: avatarColor ?? this.avatarColor,
      score: score ?? this.score,
      isHost: isHost ?? this.isHost,
      isReady: isReady ?? this.isReady,
      isConnected: isConnected ?? this.isConnected,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}
