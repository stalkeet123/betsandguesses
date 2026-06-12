import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_asset_image.dart';
import '../../../features/game/providers/game_providers.dart';
import '../../../features/player/models/player_model.dart';
import '../../../features/room/providers/room_providers.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  final String roomCode;

  const ResultsScreen({super.key, required this.roomCode});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  late final ConfettiController _confettiController;
  List<Player> _sortedPlayers = [];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 5));
    _confettiController.play();
    _loadResults();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadResults() async {
    final room = ref.read(currentRoomProvider);
    if (room == null) return;

    final players = await ref.read(playerServiceProvider).getPlayers(room.id);
    players.sort((a, b) => b.score.compareTo(a.score));

    if (mounted) setState(() => _sortedPlayers = players);
  }

  void _goHome() {
    ref.read(realtimeServiceProvider).leaveRoom(widget.roomCode);
    ref.read(currentRoomProvider.notifier).set(null);
    ref.read(currentPlayerProvider.notifier).set(null);
    ref.read(gameStateProvider.notifier).reset();
    context.goNamed('home');
  }

  void _backToLobby() {
    ref.read(gameStateProvider.notifier).reset();
    context.goNamed('lobby', pathParameters: {'roomCode': widget.roomCode});
  }

  Future<void> _shareResults() async {
    final lines = _sortedPlayers
        .asMap()
        .entries
        .map((entry) => '${entry.key + 1}. ${entry.value.name}: ${_formatScore(entry.value.score)}')
        .join('\n');
    await Clipboard.setData(ClipboardData(text: 'Bets & Guesses results\n$lines'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Results copied.')));
  }

  String _formatScore(int value) {
    return value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
  }

  @override
  Widget build(BuildContext context) {
    final winner = _sortedPlayers.isNotEmpty ? _sortedPlayers.first : null;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: CachedAssetImage(
                AppAssetPaths.background,
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.06),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.24),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  numberOfParticles: 46,
                  maxBlastForce: 30,
                  minBlastForce: 10,
                  colors: const [
                    AppColors.brassLight,
                    AppColors.chipGold,
                    AppColors.neonGreen,
                    AppColors.burgundy,
                    AppColors.neonCyan,
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final contentWidth = constraints.maxWidth.clamp(0.0, 560.0).toDouble();

                    return Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: contentWidth,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildHeader(),
                                const SizedBox(height: 10),
                                _buildWinnerCard(winner),
                                const SizedBox(height: 10),
                                _buildScoreboard(),
                                const SizedBox(height: 10),
                                _buildHighlights(winner),
                                const SizedBox(height: 12),
                                _buildActions(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        SizedBox(
          height: 104,
          child: CachedAssetImage(
            AppAssetPaths.logo,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildGoldRule()),
            const SizedBox(width: 10),
            const Icon(Icons.auto_awesome_rounded, color: AppColors.brassLight, size: 26),
            const SizedBox(width: 8),
            const Text(
              'GAME OVER!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'RehnCondensed',
                color: AppColors.brassLight,
                fontSize: 42,
                fontWeight: FontWeight.w900,
                height: 0.9,
                letterSpacing: 1.1,
                shadows: [
                  Shadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, 3)),
                  Shadow(color: AppColors.brass, blurRadius: 8),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.auto_awesome_rounded, color: AppColors.brassLight, size: 26),
            const SizedBox(width: 10),
            Expanded(child: _buildGoldRule()),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Here are the final results',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.ivory,
            fontWeight: FontWeight.w800,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
          ),
        ),
      ],
    );
  }

  Widget _buildWinnerCard(Player? winner) {
    return Container(
      height: 178,
      padding: const EdgeInsets.all(16),
      decoration: _darkPanelDecoration(radius: 22),
      child: winner == null
          ? Center(
              child: Text(
                'No results yet',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.ivory),
              ),
            )
          : Row(
              children: [
                SizedBox(
                  width: 142,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 116,
                        height: 116,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [winner.color.withValues(alpha: 0.92), winner.color.withValues(alpha: 0.45)],
                          ),
                          border: Border.all(color: AppColors.brassLight, width: 4),
                          boxShadow: [
                            BoxShadow(color: AppColors.brass.withValues(alpha: 0.55), blurRadius: 28),
                            BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            winner.name.isNotEmpty ? winner.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: AppColors.ivory,
                              fontSize: 58,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      const Positioned(
                        top: 0,
                        child: Icon(Icons.workspace_premium_rounded, color: AppColors.brassLight, size: 54),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildRibbon('WINNER'),
                      const SizedBox(height: 12),
                      Text(
                        winner.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: AppColors.ivory,
                          fontWeight: FontWeight.w900,
                          shadows: const [Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 3))],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'FINAL SCORE',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.brassLight,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatScore(winner.score),
                        maxLines: 1,
                        style: const TextStyle(
                          fontFamily: 'RehnCondensed',
                          color: AppColors.brassLight,
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                          height: 0.9,
                          letterSpacing: 0,
                          shadows: [Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 3))],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.06);
  }

  Widget _buildScoreboard() {
    return Container(
      height: 266,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: _darkPanelDecoration(radius: 20),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                SizedBox(width: 52, child: _buildBoardHeader('#')),
                Expanded(child: _buildBoardHeader('PLAYER')),
                SizedBox(width: 122, child: _buildBoardHeader('FINAL SCORE', alignRight: true)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _sortedPlayers.isEmpty
                ? Center(
                    child: Text(
                      'Scores will appear here.',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.ivory),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: _sortedPlayers.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.brassLight.withValues(alpha: 0.18),
                    ),
                    itemBuilder: (context, index) => _buildScoreRow(_sortedPlayers[index], index),
                  ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.05);
  }

  Widget _buildScoreRow(Player player, int index) {
    final isWinner = index == 0;
    final rankColor = switch (index) {
      0 => AppColors.brassLight,
      1 => AppColors.chipSilver,
      2 => AppColors.neonOrange,
      _ => AppColors.ivory.withValues(alpha: 0.72),
    };

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        gradient: isWinner
            ? const LinearGradient(colors: [Color(0xFFFFE58A), Color(0xFFFFB91F), Color(0xFFE2A317)])
            : null,
        color: isWinner ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isWinner ? AppColors.ivory.withValues(alpha: 0.72) : Colors.transparent, width: 1.1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Row(
              children: [
                Icon(
                  index < 3 ? Icons.military_tech_rounded : Icons.circle_rounded,
                  color: rankColor,
                  size: index < 3 ? 28 : 18,
                ),
                Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: isWinner ? AppColors.ink : AppColors.ivory,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: player.color,
              border: Border.all(color: isWinner ? AppColors.ink.withValues(alpha: 0.52) : AppColors.brassLight, width: 1.8),
            ),
            child: Text(
              player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
              style: const TextStyle(color: AppColors.ivory, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: isWinner ? AppColors.ink : AppColors.ivory,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            _formatScore(player.score),
            style: TextStyle(
              color: isWinner ? AppColors.feltDark : AppColors.ivory,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              height: 1,
              shadows: isWinner ? null : const [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (45 * index).ms).slideX(begin: 0.04);
  }

  Widget _buildHighlights(Player? winner) {
    final runnerUp = _sortedPlayers.length > 1 ? _sortedPlayers[1] : null;

    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFAEE), Color(0xFFF2D9A4), Color(0xFFFFFDF6)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.brassLight.withValues(alpha: 0.84), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildHighlightCell(
              icon: Icons.emoji_events_rounded,
              label: 'TOP SCORE',
              name: winner?.name ?? '-',
              value: winner == null ? '-' : _formatScore(winner.score),
            ),
          ),
          _buildVerticalDivider(),
          Expanded(
            child: _buildHighlightCell(
              icon: Icons.trending_up_rounded,
              label: 'RUNNER UP',
              name: runnerUp?.name ?? '-',
              value: runnerUp == null ? '-' : _formatScore(runnerUp.score),
            ),
          ),
          _buildVerticalDivider(),
          Expanded(
            child: _buildHighlightCell(
              icon: Icons.groups_rounded,
              label: 'PLAYERS',
              name: '${_sortedPlayers.length}',
              value: 'finished',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                label: 'PLAY AGAIN',
                icon: Icons.workspace_premium_rounded,
                isGold: true,
                onTap: _backToLobby,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                label: 'BACK TO LOBBY',
                icon: Icons.meeting_room_rounded,
                isGold: false,
                onTap: _backToLobby,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 300,
          child: _buildActionButton(
            label: 'SHARE RESULTS',
            icon: Icons.share_rounded,
            isGold: false,
            onTap: () {
              _shareResults();
            },
            compact: true,
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _goHome,
          icon: const Icon(Icons.home_rounded, size: 18),
          label: const Text('HOME'),
          style: TextButton.styleFrom(foregroundColor: AppColors.ivory.withValues(alpha: 0.82)),
        ),
      ],
    );
  }

  Widget _buildRibbon(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFE58A), Color(0xFFFFB91F), Color(0xFFD88700)]),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.ivory.withValues(alpha: 0.72), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: AppColors.ink, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: AppColors.ink, fontSize: 18, fontWeight: FontWeight.w900, height: 1),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.star_rounded, color: AppColors.ink, size: 18),
        ],
      ),
    );
  }

  Widget _buildBoardHeader(String text, {bool alignRight = false}) {
    return Text(
      text,
      textAlign: alignRight ? TextAlign.right : TextAlign.left,
      style: const TextStyle(
        color: AppColors.brassLight,
        fontSize: 13,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
        height: 1,
      ),
    );
  }

  Widget _buildHighlightCell({required IconData icon, required String label, required String name, required String value}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.felt, fontSize: 12, fontWeight: FontWeight.w900, height: 1),
        ),
        const SizedBox(height: 5),
        Icon(icon, color: AppColors.mahogany, size: 27),
        const SizedBox(height: 3),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.felt, fontSize: 15, fontWeight: FontWeight.w900, height: 1),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.mahogany, fontSize: 13, fontWeight: FontWeight.w900, height: 1),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required bool isGold,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return SizedBox(
      height: compact ? 44 : 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: compact ? 21 : 25),
        label: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
        style: ElevatedButton.styleFrom(
          backgroundColor: isGold ? AppColors.brass : AppColors.felt,
          foregroundColor: isGold ? AppColors.ink : AppColors.ivory,
          elevation: 7,
          shadowColor: Colors.black54,
          textStyle: TextStyle(
            fontFamily: 'RehnCondensed',
            fontSize: compact ? 25 : 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
            height: 0.95,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(compact ? 14 : 16),
            side: BorderSide(color: AppColors.ivory.withValues(alpha: isGold ? 0.7 : 0.42), width: 1.2),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 62,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: AppColors.felt.withValues(alpha: 0.28),
    );
  }

  Widget _buildGoldRule() {
    return Container(
      height: 1.5,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.brassLight.withValues(alpha: 0.82),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  BoxDecoration _darkPanelDecoration({required double radius}) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.feltDark.withValues(alpha: 0.96),
          AppColors.felt.withValues(alpha: 0.84),
          AppColors.feltDark.withValues(alpha: 0.98),
        ],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.brassLight.withValues(alpha: 0.72), width: 1.5),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.36), blurRadius: 18, offset: const Offset(0, 9)),
        BoxShadow(color: AppColors.brass.withValues(alpha: 0.12), blurRadius: 18),
      ],
    );
  }
}
