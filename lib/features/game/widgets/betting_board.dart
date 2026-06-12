import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/game_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../models/bet_model.dart';
import '../models/guess_model.dart';
import 'poker_chip.dart';
import 'springy_chip.dart';

class BettingBoard extends StatelessWidget {
  final List<Guess> guesses;
  final List<Bet> bets;
  final RoundPhase phase;
  final int? correctAnswer;
  final String? winningGuessId;
  final String currentPlayerId;
  final bool isLocked;
  final Function(int slotIndex, int chips) onPlaceBet;
  final Function(int slotIndex) onRemoveBet;

  const BettingBoard({
    super.key,
    required this.guesses,
    required this.bets,
    required this.phase,
    this.correctAnswer,
    this.winningGuessId,
    required this.currentPlayerId,
    required this.isLocked,
    required this.onPlaceBet,
    required this.onRemoveBet,
  });

  @override
  Widget build(BuildContext context) {
    final canBet = phase == RoundPhase.betting && !isLocked;
    final showGuesses = phase == RoundPhase.betting ||
        phase == RoundPhase.revealAnswer ||
        phase == RoundPhase.scoring;
    final slots = _buildSlots();

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: AppColors.tableDecoration(borderRadius: 34),
            child: CustomPaint(painter: _FeltPatternPainter()),
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              children: [
                _buildBoardHeader(context),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < slots.length; i++) ...[
                        Expanded(
                          child: _BettingLane(
                            slot: slots[i],
                            bets: bets.where((b) => b.slotIndex == slots[i].index).toList(),
                            phase: phase,
                            canBet: canBet,
                            showGuesses: showGuesses,
                            isLocked: isLocked,
                            isWinning: _isWinningSlot(slots[i].index),
                            hasMyBet: bets.any(
                              (b) => b.slotIndex == slots[i].index && b.playerId == currentPlayerId,
                            ),
                            currentPlayerId: currentPlayerId,
                            onPlaceBet: onPlaceBet,
                            onRemoveBet: onRemoveBet,
                          ),
                        ),
                        if (i != slots.length - 1) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 420.ms).scale(begin: const Offset(0.985, 0.985));
  }

  Widget _buildBoardHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.mahoganyDark.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.brass.withValues(alpha: 0.5)),
          ),
          child: Text(
            'WITS & WAGERS TABLE',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.brassLight,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
        ),
        const Spacer(),
        Text(
          phase == RoundPhase.betting
              ? (isLocked ? 'Bets locked' : 'Drag chips onto an odds lane')
              : 'Guesses resolve left to right',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.ivory.withValues(alpha: 0.72),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  List<_SlotData> _buildSlots() {
    final slots = <_SlotData>[
      _SlotData(
        index: 0,
        odds: GameConstants.boardOdds[0],
        label: 'SMALLER',
        subtitle: 'than every guess',
        isEdge: true,
      ),
    ];

    for (var i = 0; i < GameConstants.maxGuessSlots; i++) {
      final guess = i < guesses.length ? guesses[i] : null;
      slots.add(
        _SlotData(
          index: i + 1,
          odds: GameConstants.boardOdds[i + 1],
          label: guess != null ? Helpers.formatNumber(guess.value) : '--',
          subtitle: guess?.playerName ?? 'waiting',
          guess: guess,
          isEdge: false,
        ),
      );
    }

    slots.add(
      _SlotData(
        index: 6,
        odds: GameConstants.boardOdds[6],
        label: 'LARGER',
        subtitle: 'than every guess',
        isEdge: true,
      ),
    );
    return slots;
  }

  bool _isWinningSlot(int slotIndex) {
    if (correctAnswer == null || winningGuessId == null) return false;
    final winnerIdx = guesses.indexWhere((g) => g.id == winningGuessId);
    if (winnerIdx < 0) return slotIndex == 0;
    return slotIndex == winnerIdx + 1;
  }
}

class _BettingLane extends StatelessWidget {
  final _SlotData slot;
  final List<Bet> bets;
  final RoundPhase phase;
  final bool canBet;
  final bool showGuesses;
  final bool isLocked;
  final bool isWinning;
  final bool hasMyBet;
  final String currentPlayerId;
  final Function(int slotIndex, int chips) onPlaceBet;
  final Function(int slotIndex) onRemoveBet;

  const _BettingLane({
    required this.slot,
    required this.bets,
    required this.phase,
    required this.canBet,
    required this.showGuesses,
    required this.isLocked,
    required this.isWinning,
    required this.hasMyBet,
    required this.currentPlayerId,
    required this.onPlaceBet,
    required this.onRemoveBet,
  });

  @override
  Widget build(BuildContext context) {
    final oddsColor = AppColors.getOddsColor(slot.odds);
    final revealDim = phase == RoundPhase.revealAnswer && !isWinning;
    final myTotal = bets
        .where((b) => b.playerId == currentPlayerId)
        .fold<int>(0, (sum, bet) => sum + bet.chips);

    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => canBet,
      onAcceptWithDetails: (details) => onPlaceBet(slot.index, details.data),
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        final lane = AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isWinning
                ? AppColors.neonGreen.withValues(alpha: 0.18)
                : hovering
                    ? AppColors.brassLight.withValues(alpha: 0.16)
                    : AppColors.ink.withValues(alpha: slot.odds == 2 ? 0.18 : 0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isWinning
                  ? AppColors.neonGreen
                  : hovering
                      ? AppColors.brassLight
                      : Colors.white.withValues(alpha: 0.12),
              width: isWinning || hovering ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              _OddsMedallion(odds: slot.odds, color: oddsColor),
              const SizedBox(height: 8),
              Expanded(
                flex: 4,
                child: _GuessPlaque(slot: slot, showGuesses: showGuesses, isWinning: isWinning),
              ),
              const SizedBox(height: 8),
              Expanded(
                flex: 5,
                child: _ChipPit(bets: bets, isLocked: isLocked),
              ),
              const SizedBox(height: 8),
              _LaneFooter(
                canBet: canBet,
                hasMyBet: hasMyBet,
                myTotal: myTotal,
                isLocked: isLocked,
              ),
            ],
          ),
        );

        return Opacity(
          opacity: revealDim ? 0.22 : 1,
          child: GestureDetector(
            onTap: canBet
                ? () {
                    if (hasMyBet) {
                      onRemoveBet(slot.index);
                    } else {
                      onPlaceBet(slot.index, 1);
                    }
                  }
                : null,
            child: isWinning && phase == RoundPhase.revealAnswer
                ? lane
                    .animate(onPlay: (controller) => controller.repeat(reverse: true))
                    .scale(end: const Offset(1.035, 1.035), duration: 760.ms)
                    .shimmer(color: AppColors.neonGreen.withValues(alpha: 0.25))
                : lane,
          ),
        );
      },
    );
  }
}

class _OddsMedallion extends StatelessWidget {
  final int odds;
  final Color color;

  const _OddsMedallion({required this.odds, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.goldGradient,
        border: Border.all(color: Colors.white.withValues(alpha: 0.32), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        '$odds:1',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _GuessPlaque extends StatelessWidget {
  final _SlotData slot;
  final bool showGuesses;
  final bool isWinning;

  const _GuessPlaque({
    required this.slot,
    required this.showGuesses,
    required this.isWinning,
  });

  @override
  Widget build(BuildContext context) {
    final guessColor = slot.guess?.playerColor != null
        ? Color(Helpers.colorFromHex(slot.guess!.playerColor!))
        : AppColors.brass;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.ivory.withValues(alpha: slot.isEdge ? 0.1 : 0.93),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWinning ? AppColors.neonGreen : AppColors.brass.withValues(alpha: 0.38),
          width: isWinning ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              showGuesses || slot.isEdge ? slot.label : '???',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: slot.isEdge ? AppColors.ivory : AppColors.ink,
                fontWeight: FontWeight.w900,
                fontSize: slot.isEdge ? 13 : 22,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            showGuesses || slot.isEdge ? slot.subtitle : 'hidden',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: slot.isEdge ? AppColors.textSecondary : guessColor,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 260.ms).slideY(begin: 0.08);
  }
}

class _ChipPit extends StatelessWidget {
  final List<Bet> bets;
  final bool isLocked;

  const _ChipPit({required this.bets, required this.isLocked});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: bets.isEmpty
          ? Center(
              child: Text(
                'drop zone',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.ivory.withValues(alpha: 0.32),
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    for (var i = 0; i < bets.length; i++)
                      _positionedChip(bets[i], i, constraints.biggest),
                  ],
                );
              },
            ),
    );
  }

  Widget _positionedChip(Bet bet, int index, Size size) {
    final color = bet.playerColor != null
        ? Color(Helpers.colorFromHex(bet.playerColor!))
        : AppColors.chipGold;
    final hash = bet.id.hashCode.abs();
    final dx = ((hash % 23) - 11).toDouble();
    final dy = (((hash ~/ 23) % 21) - 10).toDouble();
    final rotation = (((hash ~/ 71) % 17) - 8) * pi / 180;
    final chipSize = min(34.0, max(24.0, size.shortestSide * 0.32));

    Widget chip = Transform.translate(
      offset: Offset(dx + (index % 3 - 1) * 4, dy - index * 1.8),
      child: Transform.rotate(
        angle: rotation,
        child: PokerChip(
          label: '${bet.chips}',
          color: color,
          size: chipSize,
          isScoreChip: bet.playerColor == null,
        ),
      ),
    );

    if (isLocked) {
      chip = chip
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.09, 1.09),
            duration: 900.ms,
            curve: Curves.easeInOut,
          );
    }

    return SpringyChip(
      key: ValueKey(bet.id),
      child: chip,
    );
  }
}

class _LaneFooter extends StatelessWidget {
  final bool canBet;
  final bool hasMyBet;
  final int myTotal;
  final bool isLocked;

  const _LaneFooter({
    required this.canBet,
    required this.hasMyBet,
    required this.myTotal,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hasMyBet
            ? AppColors.brass.withValues(alpha: 0.22)
            : AppColors.mahoganyDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: hasMyBet
              ? AppColors.brassLight.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Text(
        hasMyBet
            ? 'your chips: $myTotal'
            : isLocked
                ? 'locked'
                : canBet
                    ? 'tap 1 / drop'
                    : 'stand by',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: hasMyBet ? AppColors.brassLight : AppColors.textMuted,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SlotData {
  final int index;
  final int odds;
  final String label;
  final String subtitle;
  final Guess? guess;
  final bool isEdge;

  const _SlotData({
    required this.index,
    required this.odds,
    required this.label,
    required this.subtitle,
    this.guess,
    required this.isEdge,
  });
}

class _FeltPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width; x += 24) {
      canvas.drawLine(Offset(x.toDouble(), size.height), Offset(x + size.height, 0), linePaint);
    }

    final railPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppColors.brass.withValues(alpha: 0.16);
    final rect = Rect.fromLTWH(14, 14, size.width - 28, size.height - 28);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(24)), railPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
