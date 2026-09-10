import 'dart:async';

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
  final DateTime? questionRevealAt;
  final DateTime Function()? serverNow;
  final WidgetBuilder transitionBuilder;
  final Widget Function(BuildContext, GameState) questionBuilder;

  const ClassicQuestionStage({
    super.key,
    required this.gameState,
    required this.expectedQuestionId,
    this.retainedQuestion,
    this.onQuestionPresented,
    this.questionRevealAt,
    this.serverNow,
    required this.transitionBuilder,
    required this.questionBuilder,
  });

  @override
  State<ClassicQuestionStage> createState() => _ClassicQuestionStageState();
}

class _ClassicQuestionStageState extends State<ClassicQuestionStage> {
  GameState? _presentedQuestion;
  Timer? _questionRevealTimer;
  String? _scheduledQuestionIdentity;
  DateTime? _scheduledQuestionRevealAt;

  @override
  void initState() {
    super.initState();
    _reconcilePresentation();
  }

  @override
  void didUpdateWidget(covariant ClassicQuestionStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reconcilePresentation();
  }

  @override
  void dispose() {
    _questionRevealTimer?.cancel();
    super.dispose();
  }

  bool _matchesExpectedQuestion(GameState value, GameState incoming) {
    final question = value.currentQuestion;
    return value.roomId == incoming.roomId &&
        value.currentRound == incoming.currentRound &&
        question != null &&
        question.id == widget.expectedQuestionId;
  }

  void _reconcilePresentation() {
    final incoming = widget.gameState;
    final previous = _presentedQuestion;
    if (previous != null &&
        (previous.roomId != incoming.roomId ||
            previous.currentRound != incoming.currentRound)) {
      _presentedQuestion = null;
      _cancelScheduledReveal();
    }

    final retained = widget.retainedQuestion;
    if (_presentedQuestion == null &&
        retained != null &&
        _matchesExpectedQuestion(retained, incoming)) {
      _presentedQuestion = retained;
    }

    if (incoming.phase == RoundPhase.guessing &&
        _matchesExpectedQuestion(incoming, incoming)) {
      _cancelScheduledReveal();
      final isNewPresentation =
          _presentedQuestion?.phase != RoundPhase.guessing ||
          _presentedQuestion?.roomId != incoming.roomId ||
          _presentedQuestion?.currentRound != incoming.currentRound ||
          _presentedQuestion?.currentQuestion?.id !=
              incoming.currentQuestion?.id;
      _presentedQuestion = incoming;
      if (isNewPresentation && widget.onQuestionPresented != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              !_matchesExpectedQuestion(incoming, widget.gameState)) {
            return;
          }
          widget.onQuestionPresented?.call(incoming);
        });
      }
      return;
    }

    if (incoming.phase == RoundPhase.question &&
        _matchesExpectedQuestion(incoming, incoming)) {
      // Once this round is visible, a late question-phase reconciliation must
      // not downgrade the retained authoritative guessing presentation.
      if (_presentedQuestion != null) return;
      final revealAt = widget.questionRevealAt;
      final now = widget.serverNow?.call();
      if (revealAt == null || now == null) return;
      final delay = revealAt.difference(now);
      if (delay <= Duration.zero) {
        _presentedQuestion = incoming;
        _cancelScheduledReveal();
        return;
      }

      final identity =
          '${incoming.roomId}:${incoming.currentRound}:'
          '${incoming.currentQuestion!.id}';
      if (_scheduledQuestionIdentity == identity &&
          _scheduledQuestionRevealAt == revealAt &&
          (_questionRevealTimer?.isActive ?? false)) {
        return;
      }
      _questionRevealTimer?.cancel();
      _scheduledQuestionIdentity = identity;
      _scheduledQuestionRevealAt = revealAt;
      _questionRevealTimer = Timer(delay, () {
        _questionRevealTimer = null;
        _scheduledQuestionIdentity = null;
        _scheduledQuestionRevealAt = null;
        if (!mounted) return;
        final latest = widget.gameState;
        if ((latest.phase == RoundPhase.question ||
                latest.phase == RoundPhase.guessing) &&
            _matchesExpectedQuestion(latest, latest)) {
          setState(() => _presentedQuestion = latest);
        }
      });
    }
  }

  void _cancelScheduledReveal() {
    _questionRevealTimer?.cancel();
    _questionRevealTimer = null;
    _scheduledQuestionIdentity = null;
    _scheduledQuestionRevealAt = null;
  }

  @override
  Widget build(BuildContext context) {
    final incoming = widget.gameState;
    final presented = _presentedQuestion;
    if (presented == null) {
      // Keep this subtree mounted when metadata arrives before the payload.
      // Never build an empty question page underneath the transition.
      return KeyedSubtree(
        key: ValueKey('classic-preparing-${incoming.currentRound}'),
        child: MediaQuery(
          // A Realtime/snapshot arrival must not restart a local entrance
          // animation. The authoritative deadline still decides when the
          // preparation surface is replaced by the question.
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: Builder(builder: widget.transitionBuilder),
        ),
      );
    }

    // Once opened, same-round reconciliation cannot replay the transition.
    // A snapshot produces a new GameState object even when it represents the
    // same authoritative question, so object identity must never gate input.
    return widget.questionBuilder(context, presented);
  }
}
