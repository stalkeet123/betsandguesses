import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:witsgame/core/constants/game_constants.dart';
import 'package:witsgame/features/game/models/question_model.dart';
import 'package:witsgame/features/game/providers/game_providers.dart';

const _question = Question(id: 'question-a', textTr: 'Question A');

ProviderContainer _container() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

void _reconcile(
  ProviderContainer container, {
  String roomId = 'room-a',
  String? matchId = 'match-a',
  int round = 2,
  String? questionId = 'question-a',
  RoomStatus status = RoomStatus.playing,
}) {
  container
      .read(classicPresentationProvider.notifier)
      .reconcileSession(
        roomId: roomId,
        classicMatchId: matchId,
        round: round,
        questionId: questionId,
        status: status,
      );
}

void _present(ProviderContainer container) {
  expect(
    container
        .read(classicPresentationProvider.notifier)
        .markQuestionPresented(
          roomId: 'room-a',
          classicMatchId: 'match-a',
          round: 2,
          question: _question,
        ),
    isTrue,
  );
}

void main() {
  test('same-round reconstruction and reconciliation retain presentation', () {
    final container = _container();
    _reconcile(container);
    _present(container);

    _reconcile(container, questionId: null);

    final state = container.read(classicPresentationProvider);
    expect(state.questionPresented, isTrue);
    expect(state.presentedQuestion, _question);
  });

  test('higher same-round state reconciliation cannot clear presentation', () {
    final container = _container();
    _reconcile(container);
    _present(container);

    _reconcile(container, questionId: 'question-a');

    expect(
      container.read(classicPresentationProvider).questionPresented,
      isTrue,
    );
  });

  test('a newer round starts unpresented', () {
    final container = _container();
    _reconcile(container);
    _present(container);

    _reconcile(container, round: 3, questionId: 'question-b');

    final state = container.read(classicPresentationProvider);
    expect(state.round, 3);
    expect(state.questionPresented, isFalse);
    expect(state.presentedQuestion, isNull);
  });

  test('a new Classic match cannot inherit the old latch', () {
    final container = _container();
    _reconcile(container);
    _present(container);

    _reconcile(
      container,
      matchId: 'match-b',
      round: 1,
      questionId: 'question-b',
    );

    final state = container.read(classicPresentationProvider);
    expect(state.classicMatchId, 'match-b');
    expect(state.round, 1);
    expect(state.questionPresented, isFalse);
  });
}
