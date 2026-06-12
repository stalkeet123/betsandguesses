import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/game_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../models/question_model.dart';

class QuestionBar extends StatelessWidget {
  final int roundNumber;
  final int maxRounds;
  final Question? question;
  final RoundPhase phase;
  final int timerSeconds;

  const QuestionBar({
    super.key,
    required this.roundNumber,
    required this.maxRounds,
    this.question,
    required this.phase,
    required this.timerSeconds,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 6, 6),
      padding: const EdgeInsets.all(10),
      decoration: AppColors.leatherPanel(borderRadius: 18),
      child: Row(
        children: [
          _RoundChip(roundNumber: roundNumber, maxRounds: maxRounds),
          const SizedBox(width: 10),
          _PhasePill(phase: phase),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 58,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.ivory,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.brass.withValues(alpha: 0.62), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Text(
                question?.textTr ?? 'Question is being shuffled...',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                  height: 1.12,
                ),
              ),
            ).animate(key: ValueKey(question?.id ?? phase.name)).fadeIn(duration: 280.ms),
          ),
          const SizedBox(width: 10),
          _TimerDial(seconds: timerSeconds),
        ],
      ),
    );
  }
}

class _RoundChip extends StatelessWidget {
  final int roundNumber;
  final int maxRounds;

  const _RoundChip({required this.roundNumber, required this.maxRounds});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 58,
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'ROUND',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.ink.withValues(alpha: 0.75),
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          Text(
            '$roundNumber/$maxRounds',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhasePill extends StatelessWidget {
  final RoundPhase phase;

  const _PhasePill({required this.phase});

  @override
  Widget build(BuildContext context) {
    final color = switch (phase) {
      RoundPhase.guessing => AppColors.neonCyan,
      RoundPhase.betting => AppColors.brassLight,
      RoundPhase.revealAnswer => AppColors.neonGreen,
      RoundPhase.scoring => AppColors.chipGold,
      _ => AppColors.textMuted,
    };

    return Container(
      width: 118,
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Center(
        child: Text(
          phase.displayName,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
      ),
    );
  }
}

class _TimerDial extends StatelessWidget {
  final int seconds;

  const _TimerDial({required this.seconds});

  @override
  Widget build(BuildContext context) {
    final warning = seconds > 0 && seconds <= 10;
    final color = warning ? AppColors.neonRed : AppColors.brassLight;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 78,
      height: 58,
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.48), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: warning ? 0.28 : 0.08),
            blurRadius: warning ? 18 : 8,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_bottom_rounded, size: 15, color: color),
          const SizedBox(height: 2),
          Text(
            seconds > 0 ? '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}' : '--:--',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    ).animate(target: warning ? 1 : 0).shake(duration: 420.ms);
  }
}
