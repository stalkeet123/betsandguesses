import 'package:flutter/widgets.dart';

import '../../../core/constants/game_constants.dart';
import '../models/game_state.dart';

/// Presentation only: transport state and server deadlines continue advancing
/// while this stage waits for the question belonging to the accepted round.
class ClassicQuestionStage extends StatefulWidget {
  final GameState gameState;
  final String? expectedQuestionId;
  final WidgetBuilder transitionBuilder;
  final Widget Function(BuildContext, GameState) questionBuilder;

  const ClassicQuestionStage({
    super.key,
    required this.gameState,
    required this.expectedQuestionId,
    required this.transitionBuilder,
    required this.questionBuilder,
  });

  @override
  State<ClassicQuestionStage> createState() => _ClassicQuestionStageState();
}

class _ClassicQuestionStageState extends State<ClassicQuestionStage> {
  GameState? _presentedQuestion;

  @override
  Widget build(BuildContext context) {
    final incoming = widget.gameState;
    final previous = _presentedQuestion;
    if (previous != null &&
        (previous.roomId != incoming.roomId ||
            previous.currentRound != incoming.currentRound)) {
      _presentedQuestion = null;
    }

    final question = incoming.currentQuestion;
    if (incoming.phase == RoundPhase.guessing &&
        question != null &&
        question.id == widget.expectedQuestionId) {
      _presentedQuestion = incoming;
    }

    final presented = _presentedQuestion;
    if (presented == null) {
      // Keep this subtree mounted when metadata arrives before the payload.
      // Never build an empty question page underneath the transition.
      return KeyedSubtree(
        key: ValueKey('classic-preparing-${incoming.currentRound}'),
        child: widget.transitionBuilder(context),
      );
    }

    // Once opened, same-round reconciliation cannot replay the transition.
    // Freeze interaction if the current authority no longer has matching data.
    return IgnorePointer(
      ignoring: !identical(presented, incoming),
      child: widget.questionBuilder(context, presented),
    );
  }
}
