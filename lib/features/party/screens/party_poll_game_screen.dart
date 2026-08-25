import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/game_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_asset_image.dart';
import '../../../core/providers/core_providers.dart';
import '../../room/models/room_model.dart';
import '../../room/providers/room_providers.dart';
import '../models/party_poll_snapshot.dart';
import '../providers/party_poll_session_provider.dart';
import '../widgets/party_poll_production_view.dart';

class PartyPollGameScreen extends ConsumerStatefulWidget {
  final String roomCode;

  const PartyPollGameScreen({super.key, required this.roomCode});

  @override
  ConsumerState<PartyPollGameScreen> createState() =>
      _PartyPollGameScreenState();
}

// Must match the reveal chip entry contract in PartyPollProductionView.
const _revealChipEntryDurationMs = 350;
const _revealChipEntryStaggerMs = 40;
const _revealChipEntryMaxStaggerMs = 200;

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
  final Map<String, _PendingPartyPollBetVisual> _pendingBetVisuals =
      <String, _PendingPartyPollBetVisual>{};
  final Set<String> _optimisticallyHiddenBetIds = <String>{};
  final Map<String, _PendingPartyPollMoveVisual> _pendingMoveVisuals =
      <String, _PendingPartyPollMoveVisual>{};
  final Set<String> _removalCommandBetIds = <String>{};
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
    unawaited(audio.startPartyGameBgm());
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
    final opponentBetCount = snapshot.round.bets
        .where((bet) => bet.playerId != snapshot.me.playerId)
        .length;
    final revealEntryLeadMs =
        MediaQuery.disableAnimationsOf(context) || opponentBetCount == 0
        ? 0
        : _revealChipEntryDurationMs +
              min(
                _revealChipEntryMaxStaggerMs,
                (opponentBetCount - 1) * _revealChipEntryStaggerMs,
              ).toInt();
    if (revealEntryLeadMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: revealEntryLeadMs));
    }
    if (!_isCurrentReveal(key)) return;
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
    _reconcileOptimisticallyHiddenBets(snapshot);
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
        color: AppColors.feltDark.withValues(alpha: .97),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.brassLight,
                      size: 28,
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'ROUND',
                      style: GoogleFonts.outfit(
                        color: AppColors.ivory.withValues(alpha: .72),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${round.number}',
                        maxLines: 1,
                        style: const TextStyle(
                          fontFamily: 'RehnCondensed',
                          color: AppColors.brassLight,
                          fontSize: 108,
                          fontWeight: FontWeight.w900,
                          height: .9,
                          letterSpacing: 0,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: AppColors.brassLight.withValues(alpha: .35),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'PARTY POLL',
                          style: GoogleFonts.outfit(
                            color: AppColors.ivory,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: AppColors.brassLight.withValues(alpha: .35),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${round.number} / ${snapshot.room.maxRounds}',
                      style: GoogleFonts.outfit(
                        color: AppColors.brassLight.withValues(alpha: .72),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
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
    final staleIds = _pendingBetVisuals.entries
        .where(
          (entry) =>
              snapshot.round.phase != PartyPollPhase.betting ||
              entry.value.roundNumber != snapshot.round.number,
        )
        .map((entry) => entry.key)
        .toList(growable: false);
    if (staleIds.isNotEmpty && mounted) {
      setState(() {
        for (final id in staleIds) {
          _pendingBetVisuals.remove(id);
        }
      });
    }
  }

  void _reconcileOptimisticallyHiddenBets(PartyPollSnapshot snapshot) {
    if (_optimisticallyHiddenBetIds.isEmpty) return;
    final ids = snapshot.round.bets.map((bet) => bet.id).toSet();
    final stale = _optimisticallyHiddenBetIds
        .where(
          (id) =>
              snapshot.round.phase != PartyPollPhase.betting ||
              !ids.contains(id),
        )
        .toSet();
    if (stale.isNotEmpty && mounted) {
      setState(() => _optimisticallyHiddenBetIds.removeAll(stale));
    }
  }

  Future<void> _placeBet(
    PartyPollSnapshot snapshot,
    String targetPlayerId,
    double? positionX,
    double? positionY,
  ) async {
    final chip = _selectedChipValue;
    if (chip == null || snapshot.round.phase != PartyPollPhase.betting) return;
    final targetExists = snapshot.round.players.any(
      (player) => player.id == targetPlayerId,
    );
    if (!targetExists) return;
    final usedChips = snapshot.round.bets
        .where((bet) => !_optimisticallyHiddenBetIds.contains(bet.id))
        .where((bet) => bet.playerId == snapshot.me.playerId)
        .map((bet) => bet.chips)
        .toSet();
    final pendingChips = _pendingBetVisuals.values
        .where((pending) => pending.roundNumber == snapshot.round.number)
        .map((pending) => pending.chips)
        .toSet();
    if (usedChips.contains(chip) || pendingChips.contains(chip)) {
      _showMessage('That chip is already used this round.');
      return;
    }

    final clientActionId = const Uuid().v4();
    setState(() {
      _pendingBetVisuals[clientActionId] = _PendingPartyPollBetVisual(
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
        setState(() => _pendingBetVisuals.remove(clientActionId));
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
    if (_removalCommandBetIds.contains(betId) ||
        _pendingMoveVisuals.containsKey(betId) ||
        snapshot.round.phase != PartyPollPhase.betting) {
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

    setState(() {
      _pendingMoveVisuals[betId] = _PendingPartyPollMoveVisual(
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
      if (mounted) setState(() => _pendingMoveVisuals.remove(betId));
    }
  }

  Future<void> _removeBet(PartyPollSnapshot snapshot, String betId) async {
    if (_removalCommandBetIds.contains(betId) ||
        _pendingMoveVisuals.containsKey(betId) ||
        snapshot.round.phase != PartyPollPhase.betting) {
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
      _removalCommandBetIds.add(betId);
      _optimisticallyHiddenBetIds.add(betId);
      _selectedBetId = null;
      _selectedChipValue = null;
    });
    ref.read(audioServiceProvider).playClick();
    try {
      final updated = await ref
          .read(partyPollSessionProvider.notifier)
          .removeBet(roomId: snapshot.room.id, betId: betId);
      if (updated == null && mounted) {
        setState(() => _optimisticallyHiddenBetIds.remove(betId));
        _showMessage(
          ref.read(partyPollSessionProvider).errorMessage ??
              'Bet could not be removed.',
        );
      }
    } finally {
      if (mounted) setState(() => _removalCommandBetIds.remove(betId));
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
        .where((bet) => !_optimisticallyHiddenBetIds.contains(bet.id))
        .where((bet) => targetSlotByPlayerId.containsKey(bet.targetPlayerId))
        .map((bet) {
          final pendingMove = _pendingMoveVisuals[bet.id];
          final usePendingMove =
              pendingMove != null &&
              snapshot.round.phase == PartyPollPhase.betting &&
              pendingMove.roundNumber == snapshot.round.number &&
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
    for (final pending in _pendingBetVisuals.values) {
      final pendingIsAuthoritative = snapshot.round.bets.any(
        (bet) => bet.clientActionId == pending.clientActionId,
      );
      final pendingSlotIndex = targetSlotByPlayerId[pending.targetPlayerId];
      if (snapshot.round.phase == PartyPollPhase.betting &&
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
    }
    final effectiveOwnBetTotal = viewBets
        .where((bet) => bet.bettorPlayerId == snapshot.me.playerId)
        .fold<int>(0, (total, bet) => total + bet.chips);
    final presentationBetTotal = snapshot.round.phase == PartyPollPhase.betting
        ? effectiveOwnBetTotal
        : snapshot.me.betTotal;
    final presentationAvailableChips =
        snapshot.round.phase == PartyPollPhase.betting
        ? max(0, 40 - effectiveOwnBetTotal)
        : snapshot.me.availableChips;
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
            betTotal: presentationBetTotal,
            betLimit: snapshot.me.betLimit,
            availableChips: presentationAvailableChips,
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
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: CachedAssetImage(
              AppAssetPaths.background,
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: ColoredBox(
              color: AppColors.background.withValues(alpha: .38),
            ),
          ),
          Center(
            child: state.isLoading
                ? const CircularProgressIndicator(color: AppColors.brassLight)
                : Container(
                    constraints: const BoxConstraints(maxWidth: 340),
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(20),
                    decoration: AppColors.leatherPanel(borderRadius: 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          state.errorMessage ?? 'Loading Party Poll...',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: AppColors.ivory,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.brassLight,
                            side: const BorderSide(color: AppColors.brassLight),
                          ),
                          onPressed: _loadSnapshot,
                          child: const Text('RETRY'),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
