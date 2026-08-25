import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_asset_image.dart';
import '../../game/widgets/poker_chip.dart';

// Keep in sync with the reveal lead in PartyPollGameScreen.
const _revealChipEntryDurationMs = 350;
const _revealChipEntryStaggerMs = 40;
const _revealChipEntryMaxStaggerMs = 200;

class PartyPollViewPlayer {
  final String id;
  final int slotIndex;
  final String name;
  final int score;
  const PartyPollViewPlayer({
    required this.id,
    required this.slotIndex,
    required this.name,
    required this.score,
  });
}

class PartyPollViewBet {
  final String id;
  final String? bettorPlayerId;
  final String targetPlayerId;
  final int targetSlotIndex;
  final int chips;
  final double? positionX;
  final double? positionY;
  final bool? won;
  const PartyPollViewBet({
    required this.id,
    required this.targetPlayerId,
    required this.targetSlotIndex,
    required this.chips,
    this.bettorPlayerId,
    this.positionX,
    this.positionY,
    this.won,
  });
}

typedef PartyPollBetRequested =
    void Function(
      String targetPlayerId,
      int targetSlotIndex,
      double? positionX,
      double? positionY,
    );

typedef PartyPollBetMoveRequested =
    void Function(
      String betId,
      String targetPlayerId,
      int targetSlotIndex,
      double positionX,
      double positionY,
    );

class PartyPollProductionView extends StatelessWidget {
  final int roundNumber;
  final int maxRounds;
  final Duration remaining;
  final bool isReveal;
  final String questionText;
  final List<PartyPollViewPlayer> players;
  final List<PartyPollViewBet> bets;
  final Set<String> winningPlayerIds;
  final int score;
  final int betTotal;
  final int betLimit;
  final int availableChips;
  final int? selectedChipValue;
  final String? currentPlayerId;
  final String? selectedBetId;
  final bool emphasizeWinners;
  final int? activeRevealSlotIndex;
  final ValueChanged<int> onChipSelected;
  final ValueChanged<String> onBetSelected;
  final PartyPollBetRequested onBetRequested;
  final PartyPollBetMoveRequested onBetMoveRequested;
  final ValueChanged<String> onBetRemoveRequested;
  const PartyPollProductionView({
    super.key,
    required this.roundNumber,
    required this.maxRounds,
    required this.remaining,
    required this.isReveal,
    required this.questionText,
    required this.players,
    required this.bets,
    required this.winningPlayerIds,
    required this.score,
    required this.betTotal,
    required this.betLimit,
    required this.availableChips,
    required this.selectedChipValue,
    required this.currentPlayerId,
    required this.selectedBetId,
    required this.emphasizeWinners,
    required this.activeRevealSlotIndex,
    required this.onChipSelected,
    required this.onBetSelected,
    required this.onBetRequested,
    required this.onBetMoveRequested,
    required this.onBetRemoveRequested,
  });
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: CachedAssetImage(AppAssetPaths.background, fit: BoxFit.cover),
        ),
        Positioned.fill(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 50,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxHeight < 700;
                          final gapTight = isCompact ? 4.0 : 6.0;
                          final gap = isCompact ? 8.0 : 10.0;
                          final chipHeight = isCompact ? 96.0 : 102.0;
                          return KeyedSubtree(
                            key: const ValueKey('party-betting-info-column'),
                            child: Column(
                              children: [
                                Expanded(
                                  flex: isCompact ? 18 : 20,
                                  child: const CachedAssetImage(
                                    AppAssetPaths.logo,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                SizedBox(height: gapTight),
                                SizedBox(
                                  height: isCompact ? 39 : 42,
                                  child: _roundTimer(),
                                ),
                                SizedBox(height: gap),
                                Expanded(
                                  flex: isCompact ? 30 : 29,
                                  child: isReveal
                                      ? _resultRevealCard(scale: 1)
                                      : _questionCard(),
                                ),
                                SizedBox(height: gap),
                                SizedBox(
                                  height: chipHeight,
                                  child: _chipPicker(scale: 1),
                                ),
                                SizedBox(height: gap),
                                Expanded(
                                  flex: isCompact ? 24 : 26,
                                  child: _playersStrip(),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 50,
                    child: KeyedSubtree(
                      key: const ValueKey('party-betting-board-column'),
                      child: KeyedSubtree(
                        key: ValueKey('party-board-$roundNumber'),
                        child: _partyPollBoard(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _roundTimer() {
    final seconds = max(0, remaining.inSeconds);
    return Row(
      children: [
        Expanded(
          child: _infoPill(
            Icons.groups_rounded,
            'Round $roundNumber/$maxRounds',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _infoPill(
            isReveal ? Icons.emoji_events_rounded : Icons.timer_rounded,
            isReveal
                ? 'RESULT'
                : seconds > 0
                ? '0:${seconds.toString().padLeft(2, '0')}'
                : '--:--',
          ),
        ),
      ],
    );
  }

  Widget _infoPill(IconData icon, String label) => Container(
    height: 42,
    padding: const EdgeInsets.symmetric(horizontal: 9),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.feltDark.withValues(alpha: .96),
          AppColors.felt.withValues(alpha: .88),
        ],
      ),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: AppColors.brassLight.withValues(alpha: .22),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .28),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 21, color: Colors.white),
        const SizedBox(width: 6),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                height: 1,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: .45),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
  Widget _chipPicker({required double scale}) {
    const chips = [5, 10, 25];
    final usedChips = bets
        .where((bet) => bet.bettorPlayerId == currentPlayerId)
        .map((bet) => bet.chips)
        .toSet();
    final selectedId = _selectedOwnBetId;
    PartyPollViewBet? selectedBet;
    if (selectedId != null) {
      for (final bet in bets) {
        if (bet.id == selectedId) {
          selectedBet = bet;
          break;
        }
      }
    }
    final canEdit = !isReveal;
    final pickerTitle = !canEdit
        ? 'CHIPS LOCKED'
        : selectedBet != null
        ? 'TAP CHIP TO RECALL'
        : selectedChipValue == null
        ? 'SELECT A CHIP'
        : 'TAP A BET AREA';
    return AnimatedContainer(
      key: const ValueKey('party-chip-picker'),
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: selectedBet != null
            ? AppColors.feltDark.withValues(alpha: .24)
            : Colors.transparent,
        border: Border.all(
          color: selectedBet != null
              ? AppColors.brassLight
              : Colors.transparent,
          width: 1.2,
        ),
        boxShadow: [
          if (selectedBet != null)
            BoxShadow(
              color: AppColors.brassLight.withValues(alpha: .18),
              blurRadius: 12,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.brassLight.withValues(alpha: .52),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 4,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    pickerTitle,
                    maxLines: 1,
                    style: GoogleFonts.outfit(
                      color: AppColors.ivory.withValues(alpha: .78),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.brassLight.withValues(alpha: .52),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: !canEdit || selectedId == null
                  ? null
                  : () => onBetRemoveRequested(selectedId),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final chipSize = min(42.0, constraints.maxWidth / (3 * 1.14));
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final chip in chips)
                        Padding(
                          padding: EdgeInsets.zero,
                          child: _selectableChip(
                            chip,
                            canEdit && !usedChips.contains(chip),
                            size: chipSize,
                            isSelected: selectedBet != null
                                ? chip == selectedBet.chips
                                : selectedChipValue == chip,
                            canEdit: canEdit,
                            used: usedChips.contains(chip),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 26,
            child: Row(
              children: [
                Expanded(child: _chipStatPill('PROFIT', _formatProfit(score))),
                const SizedBox(width: 8),
                Expanded(
                  child: _chipStatPill(
                    'CHIPS LEFT',
                    isReveal ? '--' : '$availableChips',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectableChip(
    int value,
    bool available, {
    required double size,
    required bool isSelected,
    required bool canEdit,
    required bool used,
  }) => GestureDetector(
    onTap: !canEdit
        ? null
        : _selectedOwnBetId != null
        ? () => onBetRemoveRequested(_selectedOwnBetId!)
        : (available ? () => onChipSelected(value) : null),
    child: AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: isSelected ? 1.14 : 1,
      child: Opacity(
        opacity: available ? 1 : .2,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.brassLight.withValues(alpha: .72),
                      blurRadius: 18,
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              PokerChip(label: '$value', color: _chipColor(value), size: size),
              if (used)
                const Positioned(
                  right: -2,
                  bottom: -2,
                  child: Icon(
                    Icons.check_circle,
                    size: 13,
                    color: AppColors.ivory,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _chipStatPill(String label, String value) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .22),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: AppColors.brassLight.withValues(alpha: .28),
        width: 1,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              maxLines: 1,
              style: GoogleFonts.outfit(
                color: AppColors.ivory.withValues(alpha: .72),
                fontSize: 8,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: .25,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              value,
              maxLines: 1,
              style: GoogleFonts.outfit(
                color: AppColors.brassLight,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Color _chipColor(int value) => switch (value) {
    5 => AppColors.feltLight,
    10 => AppColors.neonBlue,
    25 => AppColors.neonCyan,
    _ => AppColors.brass,
  };

  String _formatProfit(int value) => value > 0 ? '+$value' : '$value';

  Widget _playersStrip() {
    final sorted = [...players]..sort((a, b) => b.score.compareTo(a.score));
    final visiblePlayers = sorted.take(3).toList();
    return Container(
      key: const ValueKey('party-leaderboard'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.feltDark.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.brass.withValues(alpha: .42),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .28),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.brassLight.withValues(alpha: .34),
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                flex: 8,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'LEADERBOARD',
                        style: GoogleFonts.outfit(
                          color: AppColors.ivory.withValues(alpha: .78),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'PROFIT',
                        style: GoogleFonts.outfit(
                          color: AppColors.brassLight.withValues(alpha: .72),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .8,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.brassLight.withValues(alpha: .34),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Column(
              children: [
                const SizedBox(height: 6),
                for (var i = 0; i < visiblePlayers.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: i == visiblePlayers.length - 1 ? 0 : 5,
                      ),
                      child: _leaderboardRow(visiblePlayers[i], i),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaderboardRow(PartyPollViewPlayer player, int index) {
    final isWinner = emphasizeWinners && winningPlayerIds.contains(player.id);
    final isLeader = index == 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: isWinner
            ? AppColors.neonGreen.withValues(alpha: .16)
            : isLeader
            ? AppColors.brassLight.withValues(alpha: .13)
            : Colors.black.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isWinner
              ? AppColors.neonGreen.withValues(alpha: .62)
              : isLeader
              ? AppColors.brassLight.withValues(alpha: .42)
              : Colors.white.withValues(alpha: .08),
          width: isWinner ? 1.3 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '#${index + 1}',
              style: GoogleFonts.outfit(
                color: isLeader ? AppColors.brassLight : AppColors.ivory,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: AppColors.ivory,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatProfit(player.score),
            maxLines: 1,
            style: GoogleFonts.outfit(
              color: isWinner ? AppColors.neonGreen : AppColors.brassLight,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 1,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: .48),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? get _selectedOwnBetId {
    final id = selectedBetId;
    if (id == null || currentPlayerId == null) return null;
    for (final bet in bets) {
      if (bet.id == id && bet.bettorPlayerId == currentPlayerId) return id;
    }
    return null;
  }

  Widget _partyPollBoard() {
    final boardPlayers = [...players]
      ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
    final specs = _partyPollSlotsFor(boardPlayers);
    final orderedSpecs = [
      ...specs.where((slot) => !slot.isGold),
      ...specs.where((slot) => slot.isGold),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boardSize = Size(constraints.maxWidth, constraints.maxHeight);
          final winningSpecs = specs
              .where(
                (spec) =>
                    spec.targetPlayerId.isNotEmpty &&
                    winningPlayerIds.contains(spec.targetPlayerId),
              )
              .toList();
          final showRevealEffects = isReveal && emphasizeWinners;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (final spec in orderedSpecs)
                Positioned(
                  left: spec.rect.left * boardSize.width,
                  top: spec.rect.top * boardSize.height,
                  width: spec.rect.width * boardSize.width,
                  height: spec.rect.height * boardSize.height,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) => _handlePollSlotTap(
                      spec,
                      details.localPosition,
                      Size(
                        spec.rect.width * boardSize.width,
                        spec.rect.height * boardSize.height,
                      ),
                    ),
                    child: _ClassicPollBetSlotSurface(
                      spec: spec,
                      isWinningReveal:
                          (isReveal &&
                              activeRevealSlotIndex == spec.targetSlotIndex) ||
                          (isReveal &&
                              emphasizeWinners &&
                              winningPlayerIds.contains(spec.targetPlayerId)),
                    ),
                  ),
                ),
              Positioned.fill(child: _placedPollChips(specs, boardSize)),
              if (showRevealEffects && winningSpecs.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (final spec in winningSpecs)
                          ..._pollWinParticles(boardSize, spec),
                      ],
                    ),
                  ),
                ),
              if (showRevealEffects && winningSpecs.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: _pollPayoutFlightChips(specs, boardSize),
                    ),
                  ),
                ),
              if (showRevealEffects && winningSpecs.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: _pollWinnerOverlay(winningSpecs, boardSize),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _pollWinParticles(Size boardSize, _PartyPollSlotSpec spec) {
    final center = Offset(
      (spec.rect.left + spec.rect.width * .5) * boardSize.width,
      (spec.rect.top + spec.rect.height * .5) * boardSize.height,
    );
    return [
      for (var i = 0; i < 12; i++)
        Positioned(
          left: center.dx + cos(i * pi / 6) * 12,
          top: center.dy + sin(i * pi / 6) * 8,
          child:
              Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i.isEven ? AppColors.brassLight : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brassLight.withValues(alpha: .55),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  )
                  .animate(delay: (i * 35).ms)
                  .fadeOut(duration: 900.ms)
                  .move(
                    begin: Offset.zero,
                    end: Offset(cos(i * pi / 6) * 34, sin(i * pi / 6) * 26),
                    duration: 900.ms,
                    curve: Curves.easeOutCubic,
                  ),
        ),
    ];
  }

  List<Widget> _pollPayoutFlightChips(
    List<_PartyPollSlotSpec> specs,
    Size boardSize,
  ) {
    final tokens = <_PollPayoutToken>[];
    var order = 0;
    for (final bet in bets.where((bet) => bet.won == true)) {
      _PartyPollSlotSpec? spec;
      for (final candidate in specs) {
        if (candidate.targetSlotIndex == bet.targetSlotIndex &&
            (candidate.targetPlayerId.isEmpty ||
                candidate.targetPlayerId == bet.targetPlayerId)) {
          spec = candidate;
          break;
        }
      }
      if (spec == null) continue;
      final visualChipCount = min(spec.odds, 4);
      for (var token = 0; token < visualChipCount && order < 18; token++) {
        tokens.add(
          _PollPayoutToken(bet: bet, spec: spec, token: token, order: order),
        );
        order++;
      }
      if (order >= 18) break;
    }
    final chipSize = (boardSize.width * .095).clamp(28.0, 36.0).toDouble();
    return [
      for (final item in tokens)
        _pollPayoutFlightChip(item, boardSize, chipSize),
    ];
  }

  Widget _pollPayoutFlightChip(
    _PollPayoutToken item,
    Size boardSize,
    double chipSize,
  ) {
    final center = Offset(
      (item.spec.rect.left + item.spec.rect.width * .5) * boardSize.width,
      (item.spec.rect.top + item.spec.rect.height * .5) * boardSize.height,
    );
    final angle = -pi / 2 + item.order * .72;
    final radius = 14.0 + (item.order % 3) * 7.0;
    final start = center + Offset(cos(angle) * radius, sin(angle) * radius);
    final leaderboardTargetY = boardSize.height * .82;
    final flyOffset = Offset(
      -boardSize.width * 1.04 - (item.order % 4) * 12,
      leaderboardTargetY - start.dy + ((item.order % 5) - 2) * 5,
    );
    final delayMs = 150 + item.order * 42;
    final flightMs = 1040 + (item.order % 4) * 45;
    final duration = Duration(milliseconds: delayMs + flightMs);

    return Positioned(
      left: start.dx - chipSize / 2,
      top: start.dy - chipSize / 2,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(
          'payout-flight-${item.bet.id}-${item.token}-${item.spec.odds}',
        ),
        tween: Tween<double>(begin: 0, end: 1),
        duration: duration,
        curve: Curves.linear,
        builder: (context, rawProgress, child) {
          final delayedProgress =
              ((rawProgress * duration.inMilliseconds) - delayMs) / flightMs;
          if (delayedProgress <= 0) return const SizedBox.shrink();
          final progress = delayedProgress.clamp(0.0, 1.0).toDouble();
          final launch = ((progress - .34) / .66).clamp(0.0, 1.0);
          final pop = (progress / .30).clamp(0.0, 1.0);
          final launchCurve = Curves.easeInOutCubic.transform(launch);
          final popCurve = Curves.easeOutBack.transform(pop).clamp(0.0, 1.12);
          final floatLift = sin(min(progress, .34) / .34 * pi) * -9;
          final opacity = launch < .78
              ? 1.0
              : (1 - ((launch - .78) / .22)).clamp(0.0, 1.0);
          final scale = launch == 0
              ? .66 + .39 * popCurve
              : (1.05 - .80 * Curves.easeInCubic.transform(launch)).clamp(
                  .22,
                  1.08,
                );
          return Opacity(
            opacity: opacity.toDouble(),
            child: Transform.translate(
              offset: Offset(
                flyOffset.dx * launchCurve,
                floatLift + flyOffset.dy * launchCurve,
              ),
              child: Transform.scale(scale: scale.toDouble(), child: child),
            ),
          );
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.brassLight.withValues(alpha: .42),
                blurRadius: 10,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: .30),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: PokerChip(
            label: '${item.bet.chips}',
            color: _chipColor(item.bet.chips),
            size: chipSize,
            isScoreChip: false,
          ),
        ),
      ),
    );
  }

  Widget _pollWinnerOverlay(
    List<_PartyPollSlotSpec> winningSpecs,
    Size boardSize,
  ) {
    final winningPlayers = players
        .where((player) => winningPlayerIds.contains(player.id))
        .toList();
    if (winningPlayers.isEmpty) return const SizedBox.shrink();
    final names = winningPlayers.map((player) => player.name).join(' · ');
    final isTie = winningPlayers.length > 1;
    final slot = winningSpecs.length == 1 ? winningSpecs.single : null;
    final overlay =
        Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.ivory.withValues(alpha: .96),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: AppColors.brassLight.withValues(alpha: .9),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .65),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isTie ? 'WINNERS' : 'WINNER',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: AppColors.mahoganyDark.withValues(alpha: .8),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      names,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: GoogleFonts.outfit(
                        color: AppColors.feltDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            )
            .animate(delay: 1100.ms)
            .fadeIn(duration: 400.ms)
            .scale(
              begin: const Offset(.85, .85),
              curve: Curves.easeOutBack,
              duration: 500.ms,
            );
    if (slot == null) return Center(child: overlay);
    return Stack(
      children: [
        Positioned(
          left: slot.rect.left * boardSize.width,
          width: slot.rect.width * boardSize.width,
          top: slot.rect.top * boardSize.height,
          height: slot.rect.height * boardSize.height,
          child: Center(child: overlay),
        ),
      ],
    );
  }

  List<_PartyPollSlotSpec> _partyPollSlotsFor(
    List<PartyPollViewPlayer> boardPlayers,
  ) {
    final count = boardPlayers.isEmpty ? 4 : boardPlayers.length.clamp(2, 8);
    const tones = [
      _PartyPollSlotTone.green,
      _PartyPollSlotTone.black,
      _PartyPollSlotTone.gold,
      _PartyPollSlotTone.red,
      _PartyPollSlotTone.green,
      _PartyPollSlotTone.black,
      _PartyPollSlotTone.gold,
      _PartyPollSlotTone.red,
    ];
    final gap = count <= 4 ? .014 : (count <= 6 ? .010 : .008);
    final slotHeight = (.960 - (count - 1) * gap) / count;

    return List.generate(count, (rowIndex) {
      final player = rowIndex < boardPlayers.length
          ? boardPlayers[rowIndex]
          : null;
      return _PartyPollSlotSpec(
        rowIndex: rowIndex,
        targetPlayerId: player?.id ?? '',
        targetSlotIndex: player?.slotIndex ?? rowIndex,
        title: player?.name ?? 'PLAYER ${rowIndex + 1}',
        odds: 2,
        tone: tones[rowIndex % tones.length],
        rect: Rect.fromLTWH(
          .040,
          .015 + rowIndex * (slotHeight + gap),
          .920,
          slotHeight,
        ),
      );
    });
  }

  void _handlePollSlotTap(
    _PartyPollSlotSpec spec,
    Offset localPosition,
    Size slotSize,
  ) {
    if (isReveal ||
        spec.targetPlayerId.isEmpty ||
        slotSize.width <= 0 ||
        slotSize.height <= 0) {
      return;
    }
    final positionX = (localPosition.dx / slotSize.width)
        .clamp(.12, .88)
        .toDouble();
    final positionY = (localPosition.dy / slotSize.height)
        .clamp(.18, .82)
        .toDouble();
    final selectedId = selectedBetId;
    if (selectedId != null) {
      PartyPollViewBet? selectedBet;
      for (final bet in bets) {
        if (bet.id == selectedId) {
          selectedBet = bet;
          break;
        }
      }
      if (selectedBet == null ||
          selectedBet.bettorPlayerId != currentPlayerId) {
        return;
      }
      onBetMoveRequested(
        selectedBet.id,
        spec.targetPlayerId,
        spec.targetSlotIndex,
        positionX,
        positionY,
      );
      return;
    }
    if (selectedChipValue == null || selectedChipValue! > availableChips) {
      return;
    }
    onBetRequested(
      spec.targetPlayerId,
      spec.targetSlotIndex,
      positionX,
      positionY,
    );
  }

  Widget _placedPollChips(List<_PartyPollSlotSpec> specs, Size boardSize) {
    if (bets.isEmpty) return const SizedBox.shrink();
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        for (var index = 0; index < bets.length; index++)
          _positionedPollChip(bets[index], index, specs, boardSize),
      ],
    );
  }

  Widget _positionedPollChip(
    PartyPollViewBet bet,
    int index,
    List<_PartyPollSlotSpec> specs,
    Size boardSize,
  ) {
    _PartyPollSlotSpec? spec;
    for (final candidate in specs) {
      if (candidate.targetSlotIndex == bet.targetSlotIndex) {
        spec = candidate;
        break;
      }
    }
    if (spec == null ||
        (spec.targetPlayerId.isNotEmpty &&
            spec.targetPlayerId != bet.targetPlayerId)) {
      return const SizedBox.shrink();
    }
    final chipSize = min(42.0, boardSize.width * .27);
    final fallbackX = .5 + ((index % 3) - 1) * .14;
    final fallbackY = .52 + ((index ~/ 3) % 2) * .16;
    final slotLocalX = bet.positionX ?? fallbackX;
    final slotLocalY = bet.positionY ?? fallbackY;
    final slotWidth = spec.rect.width * boardSize.width;
    final slotHeight = spec.rect.height * boardSize.height;
    // No clamping so the chip stays physically exactly where dropped.
    final globalLeft =
        spec.rect.left * boardSize.width +
        (slotLocalX * slotWidth - chipSize / 2);
    final globalTop =
        spec.rect.top * boardSize.height +
        (slotLocalY * slotHeight - chipSize / 2);
    final isOwnBet =
        currentPlayerId != null && bet.bettorPlayerId == currentPlayerId;
    final isSelected = isOwnBet && selectedBetId == bet.id;
    final resultSettled = isReveal && emphasizeWinners;
    final chip = _placedPollChipVisual(
      bet,
      chipSize,
      isOwnBet: isOwnBet,
      resultSettled: resultSettled,
    );
    final visual = AnimatedScale(
      duration: const Duration(milliseconds: 150),
      key: ValueKey('placed-bet-chip-${bet.id}'),
      curve: Curves.easeOutCubic,
      scale: isSelected ? 1.15 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.brassLight.withValues(alpha: .95),
                blurRadius: 22,
                spreadRadius: 4,
              ),
          ],
        ),
        child: chip,
      ),
    );
    final interactive = isOwnBet && !isReveal
        ? GestureDetector(onTap: () => onBetSelected(bet.id), child: visual)
        : IgnorePointer(child: visual);
    final opponentRevealIndex = bets
        .take(index)
        .where((candidate) => candidate.bettorPlayerId != currentPlayerId)
        .length;
    final revealedOpponent =
        isReveal &&
            !isOwnBet &&
            !WidgetsBinding
                .instance
                .platformDispatcher
                .accessibilityFeatures
                .disableAnimations
        ? interactive
              .animate(
                key: ValueKey('reveal-chip-$roundNumber-${bet.id}'),
                delay: Duration(
                  milliseconds: min(
                    _revealChipEntryMaxStaggerMs,
                    opponentRevealIndex * _revealChipEntryStaggerMs,
                  ),
                ),
              )
              .fadeIn(
                duration: _revealChipEntryDurationMs.ms,
                curve: Curves.easeOutCubic,
              )
              .moveX(
                begin: -min(150.0, boardSize.width * .55),
                end: 0,
                duration: _revealChipEntryDurationMs.ms,
                curve: Curves.easeOutCubic,
              )
              .scale(
                begin: const Offset(.76, .76),
                end: const Offset(1, 1),
                duration: _revealChipEntryDurationMs.ms,
                curve: Curves.easeOutCubic,
              )
        : interactive;
    return AnimatedPositioned(
      key: ValueKey(bet.id),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      left: globalLeft,
      top: globalTop,
      child: revealedOpponent,
    );
  }

  Widget _placedPollChipVisual(
    PartyPollViewBet bet,
    double chipSize, {
    required bool isOwnBet,
    required bool resultSettled,
  }) {
    Widget chip = PokerChip(
      label: '${bet.chips}',
      color: _chipColor(bet.chips),
      size: chipSize,
      isScoreChip: false,
    );
    if (isOwnBet) {
      chip = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          chip,
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.neonRed,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonRed.withValues(alpha: .6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    if (resultSettled && bet.won == false) {
      return _dissolvingPollChipVisual(chip, bet.id, chipSize);
    }
    if (!(resultSettled && bet.won == true)) return chip;
    return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.brassLight.withValues(alpha: .62),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: chip,
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scale(
          end: const Offset(1.12, 1.12),
          duration: 420.ms,
          curve: Curves.easeInOut,
        );
  }

  Widget _dissolvingPollChipVisual(Widget chip, String betId, double size) {
    const particleColor = Color(0xFFFFE8A3);
    const particleOffsets = [
      Offset(-15, -14),
      Offset(13, -18),
      Offset(-18, 4),
      Offset(17, 8),
      Offset(-8, 18),
      Offset(9, 15),
    ];
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          chip
              .animate(key: ValueKey('chip-dust-body-$betId'))
              .fadeOut(delay: 260.ms, duration: 620.ms)
              .scale(
                end: const Offset(.62, .62),
                delay: 180.ms,
                duration: 700.ms,
                curve: Curves.easeInCubic,
              )
              .moveY(
                end: -9,
                delay: 180.ms,
                duration: 700.ms,
                curve: Curves.easeOutCubic,
              ),
          for (var i = 0; i < particleOffsets.length; i++)
            Positioned(
              left: size / 2 - 3,
              top: size / 2 - 3,
              child:
                  Container(
                        width: i.isEven ? 5 : 4,
                        height: i.isEven ? 5 : 4,
                        decoration: BoxDecoration(
                          color: particleColor.withValues(alpha: .72),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: particleColor.withValues(alpha: .35),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      )
                      .animate(key: ValueKey('chip-dust-$betId-$i'))
                      .fadeIn(delay: (210 + i * 28).ms, duration: 70.ms)
                      .fadeOut(delay: (330 + i * 28).ms, duration: 440.ms)
                      .move(
                        end: particleOffsets[i],
                        delay: (230 + i * 28).ms,
                        duration: 560.ms,
                        curve: Curves.easeOutCubic,
                      )
                      .scale(
                        end: const Offset(.2, .2),
                        delay: (330 + i * 28).ms,
                        duration: 460.ms,
                      ),
            ),
        ],
      ),
    );
  }

  Widget _questionCard() => LayoutBuilder(
    builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 160;
      final horizontalPadding = isNarrow ? 10.0 : 18.0;
      final verticalPadding = isNarrow ? 9.0 : 14.0;
      final headerGap = isNarrow ? 5.0 : 8.0;
      final iconSize = isNarrow ? 10.0 : 12.0;

      return Container(
        key: const ValueKey('party-question-card'),
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFBF1), Color(0xFFF6E7C9), Color(0xFFFFFCF4)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.ivory.withValues(alpha: .92),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.brass.withValues(alpha: .24),
              blurRadius: 0,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: .28),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    color: AppColors.brass.withValues(alpha: .52),
                  ),
                ),
                SizedBox(width: headerGap),
                Icon(
                  Icons.how_to_vote_rounded,
                  size: iconSize,
                  color: AppColors.felt,
                ),
                SizedBox(width: headerGap),
                Flexible(
                  flex: 3,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'POLL',
                      maxLines: 1,
                      style: GoogleFonts.outfit(
                        color: AppColors.felt,
                        fontSize: isNarrow ? 12 : 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: headerGap),
                Icon(
                  Icons.how_to_vote_rounded,
                  size: iconSize,
                  color: AppColors.felt,
                ),
                SizedBox(width: headerGap),
                Expanded(
                  child: Container(
                    height: 1,
                    color: AppColors.brass.withValues(alpha: .52),
                  ),
                ),
              ],
            ),
            SizedBox(height: isNarrow ? 6 : 10),
            Expanded(
              child: _AdaptiveQuestionText(
                text: questionText,
                color: const Color(0xFF0A2C59),
                minFontSize: 16,
                fallbackMinFontSize: 12,
                maxFontSize: 34,
              ),
            ),
          ],
        ),
      );
    },
  );
  Widget _resultRevealCard({required double scale}) {
    final resultGlowSize = (108 * scale).clamp(78.0, 118.0).toDouble();
    final resultSettled = isReveal && emphasizeWinners;
    final orderedPlayers = [...players]
      ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
    final winners = orderedPlayers
        .where((player) => winningPlayerIds.contains(player.id))
        .toList(growable: false);
    final answerText = !resultSettled
        ? '--'
        : winners.isEmpty
        ? 'MAJORITY PICK'
        : winners.map((player) => player.name.toUpperCase()).join(' · ');
    final ownBets = bets
        .where((bet) => bet.bettorPlayerId == currentPlayerId)
        .toList(growable: false);
    final netProfit = ownBets.fold<int>(
      0,
      (total, bet) => total + (bet.won == true ? bet.chips : -bet.chips),
    );
    final didWin = resultSettled && netProfit > 0;
    final accent = didWin ? AppColors.chipGold : AppColors.brassLight;
    final banner = !resultSettled
        ? 'LOCKING RESULT'
        : netProfit > 0
        ? 'YOU WON +$netProfit'
        : netProfit < 0
        ? 'YOU LOST -${netProfit.abs()}'
        : 'BREAK EVEN';
    final headlineColor = didWin ? AppColors.mahoganyDark : Colors.white;
    return AnimatedContainer(
          key: ValueKey('party-result-$roundNumber'),
          duration: const Duration(milliseconds: 280),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: didWin
                  ? const [
                      Color(0xFFFFF8D4),
                      Color(0xFFFFC833),
                      Color(0xFFFFF5B8),
                    ]
                  : const [
                      Color(0xFF13040A),
                      Color(0xFF5B0F1A),
                      Color(0xFF23060B),
                    ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: didWin ? Colors.white : AppColors.brassLight,
              width: didWin ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: resultSettled ? .46 : .28),
                blurRadius: resultSettled ? 28 : 18,
                spreadRadius: resultSettled ? 2 : 0,
              ),
              if (!resultSettled)
                BoxShadow(
                  color: AppColors.burgundy.withValues(alpha: .38),
                  blurRadius: 24,
                  spreadRadius: -3,
                  offset: const Offset(0, 8),
                ),
              BoxShadow(
                color: Colors.black.withValues(alpha: .34),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'RESULT',
                style: GoogleFonts.outfit(
                  color: didWin
                      ? AppColors.mahoganyDark.withValues(alpha: .72)
                      : AppColors.brassLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                            width: resultGlowSize,
                            height: resultGlowSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  accent.withValues(alpha: .34),
                                  accent.withValues(alpha: .03),
                                ],
                              ),
                            ),
                          )
                          .animate(target: resultSettled ? 1 : 0)
                          .scale(
                            begin: const Offset(.92, .92),
                            end: const Offset(1.12, 1.12),
                            duration: 420.ms,
                            curve: Curves.easeOutCubic,
                          ),
                      FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              answerText,
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: 'RehnCondensed',
                                color: headlineColor,
                                fontSize: 76,
                                fontWeight: FontWeight.w900,
                                height: .86,
                                shadows: [
                                  Shadow(
                                    color: didWin
                                        ? Colors.white.withValues(alpha: .9)
                                        : Colors.black,
                                    blurRadius: didWin ? 6 : 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .animate(target: resultSettled ? 1 : 0)
                          .shake(duration: 420.ms, hz: 5),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: didWin
                      ? Colors.white.withValues(alpha: .58)
                      : Colors.black.withValues(alpha: .26),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: didWin
                        ? AppColors.mahoganyDark.withValues(alpha: .26)
                        : AppColors.brassLight.withValues(alpha: .52),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    banner,
                    maxLines: 1,
                    style: GoogleFonts.outfit(
                      color: didWin ? AppColors.mahoganyDark : Colors.white,
                      fontSize: resultSettled ? 18 : 14,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: resultSettled ? 0 : .8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        )
        .animate(key: ValueKey('answer-$roundNumber-$resultSettled'))
        .fadeIn(duration: 180.ms)
        .scale(begin: const Offset(.97, .97), duration: 260.ms);
  }
}

class _AdaptiveQuestionText extends StatelessWidget {
  final String text;
  final Color color;
  final double minFontSize;
  final double fallbackMinFontSize;
  final double maxFontSize;
  const _AdaptiveQuestionText({
    required this.text,
    required this.color,
    required this.minFontSize,
    required this.fallbackMinFontSize,
    required this.maxFontSize,
  });

  TextStyle _style(double fontSize) => TextStyle(
    fontFamily: 'RehnCondensed',
    color: color,
    fontSize: fontSize,
    fontWeight: FontWeight.w900,
    height: 1.12,
  );

  StrutStyle _strut(double fontSize) => StrutStyle(
    fontFamily: 'RehnCondensed',
    fontSize: fontSize,
    forceStrutHeight: true,
    height: 1.12,
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
        return const SizedBox.shrink();
      }

      bool fits(double fontSize) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: _style(fontSize)),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.noScaling,
          strutStyle: _strut(fontSize),
        )..layout(maxWidth: constraints.maxWidth);
        return painter.height <= constraints.maxHeight;
      }

      final preferredMinimumFits = fits(minFontSize);
      final fallbackMinimumFits = fits(fallbackMinFontSize);
      if (!fallbackMinimumFits) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: constraints.maxWidth,
            child: Text(
              text,
              textAlign: TextAlign.center,
              softWrap: true,
              textScaler: TextScaler.noScaling,
              strutStyle: _strut(fallbackMinFontSize),
              style: _style(fallbackMinFontSize),
            ),
          ),
        );
      }

      var low = preferredMinimumFits ? minFontSize : fallbackMinFontSize;
      var high = maxFontSize;
      for (var i = 0; i < 10; i++) {
        final candidate = (low + high) / 2;
        if (fits(candidate)) {
          low = candidate;
        } else {
          high = candidate;
        }
      }

      return Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          softWrap: true,
          textScaler: TextScaler.noScaling,
          strutStyle: _strut(low),
          style: _style(low),
        ),
      );
    },
  );
}

class _PollPayoutToken {
  final PartyPollViewBet bet;
  final _PartyPollSlotSpec spec;
  final int token;
  final int order;

  const _PollPayoutToken({
    required this.bet,
    required this.spec,
    required this.token,
    required this.order,
  });
}

class _PartyPollSlotSpec {
  final int rowIndex;
  final String targetPlayerId;
  final int targetSlotIndex;
  final String title;
  final int odds;
  final _PartyPollSlotTone tone;
  final Rect rect;

  const _PartyPollSlotSpec({
    required this.rowIndex,
    required this.targetPlayerId,
    required this.targetSlotIndex,
    required this.title,
    required this.odds,
    required this.tone,
    required this.rect,
  });

  bool get isGold => tone == _PartyPollSlotTone.gold;
}

enum _PartyPollSlotTone { green, black, gold, red }

class _ClassicPollBetSlotSurface extends StatelessWidget {
  final _PartyPollSlotSpec spec;
  final bool isWinningReveal;

  const _ClassicPollBetSlotSurface({
    required this.spec,
    required this.isWinningReveal,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(spec.isGold ? 18 : 12);
    Widget surface = AnimatedScale(
      duration: const Duration(milliseconds: 210),
      curve: Curves.easeOutCubic,
      scale: isWinningReveal ? 1.026 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .42),
              blurRadius: isWinningReveal ? 22 : 9,
              offset: Offset(0, isWinningReveal ? 8 : 5),
            ),
            if (isWinningReveal)
              BoxShadow(
                color: AppColors.brassLight.withValues(alpha: .96),
                blurRadius: 36,
                spreadRadius: 6,
              ),
            if (isWinningReveal)
              BoxShadow(
                color: Colors.white.withValues(alpha: .58),
                blurRadius: 20,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Container(
          padding: EdgeInsets.all(spec.isGold ? 3 : 2.5),
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: _outerRailGradient,
          ),
          child: Container(
            padding: EdgeInsets.all(spec.isGold ? 3 : 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(spec.isGold ? 15 : 8),
              color: spec.isGold
                  ? AppColors.chipGold.withValues(alpha: .35)
                  : AppColors.ivory,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(spec.isGold ? 12 : 6),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedAssetImage(
                    _textureAsset(spec.tone),
                    fit: spec.isGold ? BoxFit.fill : BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                  if (isWinningReveal)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: .54),
                            AppColors.chipGold.withValues(alpha: .38),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isWinningReveal
                            ? Colors.white.withValues(alpha: .82)
                            : Colors.white.withValues(
                                alpha: spec.isGold ? .34 : .16,
                              ),
                        width: isWinningReveal ? 2 : (spec.isGold ? 1.2 : 1),
                      ),
                      borderRadius: BorderRadius.circular(spec.isGold ? 12 : 6),
                    ),
                    child: const SizedBox.expand(),
                  ),
                  _PartyPollSlotLabel(spec: spec),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!isWinningReveal) return surface;
    return surface
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .shimmer(color: Colors.white.withValues(alpha: .38), duration: 1800.ms);
  }

  static const LinearGradient _outerRailGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF8F4E9),
      Color(0xFF4B3D32),
      Color(0xFFFFFDF5),
      Color(0xFF6B5647),
    ],
  );

  static String _textureAsset(_PartyPollSlotTone tone) => switch (tone) {
    _PartyPollSlotTone.red => AppAssetPaths.boardRed,
    _PartyPollSlotTone.black => AppAssetPaths.boardBlack,
    _PartyPollSlotTone.green => AppAssetPaths.boardGreen,
    _PartyPollSlotTone.gold => AppAssetPaths.boardGold,
  };
}

class _PartyPollSlotLabel extends StatelessWidget {
  final _PartyPollSlotSpec spec;

  const _PartyPollSlotLabel({required this.spec});

  @override
  Widget build(BuildContext context) {
    final accent = spec.isGold ? AppColors.ivory : AppColors.brassLight;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 7, 50, 4),
              child: Align(
                alignment: Alignment.topLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topLeft,
                  child: Stack(
                    alignment: Alignment.topLeft,
                    children: [
                      Text(
                        spec.title.toUpperCase(),
                        maxLines: 1,
                        style: GoogleFonts.rye(
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = spec.isGold ? 2.6 : 3.2
                            ..color =
                                (spec.isGold
                                        ? AppColors.brassLight
                                        : AppColors.feltDark)
                                    .withValues(alpha: spec.isGold ? .72 : .78),
                          fontSize: 27,
                          fontWeight: FontWeight.w400,
                          height: .95,
                        ),
                      ),
                      Text(
                        spec.title.toUpperCase(),
                        maxLines: 1,
                        style: GoogleFonts.rye(
                          color: spec.isGold
                              ? AppColors.mahoganyDark
                              : AppColors.ivory,
                          fontSize: 27,
                          fontWeight: FontWeight.w400,
                          height: .95,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(
                                alpha: spec.isGold ? .28 : .75,
                              ),
                              blurRadius: spec.isGold ? 2 : 7,
                              offset: const Offset(0, 2),
                            ),
                            if (spec.isGold)
                              Shadow(
                                color: AppColors.brassLight.withValues(
                                  alpha: .34,
                                ),
                                blurRadius: 9,
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
          Positioned(
            right: 8,
            bottom: 7,
            child: Container(
              height: 22,
              constraints: const BoxConstraints(minWidth: 32),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.mahoganyDark.withValues(alpha: .86),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: accent.withValues(alpha: .58),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '${spec.odds}X',
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'RehnCondensed',
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: .86,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
