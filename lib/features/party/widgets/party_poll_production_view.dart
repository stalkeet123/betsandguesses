import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_asset_image.dart';
import '../theme/party_palette.dart';
import '../../game/widgets/poker_chip.dart';

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
  final String questionRules;
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
    required this.questionRules,
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
        const Positioned.fill(child: _PartyTableBackground()),
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
                    children: [
                      Positioned(
                        left: left,
                        top: logoTop,
                        width: leftWidth,
                        height: logoHeight,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          child: CachedAssetImage(
                            AppAssetPaths.logo,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      Positioned(
                        left: left,
                        top: timerBetTop,
                        width: leftWidth,
                        height: timerHeight,
                        child: _roundTimer(),
                      ),
                      Positioned(
                        left: left,
                        top: questionBetTop,
                        width: leftWidth,
                        height: questionBetHeight,
                        child: _questionCard(),
                      ),
                      Positioned(
                        left: left,
                        top: chipTop,
                        width: leftWidth,
                        height: chipHeight,
                        child: _chipPicker(),
                      ),
                      Positioned(
                        left: left,
                        top: playersTop,
                        width: leftWidth,
                        height: playersHeight,
                        child: _playersStrip(),
                      ),
                      Positioned(
                        left: boardLeft,
                        top: 0,
                        width: boardWidth,
                        height: height,
                        child: _partyPollBoard(),
                      ),
                    ],
                  );
                },
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
    decoration: BoxDecoration(
      color: PartyPalette.surfaceRaised.withValues(alpha: .92),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: PartyPalette.orangeSoft.withValues(alpha: .32)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 15, color: PartyPalette.orangeSoft),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: PartyPalette.cream,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: .45,
            ),
          ),
        ),
      ],
    ),
  );
  Widget _chipPicker() {
    final chips = _dynamicChips(betLimit);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
      decoration: BoxDecoration(
        color: PartyPalette.surface.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: .07),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: PartyPalette.orangeSoft.withValues(alpha: .52),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                selectedChipValue == null ? 'SELECT A CHIP' : 'TAP A BET AREA',
                style: GoogleFonts.outfit(
                  color: PartyPalette.cream.withValues(alpha: .78),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 1,
                  color: PartyPalette.orangeSoft.withValues(alpha: .52),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final chip in chips)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    child: _selectableChip(chip, availableChips >= chip),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 26,
            child: Row(
              children: [
                Expanded(child: _chipStatPill('BANK', '$score')),
                const SizedBox(width: 8),
                Expanded(child: _chipStatPill('ON TABLE', '$betTotal')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectableChip(int value, bool available) => GestureDetector(
    onTap: _selectedOwnBetId != null
        ? () => onBetRemoveRequested(_selectedOwnBetId!)
        : (available ? () => onChipSelected(value) : null),
    child: AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: selectedChipValue == value ? 1.14 : 1,
      child: Opacity(
        opacity: available ? 1 : .2,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: selectedChipValue == value
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
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: PartyPalette.orangeSoft.withValues(alpha: .28),
        width: 1,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: PartyPalette.cream.withValues(alpha: .72),
                fontSize: 8,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: .4,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: PartyPalette.orangeSoft,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    ),
  );
  List<int> _dynamicChips(int bank) {
    if (bank < 20) return const [1, 5, 10];
    if (bank < 50) return const [5, 10, 25];
    if (bank <= 150) return const [5, 10, 50];
    if (bank <= 350) return const [10, 50, 100];
    if (bank <= 1000) return const [50, 100, 500];
    return const [100, 500, 1000];
  }

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
  Widget _playersStrip() {
    final sorted = [...players]..sort((a, b) => b.score.compareTo(a.score));
    final visiblePlayers = sorted.take(3).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: PartyPalette.surface.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PartyPalette.cream.withValues(alpha: .09)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'THE ROOM',
                style: GoogleFonts.outfit(
                  color: PartyPalette.creamMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                'CHIPS',
                style: GoogleFonts.outfit(
                  color: PartyPalette.orangeSoft,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Expanded(
            child: Column(
              children: [
                for (var i = 0; i < visiblePlayers.length; i++)
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(
                        bottom: i == visiblePlayers.length - 1 ? 0 : 5,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: i == 0
                            ? PartyPalette.orange.withValues(alpha: .12)
                            : Colors.white.withValues(alpha: .035),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: i == 0
                              ? PartyPalette.orangeSoft.withValues(alpha: .24)
                              : Colors.white.withValues(alpha: .05),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${i + 1}',
                            style: GoogleFonts.outfit(
                              color: i == 0
                                  ? PartyPalette.orangeSoft
                                  : PartyPalette.blueMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              visiblePlayers[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                color: PartyPalette.cream,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${visiblePlayers[i].score}',
                            style: GoogleFonts.outfit(
                              color: PartyPalette.orangeSoft,
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
                    child: _PartyPollBetSlotSurface(
                      spec: spec,
                      isWinningReveal:
                          isReveal &&
                          winningPlayerIds.contains(spec.targetPlayerId),
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
    final gap = count <= 4 ? .020 : (count <= 6 ? .014 : .010);
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
    const chipSize = 42.0;
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
    return AnimatedPositioned(
      key: ValueKey(bet.id),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      left: globalLeft,
      top: globalTop,
      child: interactive,
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

  Widget _questionCard() => AnimatedContainer(
    duration: const Duration(milliseconds: 260),
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
            Expanded(
              child: Text(
                'GROUP POLL · EVERYONE VOTES',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: PartyPalette.orangeSoft,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          questionRules,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            color: PartyPalette.blueMuted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Center(
            child: Text(
              questionText,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: PartyPalette.cream,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
          ),
        ),
      ],
    ),
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

class _PartyPollBetSlotSurface extends StatelessWidget {
  final _PartyPollSlotSpec spec;
  final bool isWinningReveal;

  const _PartyPollBetSlotSurface({
    required this.spec,
    required this.isWinningReveal,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(spec.isGold ? 18 : 12);
    final colors = switch (spec.tone) {
      _PartyPollSlotTone.green => const [Color(0xFF2E4D3D), Color(0xFF1E3328)],
      _PartyPollSlotTone.black => const [Color(0xFF332E42), Color(0xFF211D2E)],
      _PartyPollSlotTone.gold => const [Color(0xFF43362A), Color(0xFF2C2118)],
      _PartyPollSlotTone.red => const [Color(0xFF442B31), Color(0xFF2C1B20)],
    };
    final borderColor = isWinningReveal
        ? PartyPalette.orange
        : (spec.isGold
              ? PartyPalette.orangeSoft.withValues(alpha: .55)
              : PartyPalette.orangeSoft.withValues(alpha: .25));

    return AnimatedScale(
      duration: const Duration(milliseconds: 210),
      curve: Curves.easeOutCubic,
      scale: isWinningReveal ? 1.026 : 1,
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
            color: borderColor,
            width: isWinningReveal ? 2.2 : (spec.isGold ? 1.4 : 1.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .40),
              blurRadius: isWinningReveal ? 20 : 10,
              offset: Offset(0, isWinningReveal ? 8 : 4),
            ),
            if (isWinningReveal)
              BoxShadow(
                color: PartyPalette.orange.withValues(alpha: .50),
                blurRadius: 28,
                spreadRadius: 3,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(max(4, radius.topLeft.x - 1)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 1,
                child: Container(color: Colors.white.withValues(alpha: .10)),
              ),
              if (isWinningReveal)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        PartyPalette.orangeSoft.withValues(alpha: .45),
                        PartyPalette.orange.withValues(alpha: .25),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              _PartyPollSlotLabel(spec: spec),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartyPollSlotLabel extends StatelessWidget {
  final _PartyPollSlotSpec spec;

  const _PartyPollSlotLabel({required this.spec});

  @override
  Widget build(BuildContext context) {
    final accent = spec.isGold ? PartyPalette.cream : PartyPalette.orangeSoft;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 50, 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'BET ON',
                    style: GoogleFonts.outfit(
                      color: PartyPalette.cream.withValues(alpha: .60),
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      spec.title.toUpperCase(),
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: 'RehnCondensed',
                        color: PartyPalette.cream,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: .90,
                        letterSpacing: .5,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: .75),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            right: 10,
            child: Center(
              child: Container(
                height: 26,
                constraints: const BoxConstraints(minWidth: 36),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: PartyPalette.nightDeep.withValues(alpha: .85),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: accent.withValues(alpha: .50),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .35),
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
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: .86,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartyTableBackground extends StatelessWidget {
  const _PartyTableBackground();
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(gradient: PartyPalette.backgroundGradient),
    child: Stack(
      children: [
        const Positioned(
          top: -120,
          left: -80,
          child: _SoftPartyOrb(
            size: 310,
            color: PartyPalette.orange,
            opacity: .11,
          ),
        ),
        const Positioned(
          right: -90,
          bottom: -130,
          child: _SoftPartyOrb(
            size: 360,
            color: PartyPalette.sage,
            opacity: .12,
          ),
        ),
        Positioned.fill(
          child: CustomPaint(painter: _PartyBackgroundGrainPainter()),
        ),
      ],
    ),
  );
}

class _SoftPartyOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  const _SoftPartyOrb({
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
      gradient: RadialGradient(
        colors: [
          color.withValues(alpha: opacity),
          Colors.transparent,
        ],
      ),
    ),
  );
}

class _PartyBackgroundGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: .018);
    const spacing = 26.0;
    for (double y = 8; y < size.height; y += spacing) {
      for (double x = 8; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), .65, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
