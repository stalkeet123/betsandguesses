import 'package:confetti/confetti.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../models/guess_model.dart';

class AnswerReveal extends StatefulWidget {
  final int correctAnswer;
  final String? unit;
  final String? winningGuessId;
  final List<Guess> guesses;

  const AnswerReveal({
    super.key,
    required this.correctAnswer,
    this.unit,
    this.winningGuessId,
    required this.guesses,
  });

  @override
  State<AnswerReveal> createState() => _AnswerRevealState();
}

class _AnswerRevealState extends State<AnswerReveal> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final winner = widget.guesses.where((g) => g.id == widget.winningGuessId).firstOrNull;

    return Positioned(
      left: 22,
      right: 22,
      bottom: 76,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 28,
            maxBlastForce: 22,
            minBlastForce: 8,
            colors: const [
              AppColors.brassLight,
              AppColors.chipGold,
              AppColors.neonGreen,
              AppColors.burgundy,
              AppColors.neonCyan,
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF9E6B8), Color(0xFFD6A84B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.42), width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: AppColors.chipGold.withValues(alpha: 0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.workspace_premium_rounded, color: AppColors.ink, size: 28),
                const SizedBox(width: 12),
                Text(
                  'ANSWER',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.ink.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${Helpers.formatNumber(widget.correctAnswer)}${widget.unit != null ? ' ${widget.unit}' : ''}',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                if (winner != null) ...[
                  const SizedBox(width: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.ink.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.ink.withValues(alpha: 0.14)),
                    ),
                    child: Text(
                      'Closest: ${winner.playerName ?? 'Player'}',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ).animate().fadeIn(duration: 260.ms).slideY(begin: 0.25).scale(begin: const Offset(0.94, 0.94)),
        ],
      ),
    );
  }
}
