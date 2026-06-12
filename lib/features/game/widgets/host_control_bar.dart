import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/game_constants.dart';
import '../../../core/theme/app_colors.dart';

class HostControlBar extends StatelessWidget {
  final RoundPhase phase;
  final VoidCallback onRevealGuesses;
  final VoidCallback onRevealAnswer;
  final VoidCallback onNextRound;
  final bool isLastRound;

  const HostControlBar({
    super.key,
    required this.phase,
    required this.onRevealGuesses,
    required this.onRevealAnswer,
    required this.onNextRound,
    required this.isLastRound,
  });

  @override
  Widget build(BuildContext context) {
    final action = _actionForPhase();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: AppColors.leatherPanel(borderRadius: 18),
      child: Row(
        children: [
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: AppColors.brass.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.brass.withValues(alpha: 0.38)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings_rounded, size: 17, color: AppColors.brassLight),
                const SizedBox(width: 7),
                Text(
                  'DEALER CONTROLS',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.brassLight,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              _hintForPhase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (action != null)
            _DealerButton(
              label: action.label,
              icon: action.icon,
              color: action.color,
              onPressed: action.onPressed,
            ),
        ],
      ),
    ).animate().slideY(begin: 1, duration: 360.ms, curve: Curves.easeOutCubic);
  }

  _DealerAction? _actionForPhase() {
    if (phase == RoundPhase.guessing) {
      return _DealerAction(
        label: 'Reveal guesses',
        icon: Icons.visibility_rounded,
        color: AppColors.neonCyan,
        onPressed: onRevealGuesses,
      );
    }
    if (phase == RoundPhase.betting) {
      return _DealerAction(
        label: 'Reveal answer',
        icon: Icons.flaky_rounded,
        color: AppColors.neonGreen,
        onPressed: onRevealAnswer,
      );
    }
    if (phase == RoundPhase.revealAnswer || phase == RoundPhase.scoring) {
      return _DealerAction(
        label: isLastRound ? 'Final scores' : 'Next question',
        icon: isLastRound ? Icons.emoji_events_rounded : Icons.arrow_forward_rounded,
        color: isLastRound ? AppColors.chipGold : AppColors.brass,
        onPressed: onNextRound,
      );
    }
    return null;
  }

  String _hintForPhase() {
    switch (phase) {
      case RoundPhase.guessing:
        return 'Wait for guesses, then flip every card face up.';
      case RoundPhase.betting:
        return 'Players are placing chips. Reveal the answer when the table is ready.';
      case RoundPhase.revealAnswer:
      case RoundPhase.scoring:
        return 'Settle the table and move to the next deal.';
      default:
        return 'Table is waiting.';
    }
  }
}

class _DealerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _DealerButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.74)]),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: color == AppColors.chipGold || color == AppColors.brass
              ? AppColors.ink
              : Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
      ),
    );
  }
}

class _DealerAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _DealerAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });
}
