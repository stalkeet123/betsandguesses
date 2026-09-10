import '../../../core/constants/game_constants.dart';
import '../../player/models/player_model.dart';
import '../../room/models/room_model.dart';
import 'bet_model.dart';
import 'guess_model.dart';
import 'question_model.dart';

/// All visible Classic data from one database read snapshot.
class ClassicSnapshot {
  final Room room;
  final List<Player> players;
  final List<Guess> guesses;
  final List<Bet> bets;
  final Question? question;

  /// The database timestamp produced by the same MVCC read as this state.
  /// It lets a cold client render immediately without first blocking on a
  /// separate clock RPC.
  final DateTime? serverNow;

  const ClassicSnapshot({
    required this.room,
    required this.players,
    required this.guesses,
    required this.bets,
    required this.question,
    required this.serverNow,
  });

  factory ClassicSnapshot.fromResponse(Object? response) {
    Map<String, dynamic> object(Object? value, String field) {
      if (value is! Map) throw StateError('Invalid Classic snapshot: $field');
      return Map<String, dynamic>.from(value);
    }

    List<T> rows<T>(
      Object? value,
      String field,
      T Function(Map<String, dynamic>) parse,
    ) {
      if (value is! List) throw StateError('Invalid Classic snapshot: $field');
      return value.map((row) => parse(object(row, field))).toList();
    }

    final data = object(response, 'response');
    final rawServerNow = data['server_now'];
    final serverNow = rawServerNow == null
        ? null
        : DateTime.tryParse(rawServerNow as String)?.toUtc();
    if (rawServerNow != null && serverNow == null) {
      throw StateError('Invalid Classic snapshot: server_now');
    }
    final room = Room.fromJson(object(data['room'], 'room'));
    final question = data['question'] == null
        ? null
        : Question.fromJson(object(data['question'], 'question'));
    final players = rows(data['players'], 'players', Player.fromJson);
    final guesses = rows(data['guesses'], 'guesses', Guess.fromJson);
    final bets = rows(data['bets'], 'bets', Bet.fromJson);
    if (room.gameMode != GameMode.classic ||
        players.any((p) => p.roomId != room.id) ||
        guesses.any(
          (g) => g.roomId != room.id || g.roundNumber != room.currentRound,
        ) ||
        bets.any(
          (b) => b.roomId != room.id || b.roundNumber != room.currentRound,
        ) ||
        question?.id != room.currentQuestionId) {
      throw StateError('Inconsistent Classic snapshot identity');
    }
    return ClassicSnapshot(
      room: room,
      players: players,
      guesses: guesses,
      bets: bets,
      question: question,
      serverNow: serverNow,
    );
  }
}
