import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/constants/game_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_asset_image.dart';
import '../../../features/game/providers/game_providers.dart';
import '../../../features/player/models/player_model.dart';

import '../../../features/room/models/room_model.dart';
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
  bool _isReturningToLobby = false;
  bool _hasLeftResults = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 5),
    );
    _confettiController.play();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioServiceProvider).startLobbyMusic();
      ref.read(audioServiceProvider).playEpicFanfare();
    });
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
    if (_hasLeftResults) return;
    _hasLeftResults = true;
    ref.read(realtimeServiceProvider).leaveRoom(widget.roomCode);
    ref.read(currentRoomProvider.notifier).set(null);
    ref.read(currentPlayerProvider.notifier).set(null);
    ref.read(gameStateProvider.notifier).reset();
    context.goNamed('home');
  }

  void _openLobby(Room room) {
    if (!mounted || _hasLeftResults) return;
    _hasLeftResults = true;
    ref.read(currentRoomProvider.notifier).set(room);
    ref.read(gameStateProvider.notifier).reset();
    context.goNamed('lobby', pathParameters: {'roomCode': widget.roomCode});
  }

  Future<void> _backToLobby() async {
    if (_isReturningToLobby) return;
    setState(() => _isReturningToLobby = true);
    final room = ref.read(currentRoomProvider);
    try {
      if (room != null) {
        final roomService = ref.read(roomServiceProvider);
        var resetRoom = await roomService.resetToLobbyAtomic(room.id);
        if (resetRoom == null) {
          await ref.read(gameServiceProvider).clearRoomGameData(room.id);
          await roomService.resetToLobby(room.id);
          resetRoom = await roomService.getRoom(room.id);
        }
        _openLobby(resetRoom);
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to return room to lobby: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not return to the lobby. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isReturningToLobby = false);
    }
  }

  String _formatScore(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(currentRoomProvider);
    if (room != null) {
      ref.listen(roomStreamProvider(room.id), (_, next) {
        final rows = next.asData?.value;
        if (rows == null || rows.isEmpty) return;
        final updatedRoom = Room.fromJson(rows.first);
        if (updatedRoom.status == RoomStatus.waiting) {
          _openLobby(updatedRoom);
        }
      });
    }

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
                    final contentWidth = constraints.maxWidth
                        .clamp(0.0, 560.0)
                        .toDouble();
                    final isCompact = constraints.maxHeight < 720;

                    return Center(
                      child: SizedBox(
                        width: contentWidth,
                        height: constraints.maxHeight,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            18,
                            isCompact ? 6 : 10,
                            18,
                            14,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeader(compact: isCompact),
                              SizedBox(height: isCompact ? 8 : 12),
                              _buildWinnerCard(winner, compact: isCompact),
                              SizedBox(height: isCompact ? 8 : 12),
                              Expanded(child: _buildScoreboard()),
                              SizedBox(height: isCompact ? 8 : 12),
                              _buildActions(),
                            ],
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

  Widget _buildHeader({required bool compact}) {
    return Column(
      children: [
        SizedBox(
          height: compact ? 58 : 86,
          child: CachedAssetImage(AppAssetPaths.logo, fit: BoxFit.contain),
        ),
        SizedBox(height: compact ? 4 : 8),
        Row(
          children: [
            Expanded(child: _buildGoldRule()),
            const SizedBox(width: 10),
            const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.brassLight,
              size: 26,
            ),
            const SizedBox(width: 8),
            Text(
              'GAME OVER!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'RehnCondensed',
                color: AppColors.brassLight,
                fontSize: compact ? 34 : 42,
                fontWeight: FontWeight.w900,
                height: 0.9,
                letterSpacing: 1.1,
                shadows: [
                  Shadow(
                    color: Colors.black87,
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                  Shadow(color: AppColors.brass, blurRadius: 8),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.brassLight,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(child: _buildGoldRule()),
          ],
        ),
        const SizedBox(height: 4),
        if (!compact)
          Text(
            'Final leaderboard',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.ivory,
              fontWeight: FontWeight.w800,
              shadows: const [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildWinnerCard(Player? winner, {required bool compact}) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        compact ? 12 : 16,
        16,
        compact ? 12 : 16,
      ),
      decoration: _darkPanelDecoration(radius: 18),
      child: winner == null
          ? Center(
              child: Text(
                'No results yet',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: AppColors.ivory),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildRibbon('WINNER'),
                SizedBox(height: compact ? 8 : 12),
                Text(
                  winner.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.ivory,
                    fontSize: compact ? 30 : 36,
                    fontWeight: FontWeight.w900,
                    height: 0.95,
                    shadows: const [
                      Shadow(
                        color: Colors.black87,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 8 : 10),
                Text(
                  'FINAL SCORE',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.brassLight,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _formatScore(winner.score),
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: 'RehnCondensed',
                      color: AppColors.brassLight,
                      fontSize: compact ? 44 : 54,
                      fontWeight: FontWeight.w900,
                      height: 0.9,
                      letterSpacing: 0,
                      shadows: const [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.06);
  }

  Widget _buildScoreboard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: _darkPanelDecoration(radius: 20),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                SizedBox(width: 46, child: _buildBoardHeader('#')),
                Expanded(child: _buildBoardHeader('PLAYER')),
                SizedBox(
                  width: 104,
                  child: _buildBoardHeader('FINAL SCORE', alignRight: true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _sortedPlayers.isEmpty
                ? Center(
                    child: Text(
                      'Scores will appear here.',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: AppColors.ivory),
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
                    itemBuilder: (context, index) =>
                        _buildScoreRow(_sortedPlayers[index], index),
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
      constraints: const BoxConstraints(minHeight: 52),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        gradient: isWinner
            ? const LinearGradient(
                colors: [
                  Color(0xFFFFE58A),
                  Color(0xFFFFB91F),
                  Color(0xFFE2A317),
                ],
              )
            : null,
        color: isWinner ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWinner
              ? AppColors.ivory.withValues(alpha: 0.72)
              : Colors.transparent,
          width: 1.1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Row(
              children: [
                Icon(
                  index < 3
                      ? Icons.military_tech_rounded
                      : Icons.circle_rounded,
                  color: rankColor,
                  size: index < 3 ? 24 : 10,
                ),
                const SizedBox(width: 4),
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
          Expanded(
            child: Text(
              player.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: isWinner ? AppColors.ink : AppColors.ivory,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 96,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                _formatScore(player.score),
                maxLines: 1,
                style: TextStyle(
                  color: isWinner ? AppColors.feltDark : AppColors.ivory,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  shadows: isWinner
                      ? null
                      : const [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (45 * index).ms).slideX(begin: 0.04);
  }

  Widget _buildActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: _buildActionButton(
            label: 'PLAY AGAIN',
            icon: Icons.workspace_premium_rounded,
            isGold: true,
            onTap: () {
              _backToLobby();
            },
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _goHome,
          icon: const Icon(Icons.home_rounded, size: 18),
          label: const Text('HOME'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.ivory.withValues(alpha: 0.82),
          ),
        ),
      ],
    );
  }

  Widget _buildRibbon(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE58A), Color(0xFFFFB91F), Color(0xFFD88700)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.ivory.withValues(alpha: 0.72),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: AppColors.ink, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
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
            side: BorderSide(
              color: AppColors.ivory.withValues(alpha: isGold ? 0.7 : 0.42),
              width: 1.2,
            ),
          ),
        ),
      ),
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
      border: Border.all(
        color: AppColors.brassLight.withValues(alpha: 0.72),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.36),
          blurRadius: 18,
          offset: const Offset(0, 9),
        ),
        BoxShadow(
          color: AppColors.brass.withValues(alpha: 0.12),
          blurRadius: 18,
        ),
      ],
    );
  }
}
