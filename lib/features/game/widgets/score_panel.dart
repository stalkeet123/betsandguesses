import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/player/models/player_model.dart';
import 'animated_counter.dart';

class ScorePanel extends StatelessWidget {
  final List<Player> players;
  final Map<String, int> scores;

  const ScorePanel({
    super.key,
    required this.players,
    required this.scores,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<Player>.from(players)
      ..sort((a, b) => (scores[b.id] ?? 0).compareTo(scores[a.id] ?? 0));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppColors.leatherPanel(borderRadius: 18),
      child: Column(
        children: [
          Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'LEADERBOARD',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: sorted.isEmpty
                ? Center(
                    child: Text(
                      'No players',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final player = sorted[index];
                      return _ScoreTicket(
                        player: player,
                        score: scores[player.id] ?? 0,
                        rank: index + 1,
                      );
                    },
                  ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.04);
  }
}

class _ScoreTicket extends StatelessWidget {
  final Player player;
  final int score;
  final int rank;

  const _ScoreTicket({
    required this.player,
    required this.score,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final highlighted = rank <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.ivory.withValues(alpha: 0.94)
            : AppColors.ink.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted ? AppColors.brass.withValues(alpha: 0.48) : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: highlighted ? AppColors.ink : AppColors.textMuted,
                fontWeight: FontWeight.w900,
                fontFeatures: [const FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: player.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
            ),
            child: Text(
              player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: highlighted ? AppColors.ink : AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          AnimatedCounter(
            value: score,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: highlighted ? AppColors.mahogany : AppColors.brassLight,
              fontWeight: FontWeight.w900,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (45 * rank).ms);
  }
}
