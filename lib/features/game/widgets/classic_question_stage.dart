import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';

import '../../../core/constants/game_constants.dart';
import '../models/game_state.dart';
import '../models/question_model.dart';

typedef ClassicQuestionPresented =
    void Function(Question question, String source);

/// Presentation only. The durable question/transition authority belongs to
/// [classicPresentationProvider]; local state is only a one-frame bridge from
/// the first visible question frame to that durable write.
class ClassicQuestionStage extends StatefulWidget {
  final GameState gameState;
  final String? expectedQuestionId;
  final String? classicMatchId;
  final int? stateVersion;
  final bool questionAlreadyPresented;
  final Question? retainedPresentedQuestion;
  final ClassicQuestionPresented? onQuestionPresented;
  final DateTime? questionRevealAt;
  final DateTime Function()? serverNow;
  final WidgetBuilder transitionBuilder;
  final Widget Function(BuildContext, GameState) questionBuilder;

  const ClassicQuestionStage({
    super.key,
    required this.gameState,
    required this.expectedQuestionId,
    this.classicMatchId,
    this.stateVersion,
    required this.questionAlreadyPresented,
    this.retainedPresentedQuestion,
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
  Timer? _questionRevealTimer;
  String? _scheduledQuestionIdentity;
  DateTime? _scheduledQuestionRevealAt;
  String? _visibleBridgeIdentity;
  Question? _visibleBridgeQuestion;
  String? _visibleBridgeSource;
  String? _loggedTransitionIdentity;
  String? _loggedReplayBlockerIdentity;

  String _identity(GameState state, String? questionId) =>
      '${state.roomId}:${widget.classicMatchId ?? 'none'}:'
      '${state.currentRound}:${questionId ?? 'none'}';

  String _short(String? value) => value == null
      ? 'none'
      : value.length <= 8
      ? value
      : value.substring(0, 8);

  void _log(String event, GameState state, {String? retainedQuestionId}) {
    if (!kDebugMode) return;
    debugPrint(
      'CLASSIC_SYNC $event '
      'room=${state.roomId} match=${_short(widget.classicMatchId)} '
      'round=${state.currentRound} phase=${state.phase.name} '
      'state_version=${widget.stateVersion ?? 'none'} '
      'expectedQuestionId=${_short(widget.expectedQuestionId)} '
      'actualQuestionId=${_short(state.currentQuestion?.id)} '
      'retainedQuestionId=${_short(retainedQuestionId)}',
    );
  }

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

  bool _matchesExpectedQuestion(GameState state) {
    final question = state.currentQuestion;
    return question != null && question.id == widget.expectedQuestionId;
  }

  void _showQuestionAndPersist(Question question, String source) {
    final incoming = widget.gameState;
    final identity = _identity(incoming, question.id);
    if (_visibleBridgeIdentity == identity) return;
    _visibleBridgeIdentity = identity;
    _visibleBridgeQuestion = question;
    _visibleBridgeSource = source;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.questionAlreadyPresented) return;
      final bridgeQuestion = _visibleBridgeQuestion;
      final bridgeSource = _visibleBridgeSource;
      if (bridgeQuestion == null || bridgeSource == null) return;
      widget.onQuestionPresented?.call(bridgeQuestion, bridgeSource);
    });
  }

  void _reconcilePresentation() {
    final incoming = widget.gameState;
    if (widget.questionAlreadyPresented) {
      _cancelScheduledReveal();
      return;
    }

    final question = incoming.currentQuestion;
    if (incoming.phase == RoundPhase.guessing &&
        question != null &&
        _matchesExpectedQuestion(incoming)) {
      _cancelScheduledReveal();
      _showQuestionAndPersist(question, 'guessing_snapshot');
      return;
    }

    if (incoming.phase != RoundPhase.question ||
        question == null ||
        !_matchesExpectedQuestion(incoming)) {
      return;
    }

    final revealAt = widget.questionRevealAt;
    final now = widget.serverNow?.call();
    if (revealAt == null || now == null) return;
    final delay = revealAt.difference(now);
    if (delay <= Duration.zero) {
      _cancelScheduledReveal();
      _showQuestionAndPersist(question, 'question_deadline_immediate');
      return;
    }

    final identity = _identity(incoming, question.id);
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
      if (!mounted || widget.questionAlreadyPresented) return;
      final latest = widget.gameState;
      if ((latest.phase == RoundPhase.question ||
              latest.phase == RoundPhase.guessing) &&
          _matchesExpectedQuestion(latest)) {
        _showQuestionAndPersist(
          latest.currentQuestion!,
          'question_deadline_timer',
        );
        setState(() {});
      }
    });
  }

  void _cancelScheduledReveal() {
    _questionRevealTimer?.cancel();
    _questionRevealTimer = null;
    _scheduledQuestionIdentity = null;
    _scheduledQuestionRevealAt = null;
  }

  GameState _latestStateWith(Question question) =>
      widget.gameState.copyWith(currentQuestion: question);

  @override
  Widget build(BuildContext context) {
    final incoming = widget.gameState;
    final retained = widget.retainedPresentedQuestion;
    final incomingMatches = _matchesExpectedQuestion(incoming);
    final bridgeQuestion = _visibleBridgeQuestion;
    final canShowImmediately =
        incomingMatches &&
        ((incoming.phase == RoundPhase.guessing) ||
            (incoming.phase == RoundPhase.question &&
                bridgeQuestion?.id == incoming.currentQuestion?.id));

    if (widget.questionAlreadyPresented) {
      // This branch is intentionally before every transition decision. A
      // same-round snapshot may omit question metadata, but it cannot replay
      // the transition after the durable latch is set.
      final question = incomingMatches ? incoming.currentQuestion : retained;
      if (question != null) {
        final wouldTransition =
            !incomingMatches ||
            incoming.phase == RoundPhase.idle ||
            incoming.phase == RoundPhase.question;
        final identity = _identity(incoming, question.id);
        if (wouldTransition && _loggedReplayBlockerIdentity != identity) {
          _loggedReplayBlockerIdentity = identity;
          _log(
            'transition_replay_blocked',
            incoming,
            retainedQuestionId: retained?.id,
          );
        }
        return widget.questionBuilder(context, _latestStateWith(question));
      }
      // A provider latch is only set with a Question. Keep this non-transition
      // fallback defensive in case a malformed caller violates that contract.
      return const SizedBox.expand();
    }

    if (canShowImmediately && incoming.currentQuestion != null) {
      return widget.questionBuilder(
        context,
        _latestStateWith(incoming.currentQuestion!),
      );
    }

    final identity = _identity(incoming, widget.expectedQuestionId);
    if (_loggedTransitionIdentity != identity) {
      _loggedTransitionIdentity = identity;
      _log('transition_shown', incoming);
    }
    return KeyedSubtree(
      key: ValueKey('classic-preparing-${incoming.currentRound}'),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: Builder(builder: widget.transitionBuilder),
      ),
    );
  }
}
