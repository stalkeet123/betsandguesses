import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/game_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../game/widgets/poker_chip.dart';
import '../../room/providers/room_providers.dart';
import '../models/party_poll_snapshot.dart';
import '../providers/party_poll_session_provider.dart';
import '../theme/party_palette.dart';

class PartyPollGameScreen extends ConsumerStatefulWidget {
  final String roomCode;

  const PartyPollGameScreen({super.key, required this.roomCode});

  @override
  ConsumerState<PartyPollGameScreen> createState() =>
      _PartyPollGameScreenState();
}

class _PartyPollGameScreenState extends ConsumerState<PartyPollGameScreen>
    with WidgetsBindingObserver {
  static const _chipValues = [1, 5, 10, 25];
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
    PartyPollPlayer target,
  ) async {
    final chip = _selectedChipValue;
    if (chip == null || snapshot.round.phase != PartyPollPhase.betting) return;
    final ownTargetIds = snapshot.round.bets
        .where((bet) => bet.playerId == snapshot.me.playerId)
        .map((bet) => bet.targetPlayerId)
        .toSet();
    if (ownTargetIds.length >= 2 && !ownTargetIds.contains(target.id)) {
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
          targetPlayerId: target.id,
          chips: chip,
          clientActionId: const Uuid().v4(),
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
    if (state.errorMessage != null && state.errorMessage != _lastErrorMessage) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showMessage(state.errorMessage!),
      );
    }
    if (_isFinished) return _finishedView(snapshot);
    if (snapshot == null) return _loadingOrError(state);

    final round = snapshot.round;
    final isBetting = round.phase == PartyPollPhase.betting;
    final remaining = round.phaseEndsAt?.difference(DateTime.now().toUtc());
    final orderedPlayers = [...round.players]
      ..sort((left, right) => left.slotIndex.compareTo(right.slotIndex));

    return Scaffold(
      backgroundColor: PartyPalette.nightDeep,
      body: SafeArea(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: PartyPalette.backgroundGradient,
          ),
          child: Column(
            children: [
              _header(snapshot, remaining, isBetting),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    _questionCard(snapshot),
                    const SizedBox(height: 16),
                    _accountStrip(snapshot),
                    const SizedBox(height: 20),
                    Text(
                      isBetting ? 'PLACE YOUR BET' : 'ROUND RESULTS',
                      style: const TextStyle(
                        color: PartyPalette.cream,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _targetGrid(snapshot, orderedPlayers, isBetting),
                    if (isBetting) ...[
                      const SizedBox(height: 22),
                      _chipPicker(snapshot),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
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

  Widget _header(
    PartyPollSnapshot snapshot,
    Duration? remaining,
    bool isBetting,
  ) {
    final seconds = remaining == null ? 0 : remaining.inSeconds.clamp(0, 999);
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'PARTY POLL',
              style: TextStyle(
                color: PartyPalette.cream,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'ROUND ${snapshot.round.number}',
                style: const TextStyle(
                  color: PartyPalette.creamMuted,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                isBetting
                    ? 'BETTING  $minutes:${remainder.toString().padLeft(2, '0')}'
                    : 'RESULT',
                style: const TextStyle(
                  color: PartyPalette.orangeSoft,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _questionCard(PartyPollSnapshot snapshot) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: PartyPalette.surface.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: PartyPalette.orangeSoft.withValues(alpha: .35)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          snapshot.round.question.text,
          style: const TextStyle(
            color: PartyPalette.cream,
            fontSize: 23,
            fontWeight: FontWeight.w900,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          snapshot.round.question.rules,
          style: const TextStyle(color: PartyPalette.creamMuted, height: 1.35),
        ),
      ],
    ),
  );

  Widget _accountStrip(PartyPollSnapshot snapshot) => Row(
    children: [
      _stat('SCORE', snapshot.me.score.toString()),
      const SizedBox(width: 8),
      _stat('LIMIT', snapshot.me.betLimit.toString()),
      const SizedBox(width: 8),
      _stat('AVAILABLE', snapshot.me.availableChips.toString()),
    ],
  );

  Widget _stat(String label, String value) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: PartyPalette.surfaceRaised.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: PartyPalette.cream,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: PartyPalette.creamMuted,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _targetGrid(
    PartyPollSnapshot snapshot,
    List<PartyPollPlayer> players,
    bool isBetting,
  ) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: players.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.18,
    ),
    itemBuilder: (_, index) {
      final target = players[index];
      final ownBets = snapshot.round.bets.where(
        (bet) =>
            bet.playerId == snapshot.me.playerId &&
            bet.targetPlayerId == target.id,
      );
      final ownTotal = ownBets.fold<int>(0, (total, bet) => total + bet.chips);
      final hasTwoTargets =
          snapshot.round.bets
              .where((bet) => bet.playerId == snapshot.me.playerId)
              .map((bet) => bet.targetPlayerId)
              .toSet()
              .length >=
          2;
      final disabled =
          !isBetting ||
          _selectedChipValue == null ||
          (hasTwoTargets && ownTotal == 0);
      final winner = snapshot.round.winningPlayerIds.contains(target.id);
      return InkWell(
        onTap: disabled ? null : () => _placeBet(snapshot, target),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: winner
                ? PartyPalette.sage.withValues(alpha: .45)
                : PartyPalette.surfaceWarm.withValues(alpha: .72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: winner
                  ? PartyPalette.cream
                  : PartyPalette.creamMuted.withValues(alpha: .22),
              width: winner ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: _avatarColor(target.avatarColor),
                child: Text(
                  target.name.isEmpty ? '?' : target.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                target.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PartyPalette.cream,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              Text(
                winner
                    ? 'WINNER'
                    : ownTotal > 0
                    ? 'YOUR BET: $ownTotal'
                    : isBetting
                    ? 'TAP TO BET'
                    : '—',
                style: TextStyle(
                  color: winner ? PartyPalette.cream : PartyPalette.creamMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _chipPicker(PartyPollSnapshot snapshot) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'SELECT A CHIP',
        style: TextStyle(
          color: PartyPalette.creamMuted,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 14,
        children: _chipValues
            .map(
              (value) => GestureDetector(
                onTap: value > snapshot.me.availableChips
                    ? null
                    : () => setState(() => _selectedChipValue = value),
                child: Opacity(
                  opacity: value > snapshot.me.availableChips ? .35 : 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedChipValue == value
                            ? PartyPalette.cream
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: PokerChip(
                      label: value.toString(),
                      color: _chipColor(value),
                      size: 54,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    ],
  );

  Widget _finishedView(PartyPollSnapshot? snapshot) => Scaffold(
    backgroundColor: PartyPalette.nightDeep,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'GAME FINISHED',
            style: TextStyle(
              color: PartyPalette.cream,
              fontWeight: FontWeight.w900,
              fontSize: 28,
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

  Color _chipColor(int value) => switch (value) {
    1 => PartyPalette.terracotta,
    5 => PartyPalette.orange,
    10 => PartyPalette.plum,
    _ => PartyPalette.sage,
  };
  Color _avatarColor(String? value) => value == null
      ? PartyPalette.orange
      : Color(
          int.tryParse(value.replaceFirst('#', '0xFF')) ??
              PartyPalette.orange.toARGB32(),
        );
}
