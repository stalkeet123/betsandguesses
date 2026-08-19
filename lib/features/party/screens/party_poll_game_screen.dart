import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/game_constants.dart';
import '../../../core/widgets/cached_asset_image.dart';
import '../../../core/providers/core_providers.dart';
import '../../game/widgets/poker_chip.dart';
import '../../room/providers/room_providers.dart';
import '../models/party_poll_snapshot.dart';
import '../providers/party_poll_session_provider.dart';
import '../theme/party_palette.dart';

enum _PollSlotTone { green, black, gold, red }

class _PollVisualSlot {
  final int index;
  final PartyPollPlayer? player;
  final _PollSlotTone tone;
  final Rect rect;
  const _PollVisualSlot(this.index, this.player, this.tone, this.rect);
}

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
    if (_isFinished) return _finishedView(snapshot);
    if (snapshot == null) return _loadingOrError(state);
    final isBetting = snapshot.round.phase == PartyPollPhase.betting;
    final remaining = snapshot.round.phaseEndsAt?.difference(
      DateTime.now().toUtc(),
    );
    final players = [...snapshot.round.players]
      ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _PollPartyTableBackground()),
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;
                    final compact = height < 700;
                    final gap = compact ? 8.0 : 10.0;
                    final logoTop = 6.0;
                    final logoHeight = compact ? 76.0 : 92.0;
                    final timerHeight = compact ? 39.0 : 42.0;
                    final leftColumnWidth = (width - 4) / 2;
                    final left = 6.0;
                    final leftWidth = leftColumnWidth - 12;
                    final boardLeft = leftColumnWidth + 4;
                    final boardWidth = width - boardLeft;
                    final timerBetTop = logoTop + logoHeight + 4;
                    final questionBetTop = timerBetTop + timerHeight + gap;
                    final chipHeight = compact ? 96.0 : 102.0;
                    final rawQuestionHeight =
                        height -
                        questionBetTop -
                        chipHeight -
                        (gap * 2) -
                        (compact ? 100 : 120) -
                        8;
                    final questionBetHeight = min(
                      height * (compact ? .28 : .29),
                      max(compact ? 112.0 : 132.0, rawQuestionHeight),
                    );
                    final chipTop = questionBetTop + questionBetHeight + gap;
                    final playersTop = chipTop + chipHeight + gap;
                    final playersHeight = max(72.0, height - playersTop - 8);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: left,
                          top: logoTop,
                          width: leftWidth,
                          height: logoHeight,
                          child: _partyModeMark(),
                        ),
                        Positioned(
                          left: left,
                          top: timerBetTop,
                          width: leftWidth,
                          height: timerHeight,
                          child: _roundTimerPills(
                            snapshot,
                            remaining,
                            isBetting,
                          ),
                        ),
                        Positioned(
                          left: left,
                          top: questionBetTop,
                          width: leftWidth,
                          height: questionBetHeight,
                          child: _questionCard(snapshot),
                        ),
                        Positioned(
                          left: left,
                          top: chipTop,
                          width: leftWidth,
                          height: chipHeight,
                          child: _chipPicker(snapshot),
                        ),
                        Positioned(
                          left: left,
                          top: playersTop,
                          width: leftWidth,
                          height: playersHeight,
                          child: _playersStrip(snapshot, players),
                        ),
                        Positioned(
                          left: boardLeft,
                          top: 0,
                          width: boardWidth,
                          height: height,
                          child: _pollBettingBoard(
                            snapshot,
                            players,
                            isBetting,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _partyModeMark() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    child: CachedAssetImage(AppAssetPaths.logo, fit: BoxFit.contain),
  );

  Widget _playersStrip(
    PartyPollSnapshot snapshot,
    List<PartyPollPlayer> players,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    decoration: BoxDecoration(
      color: PartyPalette.surface.withValues(alpha: .72),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: PartyPalette.orangeSoft.withValues(alpha: .20)),
    ),
    child: Row(
      children: [
        for (final player in players.take(5))
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    player.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: PartyPalette.creamMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${snapshot.scores[player.id] ?? 0}',
                    style: GoogleFonts.outfit(
                      color: PartyPalette.cream,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
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

  Widget _roundTimerPills(
    PartyPollSnapshot snapshot,
    Duration? remaining,
    bool isBetting,
  ) {
    final seconds = remaining?.inSeconds.clamp(0, 999) ?? 0;
    final time =
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Row(
        children: [
          _roundPill(
            'ROUND ${snapshot.round.number} / ${snapshot.room.maxRounds}',
          ),
          const Spacer(),
          _roundPill(isBetting ? time : 'RESULT', accent: !isBetting),
        ],
      ),
    );
  }

  Widget _roundPill(String label, {bool accent = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
    decoration: BoxDecoration(
      color: PartyPalette.surfaceRaised.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(
        color: PartyPalette.orangeSoft.withValues(alpha: accent ? .7 : .34),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .2),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Text(
      label,
      style: GoogleFonts.outfit(
        color: accent ? PartyPalette.orangeSoft : PartyPalette.cream,
        fontWeight: FontWeight.w900,
        fontSize: 11,
        letterSpacing: .8,
      ),
    ),
  );

  Widget _questionCard(PartyPollSnapshot snapshot) => Container(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
    decoration: BoxDecoration(
      color: PartyPalette.surface.withValues(alpha: .96),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: PartyPalette.orangeSoft.withValues(alpha: .32)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .24),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: PartyPalette.orange,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'GROUP POLL · EVERYONE VOTES',
              style: GoogleFonts.outfit(
                color: PartyPalette.orangeSoft,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          snapshot.round.question.rules,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            color: PartyPalette.blueMuted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 11),
        Text(
          snapshot.round.question.text,
          style: GoogleFonts.outfit(
            color: PartyPalette.cream,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
      ],
    ),
  );

  Widget _pollBettingBoard(
    PartyPollSnapshot snapshot,
    List<PartyPollPlayer> players,
    bool isBetting,
  ) {
    final slots = _productionPollSlots(players);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final slot in slots)
              Positioned(
                left: slot.rect.left * size.width,
                top: slot.rect.top * size.height,
                width: slot.rect.width * size.width,
                height: slot.rect.height * size.height,
                child: _productionPollSlot(snapshot, slot, isBetting),
              ),
          ],
        );
      },
    );
  }

  List<_PollVisualSlot> _productionPollSlots(List<PartyPollPlayer> players) {
    final count = players.isEmpty ? 4 : players.length.clamp(2, 8);
    const tones = [
      _PollSlotTone.green,
      _PollSlotTone.black,
      _PollSlotTone.gold,
      _PollSlotTone.red,
      _PollSlotTone.green,
      _PollSlotTone.black,
      _PollSlotTone.gold,
      _PollSlotTone.red,
    ];
    final gap = count <= 4 ? .020 : (count <= 6 ? .014 : .010);
    final height = (.960 - (count - 1) * gap) / count;
    return List.generate(
      count,
      (index) => _PollVisualSlot(
        index,
        index < players.length ? players[index] : null,
        tones[index % tones.length],
        Rect.fromLTWH(.040, .015 + index * (height + gap), .920, height),
      ),
    );
  }

  Widget _productionPollSlot(
    PartyPollSnapshot snapshot,
    _PollVisualSlot slot,
    bool isBetting,
  ) {
    final target = slot.player;
    if (target == null) return const SizedBox.shrink();
    final targetBets = snapshot.round.bets
        .where((bet) => bet.targetPlayerId == target.id)
        .toList();
    final ownBets = targetBets
        .where((bet) => bet.playerId == snapshot.me.playerId)
        .toList();
    final visibleBets = snapshot.round.phase == PartyPollPhase.reveal
        ? targetBets
        : ownBets;
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
        (hasTwoTargets && ownBets.isEmpty);
    final winner = snapshot.round.winningPlayerIds.contains(target.id);
    final radius = BorderRadius.circular(
      slot.tone == _PollSlotTone.gold ? 18 : 12,
    );
    final colors = _slotColors(slot.tone);
    return GestureDetector(
      onTap: disabled ? null : () => _placeBet(snapshot, target),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          border: Border.all(
            color: winner
                ? PartyPalette.orange
                : PartyPalette.orangeSoft.withValues(alpha: .25),
            width: winner ? 2.2 : 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .40),
              blurRadius: winner ? 20 : 10,
              offset: Offset(0, winner ? 8 : 4),
            ),
            if (winner)
              BoxShadow(
                color: PartyPalette.orange.withValues(alpha: .50),
                blurRadius: 28,
                spreadRadius: 3,
              ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 1,
              child: Container(color: Colors.white.withValues(alpha: .10)),
            ),
            if (winner)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: RadialGradient(
                      colors: [
                        PartyPalette.orangeSoft.withValues(alpha: .45),
                        PartyPalette.orange.withValues(alpha: .25),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            Center(
              child: Text(
                target.name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: PartyPalette.cream,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
            ),
            if (winner) Positioned(top: 7, right: 10, child: _winnerBadge()),
            ..._placedChips(visibleBets, winner),
          ],
        ),
      ),
    );
  }

  List<Color> _slotColors(_PollSlotTone tone) => switch (tone) {
    _PollSlotTone.green => const [Color(0xFF275B4B), Color(0xFF13382F)],
    _PollSlotTone.black => const [Color(0xFF263039), Color(0xFF11181C)],
    _PollSlotTone.gold => const [Color(0xFF75593A), Color(0xFF3E2D1F)],
    _PollSlotTone.red => const [Color(0xFF704446), Color(0xFF3A2024)],
  };
  Widget _winnerBadge() => Container(
    padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 7),
    decoration: BoxDecoration(
      color: PartyPalette.orangeSoft,
      borderRadius: BorderRadius.circular(99),
      boxShadow: [
        BoxShadow(
          color: PartyPalette.orange.withValues(alpha: .5),
          blurRadius: 10,
        ),
      ],
    ),
    child: Text(
      'WINNER',
      textAlign: TextAlign.center,
      style: GoogleFonts.outfit(
        color: PartyPalette.nightDeep,
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: .7,
      ),
    ),
  );

  List<Widget> _placedChips(List<PartyPollBet> bets, bool winner) {
    return [
      for (var index = 0; index < bets.length && index < 5; index++)
        Positioned(
          left: 18 + (index % 3) * 27.0,
          bottom: 8 + (index ~/ 3) * 18.0,
          child: Transform.rotate(
            angle: (index - 2) * .08,
            child: PokerChip(
              label: bets[index].chips.toString(),
              color: winner && bets[index].won == true
                  ? PartyPalette.orange
                  : _chipColor(bets[index].chips),
              size: 38,
            ),
          ),
        ),
    ];
  }

  Widget _chipPicker(PartyPollSnapshot snapshot) {
    final chips = _dynamicChips(snapshot.me.betLimit);
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
      decoration: BoxDecoration(
        color: PartyPalette.surface.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: PartyPalette.orangeSoft.withValues(alpha: .24),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: PartyPalette.orangeSoft.withValues(alpha: .48),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _selectedChipValue == null ? 'SELECT A CHIP' : 'TAP A BET AREA',
                style: GoogleFonts.outfit(
                  color: PartyPalette.cream.withValues(alpha: .78),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 1,
                  color: PartyPalette.orangeSoft.withValues(alpha: .48),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final value in chips)
                _selectableChip(value, snapshot.me.availableChips >= value),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(child: _chipStatPill('SCORE', '${snapshot.me.score}')),
              const SizedBox(width: 8),
              Expanded(
                child: _chipStatPill('ON TABLE', '${snapshot.me.betTotal}'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _selectableChip(int value, bool available) => GestureDetector(
    onTap: available ? () => setState(() => _selectedChipValue = value) : null,
    child: AnimatedScale(
      duration: const Duration(milliseconds: 140),
      scale: _selectedChipValue == value ? 1.13 : 1,
      child: Opacity(
        opacity: available ? 1 : .35,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: _selectedChipValue == value
                ? [
                    BoxShadow(
                      color: PartyPalette.orangeSoft.withValues(alpha: .5),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          child: PokerChip(label: '$value', color: _chipColor(value), size: 42),
        ),
      ),
    ),
  );

  Widget _chipStatPill(String label, String value) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .22),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: PartyPalette.orangeSoft.withValues(alpha: .28)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$label  ',
            style: GoogleFonts.outfit(
              color: PartyPalette.creamMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: PartyPalette.cream,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ),
  );

  List<int> _dynamicChips(int limit) {
    if (limit < 20) return const [1, 5, 10];
    if (limit < 50) return const [5, 10, 25];
    if (limit <= 150) return const [5, 10, 50];
    if (limit <= 350) return const [10, 50, 100];
    if (limit <= 1000) return const [50, 100, 500];
    return const [100, 500, 1000];
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

  Color _chipColor(int value) => switch (value) {
    1 => PartyPalette.plum,
    5 => PartyPalette.sage,
    10 => const Color(0xFF48657A),
    25 => PartyPalette.terracotta,
    50 => const Color(0xFF81516A),
    100 => const Color(0xFFB06F43),
    500 => PartyPalette.orange,
    1000 => PartyPalette.orangeSoft,
    _ => PartyPalette.orange,
  };
}

class _PollPartyTableBackground extends StatelessWidget {
  const _PollPartyTableBackground();
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(gradient: PartyPalette.backgroundGradient),
    child: Stack(
      children: [
        Positioned(
          top: -120,
          left: -80,
          child: _PollSoftOrb(
            size: 310,
            color: PartyPalette.orange,
            opacity: .11,
          ),
        ),
        Positioned(
          right: -90,
          bottom: -130,
          child: _PollSoftOrb(
            size: 360,
            color: PartyPalette.sage,
            opacity: .12,
          ),
        ),
      ],
    ),
  );
}

class _PollSoftOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  const _PollSoftOrb({
    required this.size,
    required this.color,
    required this.opacity,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: opacity),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: opacity),
          blurRadius: 80,
          spreadRadius: 28,
        ),
      ],
    ),
  );
}
