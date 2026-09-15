import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/core/constants/game_constants.dart';
import 'package:witsgame/features/game/models/game_state.dart';
import 'package:witsgame/features/game/models/question_model.dart';
import 'package:witsgame/features/game/providers/game_providers.dart';
import 'package:witsgame/features/game/widgets/classic_question_stage.dart';

const questionA = Question(id: 'question-a', textTr: 'Question A');

GameState state({
  int round = 2,
  RoundPhase phase = RoundPhase.question,
  Question? question,
  bool submitted = false,
}) => GameState(
  roomId: 'room-a',
  roomCode: 'ABCDEF',
  currentRound: round,
  phase: phase,
  currentQuestion: question,
  hasSubmittedGuess: submitted,
);

Widget surface(
  GameState incoming, {
  required bool alreadyPresented,
  Question? retainedQuestion,
  ClassicQuestionPresented? onQuestionPresented,
  DateTime? questionRevealAt,
  DateTime Function()? serverNow,
  Key? stageKey,
}) => MaterialApp(
  home: ClassicQuestionStage(
    key: stageKey,
    gameState: incoming,
    expectedQuestionId: questionA.id,
    classicMatchId: 'match-a',
    stateVersion: 12,
    questionAlreadyPresented: alreadyPresented,
    retainedPresentedQuestion: retainedQuestion,
    onQuestionPresented: onQuestionPresented,
    questionRevealAt: questionRevealAt,
    serverNow: serverNow,
    transitionBuilder: (_) => const Text('TRANSITION'),
    questionBuilder: (_, presented) => Text(
      '${presented.currentQuestion!.textTr}'
      '${presented.hasSubmittedGuess ? ' SUBMITTED' : ''}',
    ),
  ),
);

void main() {
  testWidgets('expired question deadline persists at first visible question', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(classicPresentationProvider.notifier)
        .reconcileSession(
          roomId: 'room-a',
          classicMatchId: 'match-a',
          round: 2,
          questionId: questionA.id,
          status: RoomStatus.playing,
        );
    final now = DateTime.utc(2026, 9, 10, 12);

    await tester.pumpWidget(
      surface(
        state(question: questionA),
        alreadyPresented: false,
        questionRevealAt: now.subtract(const Duration(milliseconds: 1)),
        serverNow: () => now,
        onQuestionPresented: (question, _) {
          container
              .read(classicPresentationProvider.notifier)
              .markQuestionPresented(
                roomId: 'room-a',
                classicMatchId: 'match-a',
                round: 2,
                question: question,
              );
        },
      ),
    );
    await tester.pump();

    expect(find.text('Question A'), findsOneWidget);
    expect(
      container.read(classicPresentationProvider).questionPresented,
      isTrue,
    );
    expect(find.text('TRANSITION'), findsNothing);
  });

  testWidgets('recreated Stage cannot replay a presented round transition', (
    tester,
  ) async {
    await tester.pumpWidget(
      surface(
        state(phase: RoundPhase.guessing, question: questionA),
        alreadyPresented: true,
        retainedQuestion: questionA,
      ),
    );
    expect(find.text('Question A'), findsOneWidget);

    await tester.pumpWidget(
      surface(
        state(),
        alreadyPresented: true,
        retainedQuestion: questionA,
        stageKey: const ValueKey('recreated-stage'),
      ),
    );

    expect(find.text('Question A'), findsOneWidget);
    expect(find.text('TRANSITION'), findsNothing);
  });

  testWidgets('deadline timer persists when it makes the question visible', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(classicPresentationProvider.notifier)
        .reconcileSession(
          roomId: 'room-a',
          classicMatchId: 'match-a',
          round: 2,
          questionId: questionA.id,
          status: RoomStatus.playing,
        );
    final now = DateTime.utc(2026, 9, 10, 12);

    await tester.pumpWidget(
      surface(
        state(question: questionA),
        alreadyPresented: false,
        questionRevealAt: now.add(const Duration(seconds: 1)),
        serverNow: () => now,
        onQuestionPresented: (question, _) {
          container
              .read(classicPresentationProvider.notifier)
              .markQuestionPresented(
                roomId: 'room-a',
                classicMatchId: 'match-a',
                round: 2,
                question: question,
              );
        },
      ),
    );
    expect(find.text('TRANSITION'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('Question A'), findsOneWidget);
    expect(
      container.read(classicPresentationProvider).questionPresented,
      isTrue,
    );
  });
}
