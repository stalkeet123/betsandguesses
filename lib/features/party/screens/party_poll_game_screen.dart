import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/game_constants.dart';
import '../../../core/providers/core_providers.dart';
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

class _PartyPollGameScreenState extends ConsumerState<PartyPollGameScreen>
    with WidgetsBindingObserver {
  Timer? _clockTimer;
  Timer? _refreshTimer;
  Timer? _reloadDebounce;
  bool _transitionCommandInFlight = false;
  bool _snapshotLoadInFlight = false;
  bool _isFinished = false;
  int? _selectedChipValue;
  String? _lastErrorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initialLoad());
    });
    _clockTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
      unawaited(_runDeadlineTransitionIfNeeded());
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
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadSnapshot());
    }
  }

  Future<void> _initialLoad() async {
    await _loadSnapshot(connectRealtime: true);
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
          setState(() => _isFinished = true);
        }
      }
    } finally {
      _transitionCommandInFlight = false;
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
    final placement = await ref
        .read(partyPollSessionProvider.notifier)
        .placeBet(
          roomId: snapshot.room.id,
          targetPlayerId: targetPlayerId,
          chips: chip,
          clientActionId: const Uuid().v4(),
          positionX: positionX,
          positionY: positionY,
        );
    if (placement == null && mounted) {
      _showMessage(
        ref.read(partyPollSessionProvider).errorMessage ??
            'Bet could not be placed.',
      );
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
    if (_isFinished) return _finishedView(snapshot);
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
        .map(
          (bet) => PartyPollViewBet(
            id: bet.id,
            bettorPlayerId: bet.playerId,
            targetPlayerId: bet.targetPlayerId,
            targetSlotIndex: targetSlotByPlayerId[bet.targetPlayerId]!,
            chips: bet.chips,
            positionX: bet.positionX,
            positionY: bet.positionY,
            won: bet.won,
          ),
        )
        .toList(growable: false);
    final isReveal = snapshot.round.phase == PartyPollPhase.reveal;
    final deadline = snapshot.round.phaseEndsAt;
    final rawRemaining = deadline == null
        ? Duration.zero
        : deadline.difference(DateTime.now().toUtc());
    final remaining = rawRemaining.isNegative ? Duration.zero : rawRemaining;

    return Scaffold(
      body: PartyPollProductionView(
        roundNumber: snapshot.round.number,
        maxRounds: snapshot.room.maxRounds,
        remaining: remaining,
        isReveal: isReveal,
        questionText: snapshot.round.question.text,
        questionRules: snapshot.round.question.rules,
        players: viewPlayers,
        bets: viewBets,
        winningPlayerIds: snapshot.round.winningPlayerIds.toSet(),
        score: snapshot.me.score,
        betTotal: snapshot.me.betTotal,
        betLimit: snapshot.me.betLimit,
        availableChips: snapshot.me.availableChips,
        selectedChipValue: _selectedChipValue,
        currentPlayerId: snapshot.me.playerId,
        selectedBetId: null,
        emphasizeWinners: isReveal,
        onChipSelected: (value) {
          setState(() {
            _selectedChipValue = _selectedChipValue == value ? null : value;
          });
        },
        onBetSelected: (_) {},
        onBetRequested: (targetPlayerId, _, positionX, positionY) {
          unawaited(_placeBet(snapshot, targetPlayerId, positionX, positionY));
        },
        onBetMoveRequested: (_, _, _, _, _) {},
        onBetRemoveRequested: (_) {},
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

  Widget _finishedView(PartyPollSnapshot? snapshot) => Scaffold(
    backgroundColor: PartyPalette.nightDeep,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'GAME FINISHED',
            style: GoogleFonts.outfit(
              color: PartyPalette.cream,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (snapshot != null) ...[
            const SizedBox(height: 12),
            Text(
              'Your score: ${snapshot.me.score}',
              style: const TextStyle(color: PartyPalette.creamMuted),
            ),
          ],
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => context.goNamed('home'),
            child: const Text('BACK TO HOME'),
          ),
        ],
      ),
    ),
  );
}
