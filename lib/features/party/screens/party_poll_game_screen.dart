import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/game_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../room/models/room_model.dart';
import '../../room/providers/room_providers.dart';
import '../models/party_poll_snapshot.dart';
import '../providers/party_poll_session_provider.dart';
import '../theme/party_palette.dart';
import '../widgets/party_poll_production_view.dart';

class PartyPollGameScreen extends ConsumerStatefulWidget {
  final String roomCode;

  const PartyPollGameScreen({super.key, required this.roomCode});

  @override
  ConsumerState<PartyPollGameScreen> createState() =>
      _PartyPollGameScreenState();
}

class _PendingPartyPollBetVisual {
  final String clientActionId;
  final int roundNumber;
  final String targetPlayerId;
  final int chips;
  final double? positionX;
  final double? positionY;

  const _PendingPartyPollBetVisual({
    required this.clientActionId,
    required this.roundNumber,
    required this.targetPlayerId,
    required this.chips,
    required this.positionX,
    required this.positionY,
  });
}

class _PendingPartyPollMoveVisual {
  final String betId;
  final int roundNumber;
  final String targetPlayerId;
  final double positionX;
  final double positionY;
  const _PendingPartyPollMoveVisual({
    required this.betId,
    required this.roundNumber,
    required this.targetPlayerId,
    required this.positionX,
    required this.positionY,
  });
}

class _PartyPollGameScreenState extends ConsumerState<PartyPollGameScreen>
    with WidgetsBindingObserver {
  Timer? _clockTimer;
  Timer? _refreshTimer;
  Timer? _reloadDebounce;
  Timer? _revealScanTimer;
  Timer? _revealLeadInTimer;
  Timer? _revealClinkTimer;
  bool _transitionCommandInFlight = false;
  bool _snapshotLoadInFlight = false;
  bool _betCommandInFlight = false;
  _PendingPartyPollBetVisual? _pendingBetVisual;
  _PendingPartyPollMoveVisual? _pendingMoveVisual;
  bool _showPartyRoundTransition = false;
  int? _partyTransitionRound;
  Timer? _partyRoundTransitionTimer;
  bool _resultsNavigationScheduled = false;
  int? _selectedChipValue;
  String? _selectedBetId;
  String? _lastErrorMessage;
  String? _startedRevealKey;
  int? _activeRevealSlotIndex;
  bool _emphasizeRevealWinners = false;
  int? _lastDisplayedRemainingSecond;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initialLoad());
    });
    _clockTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      unawaited(_runDeadlineTransitionIfNeeded());
      final snapshot = ref.read(partyPollSessionProvider).snapshot;
      final deadline = snapshot?.round.phaseEndsAt;
      final second = deadline == null
          ? 0
          : max(0, deadline.difference(DateTime.now().toUtc()).inSeconds);
      if (mounted && second != _lastDisplayedRemainingSecond) {
        _lastDisplayedRemainingSecond = second;
        setState(() {});
      }
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_loadSnapshot());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _refreshTimer?.cancel();
    _reloadDebounce?.cancel();
    _cancelRevealChoreography(resetRevealKey: true);
    _partyRoundTransitionTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadSnapshot());
    }
  }

  Future<void> _initialLoad() async {
    final audio = ref.read(audioServiceProvider);
    unawaited(audio.startGameSilence());
    unawaited(audio.preparePartyPollRevealAudio());
    await _loadSnapshot(connectRealtime: true);
  }

  String _revealKey(PartyPollSnapshot snapshot) =>
      '${snapshot.round.number}:${snapshot.round.phaseStartedAt.toIso8601String()}';

  bool _isCurrentReveal(String key) {
    final snapshot = ref.read(partyPollSessionProvider).snapshot;
    return mounted &&
        _startedRevealKey == key &&
        snapshot != null &&
        snapshot.round.phase == PartyPollPhase.reveal &&
        _revealKey(snapshot) == key;
  }

  void _cancelRevealChoreography({required bool resetRevealKey}) {
    unawaited(ref.read(audioServiceProvider).stopResultReveal());
    unawaited(ref.read(audioServiceProvider).stopPayout());
    _revealLeadInTimer?.cancel();
    _revealLeadInTimer = null;
    _revealScanTimer?.cancel();
    _revealScanTimer = null;
    _revealClinkTimer?.cancel();
    _revealClinkTimer = null;
    if (resetRevealKey) _startedRevealKey = null;
  }

  void _observeRevealSnapshot(PartyPollSnapshot snapshot) {
    if (snapshot.round.phase != PartyPollPhase.reveal) {
      final needsClear =
          _startedRevealKey != null ||
          _activeRevealSlotIndex != null ||
          _emphasizeRevealWinners;
      _cancelRevealChoreography(resetRevealKey: true);
      if (needsClear && mounted) {
        setState(() {
          _activeRevealSlotIndex = null;
          _emphasizeRevealWinners = false;
        });
      }
      return;
    }

    final key = _revealKey(snapshot);
    if (_startedRevealKey == key) return;
    _cancelRevealChoreography(resetRevealKey: false);
    _startedRevealKey = key;
    setState(() {
      _selectedBetId = null;
      _activeRevealSlotIndex = null;
      _emphasizeRevealWinners = false;
    });
    unawaited(_startRevealChoreography(snapshot, key));
  }

  Future<void> _startRevealChoreography(
    PartyPollSnapshot snapshot,
    String key,
  ) async {
    const impactMs = 2050;
    const maxCadenceMs = 240;
    final players = [...snapshot.round.players]
      ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
    final activeSlots = players
        .map((player) => player.slotIndex)
        .toList(growable: false);
    int? primaryWinningSlot;
    for (final player in players) {
      if (snapshot.round.winningPlayerIds.contains(player.id)) {
        primaryWinningSlot = player.slotIndex;
        break;
      }
    }
    final scanOrder = <int>[
      ...activeSlots,
      ...activeSlots,
      if (primaryWinningSlot != null) primaryWinningSlot,
    ];
    await ref.read(audioServiceProvider).playResultReveal();
    if (!_isCurrentReveal(key) || scanOrder.isEmpty) return;
    final cadenceMs = min(maxCadenceMs, impactMs ~/ scanOrder.length);
    final leadInMs = impactMs - cadenceMs * scanOrder.length;
    void complete() {
      if (!_isCurrentReveal(key)) return;
      _revealScanTimer?.cancel();
      _revealScanTimer = null;
      setState(() {
        _activeRevealSlotIndex = primaryWinningSlot;
        _emphasizeRevealWinners = true;
      });
      final own = snapshot.round.bets
          .where((bet) => bet.playerId == snapshot.me.playerId)
          .toList(growable: false);
      if (own.isNotEmpty) {
        final net = own.fold<int>(
          0,
          (sum, bet) => sum + (bet.won == true ? bet.chips : -bet.chips),
        );
        final audio = ref.read(audioServiceProvider);
        unawaited(net > 0 ? audio.playPayout() : audio.playChipLoss());
      }
      _revealClinkTimer = Timer(const Duration(milliseconds: 240), () {
        if (_isCurrentReveal(key)) {
          unawaited(ref.read(audioServiceProvider).playClink());
        }
      });
    }

    void begin() {
      if (!_isCurrentReveal(key)) return;
      var step = 0;
      setState(() => _activeRevealSlotIndex = scanOrder.first);
      _revealScanTimer = Timer.periodic(Duration(milliseconds: cadenceMs), (
        timer,
      ) {
        if (!_isCurrentReveal(key)) {
          timer.cancel();
          return;
        }
        step++;
        if (step >= scanOrder.length) {
          complete();
          return;
        }
        unawaited(ref.read(audioServiceProvider).playClick());
        setState(() => _activeRevealSlotIndex = scanOrder[step]);
      });
    }

    _revealLeadInTimer = Timer(Duration(milliseconds: leadInMs), begin);
  }

  Future<void> _loadSnapshot({bool connectRealtime = false}) async {
    if (!mounted || _snapshotLoadInFlight) return;
    final room = ref.read(currentRoomProvider);
    if (room == null) return;
    _snapshotLoadInFlight = true;
    try {
      final snapshot = await ref
          .read(partyPollSessionProvider.notifier)
          .load(room.id);
      if (snapshot != null && mounted) {
        ref.read(currentRoomProvider.notifier).set(snapshot.room);
        if (connectRealtime) unawaited(_connectRealtime(snapshot));
      }
    } finally {
      _snapshotLoadInFlight = false;
    }
  }

  Future<void> _connectRealtime(PartyPollSnapshot snapshot) async {
    final player = ref.read(currentPlayerProvider);
    try {
      await ref
          .read(realtimeServiceProvider)
          .joinRoom(
            widget.roomCode,
            roomId: snapshot.room.id,
            presencePayload: player == null
                ? null
                : {'device_id': player.deviceId, 'player_id': player.id},
            onPhaseChange: (_) => _scheduleSnapshotReload(),
            onGuessSubmitted: (_) => _scheduleSnapshotReload(),
            onGuessesRevealed: (_) => _scheduleSnapshotReload(),
            onBetPlaced: (_) => _scheduleSnapshotReload(),
            onBetRemoved: (_) => _scheduleSnapshotReload(),
            onScoreUpdate: (_) => _scheduleSnapshotReload(),
            onAnswerRevealed: (_) => _scheduleSnapshotReload(),
            onGameStarted: (_) => _scheduleSnapshotReload(),
            onGameEnded: (_) => _scheduleSnapshotReload(),
            onRoomRowChanged: (_) => _scheduleSnapshotReload(),
          );
    } catch (_) {
      // Periodic snapshot refresh remains the recovery path.
    }
  }

  void _scheduleSnapshotReload() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_loadSnapshot());
    });
  }

  Future<void> _runDeadlineTransitionIfNeeded() async {
    final snapshot = ref.read(partyPollSessionProvider).snapshot;
    if (!mounted || snapshot == null || _transitionCommandInFlight) return;
    final deadline = snapshot.round.phaseEndsAt;
    if (deadline == null || DateTime.now().toUtc().isBefore(deadline)) return;

    _transitionCommandInFlight = true;
    try {
      if (snapshot.round.phase == PartyPollPhase.betting) {
        await ref
            .read(partyPollSessionProvider.notifier)
            .settleRound(snapshot.room.id);
      } else {
        final result = await ref
            .read(partyPollSessionProvider.notifier)
            .advanceRound(
              snapshot.room.id,
              bettingDurationSeconds: GameConstants.partyBetTimerSeconds,
            );
        if (result?['finished'] == true && mounted) {
          final roomJson = result?['room'];
          if (roomJson is Map) {
            ref
                .read(currentRoomProvider.notifier)
                .set(Room.fromJson(Map<String, dynamic>.from(roomJson)));
          }
          _goToResultsOnce();
        }
      }
    } finally {
      _transitionCommandInFlight = false;
    }
  }

  void _triggerPartyRoundTransition(PartyPollSnapshot snapshot) {
    if (_partyTransitionRound == snapshot.round.number) return;
    _partyTransitionRound = snapshot.round.number;
    _partyRoundTransitionTimer?.cancel();
    _showPartyRoundTransition = true;
    unawaited(ref.read(audioServiceProvider).playQuestionReveal());
    setState(() {});
    _partyRoundTransitionTimer = Timer(const Duration(milliseconds: 2100), () {
      if (mounted) setState(() => _showPartyRoundTransition = false);
    });
  }

  void _goToResultsOnce() {
    unawaited(ref.read(audioServiceProvider).stopTransientEffects());
    if (_resultsNavigationScheduled || !mounted) return;
    _resultsNavigationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.goNamed(
          'results',
          pathParameters: {'roomCode': widget.roomCode},
        );
      }
    });
  }

  void _observePresentationSnapshot(PartyPollSnapshot snapshot) {
    _clearStalePendingBetVisual(snapshot);
    _observeRevealSnapshot(snapshot);
    if (snapshot.round.phase == PartyPollPhase.betting) {
      _triggerPartyRoundTransition(snapshot);
    }
    if (snapshot.status == 'finished') _goToResultsOnce();
  }

  Widget _buildPartyRoundTransitionOverlay(PartyPollSnapshot snapshot) {
    final round = snapshot.round;
    final content = IgnorePointer(
      child: ColoredBox(
        color: PartyPalette.nightDeep.withValues(alpha: 0.97),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5.5,
                      ),
                      decoration: BoxDecoration(
                        color: PartyPalette.surfaceRaised,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: PartyPalette.orangeSoft.withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: PartyPalette.orange.withValues(alpha: 0.25),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Text(
                        'ROUND ${round.number} OF ${snapshot.room.maxRounds}',
                        style: GoogleFonts.outfit(
                          color: PartyPalette.orangeSoft,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'ROUND ${round.number}',
                        maxLines: 1,
                        style: const TextStyle(
                          fontFamily: 'RehnCondensed',
                          color: PartyPalette.cream,
                          fontSize: 96,
                          fontWeight: FontWeight.w900,
                          height: 0.88,
                          letterSpacing: 0,
                          shadows: [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 20,
                              offset: Offset(0, 4),
                            ),
                            Shadow(color: PartyPalette.orange, blurRadius: 28),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            PartyPalette.surfaceRaised.withValues(alpha: 0.95),
                            PartyPalette.surface.withValues(alpha: 0.98),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: PartyPalette.orangeSoft.withValues(
                            alpha: 0.45,
                          ),
                          width: 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(
                                colors: [
                                  PartyPalette.surfaceRaised,
                                  PartyPalette.nightDeep,
                                ],
                              ),
                              border: Border.all(
                                color: PartyPalette.orangeSoft,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: PartyPalette.orange.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.how_to_vote_rounded,
                              color: PartyPalette.cream,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'GROUP POLL',
                                  style: GoogleFonts.outfit(
                                    color: PartyPalette.orangeSoft,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'EVERYONE VOTES',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'RehnCondensed',
                                    color: PartyPalette.cream,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    height: 0.95,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Majority Rules · Pick who fits best!',
                                  style: GoogleFonts.outfit(
                                    color: PartyPalette.blueMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return content;
    return content
        .animate(key: ValueKey('party-round-transition-${round.number}'))
        .fadeIn(duration: 220.ms, curve: Curves.easeOut)
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: 450.ms,
          curve: Curves.easeOutCubic,
        )
        .fadeOut(delay: 1600.ms, duration: 450.ms, curve: Curves.easeIn);
  }

  void _clearStalePendingBetVisual(PartyPollSnapshot snapshot) {
    final pending = _pendingBetVisual;
    if (pending == null ||
        (snapshot.round.phase == PartyPollPhase.betting &&
            pending.roundNumber == snapshot.round.number)) {
      return;
    }
    setState(() {
      if (identical(_pendingBetVisual, pending)) {
        _pendingBetVisual = null;
      }
    });
  }

  Future<void> _placeBet(
    PartyPollSnapshot snapshot,
    String targetPlayerId,
    double? positionX,
    double? positionY,
  ) async {
    if (_betCommandInFlight) return;
    final chip = _selectedChipValue;
    if (chip == null || snapshot.round.phase != PartyPollPhase.betting) return;
    final targetExists = snapshot.round.players.any(
      (player) => player.id == targetPlayerId,
    );
    if (!targetExists) return;
    final ownTargetIds = snapshot.round.bets
        .where((bet) => bet.playerId == snapshot.me.playerId)
        .map((bet) => bet.targetPlayerId)
        .toSet();
    if (ownTargetIds.length >= 2 && !ownTargetIds.contains(targetPlayerId)) {
      _showMessage('You can back up to two players this round.');
      return;
    }
    if (chip > snapshot.me.availableChips) {
      _showMessage('That chip is not available.');
      return;
    }

    final clientActionId = const Uuid().v4();
    setState(() {
      _betCommandInFlight = true;
      _pendingBetVisual = _PendingPartyPollBetVisual(
        clientActionId: clientActionId,
        roundNumber: snapshot.round.number,
        targetPlayerId: targetPlayerId,
        chips: chip,
        positionX: positionX,
        positionY: positionY,
      );
    });
    ref.read(audioServiceProvider).playDrop();

    try {
      final placement = await ref
          .read(partyPollSessionProvider.notifier)
          .placeBet(
            roomId: snapshot.room.id,
            targetPlayerId: targetPlayerId,
            chips: chip,
            clientActionId: clientActionId,
            positionX: positionX,
            positionY: positionY,
          );
      if (placement == null && mounted) {
        _showMessage(
          ref.read(partyPollSessionProvider).errorMessage ??
              'Bet could not be placed.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _betCommandInFlight = false;
          if (_pendingBetVisual?.clientActionId == clientActionId) {
            _pendingBetVisual = null;
          }
        });
      }
    }
  }

  void _selectBet(PartyPollSnapshot snapshot, String betId) {
    if (snapshot.round.phase != PartyPollPhase.betting) return;
    final isOwnedCurrentBet = snapshot.round.bets.any(
      (bet) => bet.id == betId && bet.playerId == snapshot.me.playerId,
    );
    if (!isOwnedCurrentBet) return;
    ref.read(audioServiceProvider).playChip();
    setState(() {
      _selectedBetId = betId;
      _selectedChipValue = null;
    });
  }

  Future<void> _moveBet(
    PartyPollSnapshot snapshot,
    String betId,
    String targetPlayerId,
    double positionX,
    double positionY,
  ) async {
    if (_betCommandInFlight || snapshot.round.phase != PartyPollPhase.betting) {
      return;
    }
    PartyPollBet? sourceBet;
    for (final bet in snapshot.round.bets) {
      if (bet.id == betId && bet.playerId == snapshot.me.playerId) {
        sourceBet = bet;
        break;
      }
    }
    if (sourceBet == null) {
      if (mounted) setState(() => _selectedBetId = null);
      return;
    }
    if (!snapshot.round.players.any((player) => player.id == targetPlayerId) ||
        !positionX.isFinite ||
        !positionY.isFinite) {
      return;
    }
    final otherTargetIds = snapshot.round.bets
        .where((bet) => bet.playerId == snapshot.me.playerId && bet.id != betId)
        .map((bet) => bet.targetPlayerId)
        .toSet();
    if (otherTargetIds.length >= 2 &&
        !otherTargetIds.contains(targetPlayerId)) {
      _showMessage('You can back up to two players this round.');
      return;
    }

    setState(() {
      _betCommandInFlight = true;
      _pendingMoveVisual = _PendingPartyPollMoveVisual(
        betId: betId,
        roundNumber: snapshot.round.number,
        targetPlayerId: targetPlayerId,
        positionX: positionX,
        positionY: positionY,
      );
    });
    ref.read(audioServiceProvider).playDrop();
    try {
      final updated = await ref
          .read(partyPollSessionProvider.notifier)
          .moveBet(
            roomId: snapshot.room.id,
            betId: betId,
            targetPlayerId: targetPlayerId,
            positionX: positionX,
            positionY: positionY,
          );
      if (updated == null && mounted) {
        _showMessage(
          ref.read(partyPollSessionProvider).errorMessage ??
              'Bet could not be moved.',
        );
      } else if (updated != null && mounted) {
        setState(() {
          _selectedBetId = betId;
          _selectedChipValue = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _betCommandInFlight = false;
          _pendingMoveVisual = null;
        });
      }
    }
  }

  Future<void> _removeBet(PartyPollSnapshot snapshot, String betId) async {
    if (_betCommandInFlight || snapshot.round.phase != PartyPollPhase.betting) {
      return;
    }
    final isOwnedCurrentBet = snapshot.round.bets.any(
      (bet) => bet.id == betId && bet.playerId == snapshot.me.playerId,
    );
    if (!isOwnedCurrentBet) {
      if (mounted) setState(() => _selectedBetId = null);
      return;
    }

    setState(() {
      _betCommandInFlight = true;
      _selectedBetId = null;
      _selectedChipValue = null;
    });
    ref.read(audioServiceProvider).playClick();
    try {
      final updated = await ref
          .read(partyPollSessionProvider.notifier)
          .removeBet(roomId: snapshot.room.id, betId: betId);
      if (updated == null && mounted) {
        _showMessage(
          ref.read(partyPollSessionProvider).errorMessage ??
              'Bet could not be removed.',
        );
      }
    } finally {
      if (mounted) setState(() => _betCommandInFlight = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted || message == _lastErrorMessage) return;
    _lastErrorMessage = message;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(partyPollSessionProvider);
    final snapshot = state.snapshot;
    if (snapshot == null) return _loadingOrError(state);

    final targetSlotByPlayerId = {
      for (final player in snapshot.round.players) player.id: player.slotIndex,
    };
    final viewPlayers = snapshot.round.players
        .map(
          (player) => PartyPollViewPlayer(
            id: player.id,
            slotIndex: player.slotIndex,
            name: player.name,
            score: snapshot.scores[player.id] ?? 0,
          ),
        )
        .toList(growable: false);
    final viewBets = snapshot.round.bets
        .where((bet) => targetSlotByPlayerId.containsKey(bet.targetPlayerId))
        .map((bet) {
          final pendingMove = _pendingMoveVisual;
          final usePendingMove =
              pendingMove != null &&
              snapshot.round.phase == PartyPollPhase.betting &&
              pendingMove.roundNumber == snapshot.round.number &&
              pendingMove.betId == bet.id &&
              targetSlotByPlayerId.containsKey(pendingMove.targetPlayerId);
          final targetPlayerId = usePendingMove
              ? pendingMove.targetPlayerId
              : bet.targetPlayerId;
          return PartyPollViewBet(
            id: bet.id,
            bettorPlayerId: bet.playerId,
            targetPlayerId: targetPlayerId,
            targetSlotIndex: targetSlotByPlayerId[targetPlayerId]!,
            chips: bet.chips,
            positionX: usePendingMove ? pendingMove.positionX : bet.positionX,
            positionY: usePendingMove ? pendingMove.positionY : bet.positionY,
            won: bet.won,
          );
        })
        .toList();
    final isReveal = snapshot.round.phase == PartyPollPhase.reveal;
    final pending = _pendingBetVisual;
    final pendingIsAuthoritative =
        pending != null &&
        snapshot.round.bets.any(
          (bet) => bet.clientActionId == pending.clientActionId,
        );
    final pendingSlotIndex = pending == null
        ? null
        : targetSlotByPlayerId[pending.targetPlayerId];
    if (pending != null &&
        snapshot.round.phase == PartyPollPhase.betting &&
        pending.roundNumber == snapshot.round.number &&
        !pendingIsAuthoritative &&
        pendingSlotIndex != null) {
      viewBets.add(
        PartyPollViewBet(
          id: 'pending:${pending.clientActionId}',
          bettorPlayerId: snapshot.me.playerId,
          targetPlayerId: pending.targetPlayerId,
          targetSlotIndex: pendingSlotIndex,
          chips: pending.chips,
          positionX: pending.positionX,
          positionY: pending.positionY,
          won: null,
        ),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _observePresentationSnapshot(snapshot);
    });
    final effectiveSelectedBetId =
        !isReveal &&
            _selectedBetId != null &&
            snapshot.round.bets.any(
              (bet) =>
                  bet.id == _selectedBetId &&
                  bet.playerId == snapshot.me.playerId,
            )
        ? _selectedBetId
        : null;
    final deadline = snapshot.round.phaseEndsAt;
    final rawRemaining = deadline == null
        ? Duration.zero
        : deadline.difference(DateTime.now().toUtc());
    final remaining = rawRemaining.isNegative ? Duration.zero : rawRemaining;

    return Scaffold(
      body: Stack(
        children: [
          PartyPollProductionView(
            roundNumber: snapshot.round.number,
            maxRounds: snapshot.room.maxRounds,
            remaining: remaining,
            isReveal: isReveal,
            questionText: snapshot.round.question.text,
            players: viewPlayers,
            bets: viewBets,
            winningPlayerIds: snapshot.round.winningPlayerIds.toSet(),
            score: snapshot.me.score,
            betTotal: snapshot.me.betTotal,
            betLimit: snapshot.me.betLimit,
            availableChips: snapshot.me.availableChips,
            selectedChipValue: _selectedChipValue,
            currentPlayerId: snapshot.me.playerId,
            selectedBetId: effectiveSelectedBetId,
            emphasizeWinners: isReveal && _emphasizeRevealWinners,
            activeRevealSlotIndex: isReveal ? _activeRevealSlotIndex : null,
            onChipSelected: (value) {
              setState(() {
                _selectedChipValue = _selectedChipValue == value ? null : value;
                _selectedBetId = null;
              });
              ref.read(audioServiceProvider).playChip();
            },
            onBetSelected: (betId) => _selectBet(snapshot, betId),
            onBetRequested: (targetPlayerId, _, positionX, positionY) {
              unawaited(
                _placeBet(snapshot, targetPlayerId, positionX, positionY),
              );
            },
            onBetMoveRequested:
                (betId, targetPlayerId, _, positionX, positionY) {
                  unawaited(
                    _moveBet(
                      snapshot,
                      betId,
                      targetPlayerId,
                      positionX,
                      positionY,
                    ),
                  );
                },
            onBetRemoveRequested: (betId) {
              unawaited(_removeBet(snapshot, betId));
            },
          ),
          if (_showPartyRoundTransition &&
              snapshot.round.phase == PartyPollPhase.betting)
            Positioned.fill(child: _buildPartyRoundTransitionOverlay(snapshot)),
        ],
      ),
    );
  }

  Widget _loadingOrError(PartyPollSessionState state) {
    return Scaffold(
      backgroundColor: PartyPalette.nightDeep,
      body: Center(
        child: state.isLoading
            ? const CircularProgressIndicator(color: PartyPalette.orangeSoft)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.errorMessage ?? 'Loading Party Poll...',
                    style: const TextStyle(color: PartyPalette.cream),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _loadSnapshot,
                    child: const Text('RETRY'),
                  ),
                ],
              ),
      ),
    );
  }
}
