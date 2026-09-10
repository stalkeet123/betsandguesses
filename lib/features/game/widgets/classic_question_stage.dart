import 'package:flutter/widgets.dart';

import '../../../core/constants/game_constants.dart';
import '../models/game_state.dart';

/// Presentation only: transport state and server deadlines continue advancing
/// while this stage waits for the question belonging to the accepted round.
class ClassicQuestionStage extends StatefulWidget {
  final GameState gameState;
  final String? expectedQuestionId;

  /// A previously opened authoritative question for this exact round. The
  /// parent owns this cache so a temporary route/subtree rebuild cannot make
  /// the same round play its transition a second time.
  final GameState? retainedQuestion;
  final ValueChanged<GameState>? onQuestionPresented;
  final WidgetBuilder transitionBuilder;
  final Widget Function(BuildContext, GameState) questionBuilder;

  const ClassicQuestionStage({
    super.key,
    required this.gameState,
    required this.expectedQuestionId,
    this.retainedQuestion,
    this.onQuestionPresented,
    required this.transitionBuilder,
    required this.questionBuilder,
  });

  @override
  State<ClassicQuestionStage> createState() => _ClassicQuestionStageState();
}

class _ClassicQuestionStageState extends State<ClassicQuestionStage> {
  GameState? _presentedQuestion;

  bool _matchesExpectedQuestion(GameState value, GameState incoming) {
    final question = value.currentQuestion;
    return value.roomId == incoming.roomId &&
        value.currentRound == incoming.currentRound &&
        question != null &&
        question.id == widget.expectedQuestionId;
  }

  @override
  Widget build(BuildContext context) {
    final incoming = widget.gameState;
    final previous = _presentedQuestion;
    if (previous != null &&
        (previous.roomId != incoming.roomId ||
            previous.currentRound != incoming.currentRound)) {
      _presentedQuestion = null;
    }

    final retained = widget.retainedQuestion;
    if (_presentedQuestion == null &&
        retained != null &&
        _matchesExpectedQuestion(retained, incoming)) {
      _presentedQuestion = retained;
    }

    if (incoming.phase == RoundPhase.guessing &&
        _matchesExpectedQuestion(incoming, incoming)) {
      _presentedQuestion = incoming;
      widget.onQuestionPresented?.call(incoming);
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
    // A snapshot produces a new GameState object even when it represents the
    // same authoritative question, so object identity must never gate input.
    return widget.questionBuilder(context, presented);
  }
}
