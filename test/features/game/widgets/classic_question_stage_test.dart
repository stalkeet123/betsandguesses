import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/core/constants/game_constants.dart';
import 'package:witsgame/features/game/models/game_state.dart';
import 'package:witsgame/features/game/models/question_model.dart';
import 'package:witsgame/features/game/widgets/classic_question_stage.dart';

const questionA = Question(id: 'question-a', textTr: 'Question A');
const questionB = Question(id: 'question-b', textTr: 'Question B');

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
  String? expectedId = 'question-a',
  VoidCallback? onTransitionMounted,
  bool board = false,
}) => MaterialApp(
  home: AnimatedSwitcher(
    duration: const Duration(milliseconds: 430),
    child: board
        ? const SizedBox(key: ValueKey('board'), child: Text('BOARD'))
        : KeyedSubtree(
            key: const ValueKey('guessing-surface'),
            child: ClassicQuestionStage(
              gameState: incoming,
              expectedQuestionId: expectedId,
              transitionBuilder: (_) => _TransitionProbe(
                round: incoming.currentRound,
                onMounted: onTransitionMounted,
              ),
              questionBuilder: (_, presented) {
                // The gameplay builder must never receive an empty question.
                return Text(
                  '${presented.currentQuestion!.textTr}'
                  '${presented.hasSubmittedGuess ? ' SUBMITTED' : ''}',
                );
              },
            ),
          ),
  ),
);

void main() {
  testWidgets('metadata before payload keeps one mounted transition', (
    tester,
  ) async {
    var mounts = 0;
    void mounted() => mounts++;
    await tester.pumpWidget(surface(state(), onTransitionMounted: mounted));
    await tester.pumpWidget(
      surface(
        state(phase: RoundPhase.guessing),
        onTransitionMounted: mounted,
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('ROUND 2'), findsOneWidget);
    expect(find.text('Question A'), findsNothing);
    expect(mounts, 1);

    await tester.pumpWidget(
      surface(
        state(phase: RoundPhase.guessing, question: questionA),
        onTransitionMounted: mounted,
      ),
    );
    expect(find.text('Question A'), findsOneWidget);
    expect(find.text('ROUND 2'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preloaded question waits for guessing authority', (
    tester,
  ) async {
    var mounts = 0;
    void mounted() => mounts++;
    await tester.pumpWidget(
      surface(state(question: questionA), onTransitionMounted: mounted),
    );
    expect(find.text('Question A'), findsNothing);
    await tester.pumpWidget(
      surface(state(question: questionA), onTransitionMounted: mounted),
    );
    expect(mounts, 1);
    await tester.pumpWidget(
      surface(state(phase: RoundPhase.guessing, question: questionA)),
    );
    expect(find.text('Question A'), findsOneWidget);
    expect(find.text('ROUND 2'), findsNothing);
  });

  testWidgets('idle and missed transition never build an empty question', (
    tester,
  ) async {
    await tester.pumpWidget(surface(state(round: 0, phase: RoundPhase.idle)));
    await tester.pumpWidget(surface(state(phase: RoundPhase.guessing)));
    expect(find.text('ROUND 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      surface(state(phase: RoundPhase.guessing, question: questionA)),
    );
    expect(find.text('Question A'), findsOneWidget);
  });

  testWidgets('cached prior question does not open the next round', (
    tester,
  ) async {
    await tester.pumpWidget(
      surface(state(phase: RoundPhase.guessing, question: questionA)),
    );
    await tester.pumpWidget(
      surface(
        state(round: 3, phase: RoundPhase.guessing, question: questionA),
        expectedId: questionB.id,
      ),
    );
    expect(find.text('ROUND 3'), findsOneWidget);
    expect(find.text('Question A'), findsNothing);
    await tester.pumpWidget(
      surface(
        state(round: 3, phase: RoundPhase.guessing, question: questionB),
        expectedId: questionB.id,
      ),
    );
    expect(find.text('Question B'), findsOneWidget);
  });

  testWidgets('same-round reconciliation cannot replay an opened transition', (
    tester,
  ) async {
    var mounts = 0;
    void mounted() => mounts++;
    await tester.pumpWidget(surface(state(), onTransitionMounted: mounted));
    await tester.pumpWidget(
      surface(
        state(phase: RoundPhase.guessing, question: questionA),
        onTransitionMounted: mounted,
      ),
    );
    for (final incoming in [
      state(question: questionA),
      state(phase: RoundPhase.guessing),
      state(phase: RoundPhase.guessing, question: questionA),
    ]) {
      await tester.pumpWidget(
        surface(incoming, onTransitionMounted: mounted),
      );
      expect(find.text('Question A'), findsOneWidget);
      expect(find.text('ROUND 2'), findsNothing);
    }
    expect(mounts, 1);
    await tester.pumpWidget(
      surface(
        state(
          phase: RoundPhase.guessing,
          question: questionA,
          submitted: true,
        ),
      ),
    );
    expect(find.text('Question A SUBMITTED'), findsOneWidget);
  });

  testWidgets('unknown expected identity cannot admit a cached question', (
    tester,
  ) async {
    await tester.pumpWidget(
      surface(
        state(phase: RoundPhase.guessing, question: questionA),
        expectedId: null,
      ),
    );
    expect(find.text('ROUND 2'), findsOneWidget);
    expect(find.text('Question A'), findsNothing);
  });

  testWidgets('outgoing surface keeps its captured round during a switch', (
    tester,
  ) async {
    var mounts = 0;
    void mounted() => mounts++;
    final ready = state(phase: RoundPhase.guessing, question: questionA);
    await tester.pumpWidget(surface(ready, onTransitionMounted: mounted));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      surface(state(phase: RoundPhase.betting), board: true),
    );
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpWidget(
      surface(
        state(round: 3, question: questionB),
        expectedId: questionB.id,
        onTransitionMounted: mounted,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ROUND 3'), findsOneWidget);
    expect(find.text('ROUND 2'), findsNothing);
    expect(mounts, 1);
  });
}

class _TransitionProbe extends StatefulWidget {
  final int round;
  final VoidCallback? onMounted;

  const _TransitionProbe({required this.round, this.onMounted});

  @override
  State<_TransitionProbe> createState() => _TransitionProbeState();
}

class _TransitionProbeState extends State<_TransitionProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMounted?.call();
  }

  @override
  Widget build(BuildContext context) => Text('ROUND ${widget.round}');
}
