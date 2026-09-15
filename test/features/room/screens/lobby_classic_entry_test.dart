import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/core/constants/game_constants.dart';
import 'package:witsgame/features/game/models/classic_snapshot.dart';
import 'package:witsgame/features/game/models/question_model.dart';
import 'package:witsgame/features/room/models/room_model.dart';
import 'package:witsgame/features/room/screens/lobby_screen.dart';

Room _room({
  String id = 'room-1',
  RoomStatus status = RoomStatus.playing,
  GameMode mode = GameMode.classic,
  int round = 1,
  String? questionId = 'question-1',
}) {
  return Room(
    id: id,
    code: 'ABC123',
    hostId: 'host-1',
    status: status,
    gameMode: mode,
    currentRound: round,
    currentQuestionId: questionId,
    roundPhase: RoundPhase.guessing,
    createdAt: DateTime.utc(2026),
  );
}

ClassicSnapshot _snapshot({Room? room, Question? question}) {
  return ClassicSnapshot(
    room: room ?? _room(),
    players: const [],
    guesses: const [],
    bets: const [],
    question: question ?? const Question(id: 'question-1', textTr: 'Question'),
    serverNow: DateTime.utc(2026),
  );
}

void main() {
  test(
    'Classic room-stream entry accepts an authoritative seeded snapshot',
    () {
      final startedRoom = _room();
      final snapshot = _snapshot();

      expect(
        isValidClassicLobbyEntrySnapshot(
          startedRoom: startedRoom,
          snapshot: snapshot,
        ),
        isTrue,
      );
    },
  );

  test('Classic room-stream entry rejects a snapshot without its question', () {
    final startedRoom = _room();
    final snapshot = ClassicSnapshot(
      room: _room(questionId: null),
      players: const [],
      guesses: const [],
      bets: const [],
      question: null,
      serverNow: DateTime.utc(2026),
    );

    expect(
      isValidClassicLobbyEntrySnapshot(
        startedRoom: startedRoom,
        snapshot: snapshot,
      ),
      isFalse,
    );
  });

  test('Classic room-stream entry rejects a mismatched question identity', () {
    final startedRoom = _room();
    final snapshot = _snapshot(
      room: _room(questionId: 'question-2'),
      question: const Question(id: 'question-3', textTr: 'Wrong question'),
    );

    expect(
      isValidClassicLobbyEntrySnapshot(
        startedRoom: startedRoom,
        snapshot: snapshot,
      ),
      isFalse,
    );
  });
}
