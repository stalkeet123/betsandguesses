import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/constants/game_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_asset_image.dart';
import '../../../features/player/models/player_model.dart';
import '../../../features/room/providers/room_providers.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  final String roomCode;

  const LobbyScreen({super.key, required this.roomCode});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  List<Player> _players = [];
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    _loadPlayers();
    _setupRealtimeListener();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioServiceProvider).startAmbience();
    });
  }

  void _setupRealtimeListener() {
    final room = ref.read(currentRoomProvider);
    if (room == null) return;

    final realtimeService = ref.read(realtimeServiceProvider);
    realtimeService.joinRoom(
      widget.roomCode,
      onPhaseChange: (_) {},
      onGuessSubmitted: (_) {},
      onGuessesRevealed: (_) {},
      onBetPlaced: (_) {},
      onBetRemoved: (_) {},
      onScoreUpdate: (_) {},
      onAnswerRevealed: (_) {},
      onGameStarted: (_) {
        if (mounted) {
          context.goNamed('game', pathParameters: {'roomCode': widget.roomCode});
        }
      },
      onGameEnded: (_) {},
    );
  }

  Future<void> _loadPlayers() async {
    final room = ref.read(currentRoomProvider);
    if (room == null) return;

    final playerService = ref.read(playerServiceProvider);
    final players = await playerService.getPlayers(room.id);
    if (mounted) setState(() => _players = players);
  }

  Future<void> _toggleReady() async {
    final player = ref.read(currentPlayerProvider);
    if (player == null) return;

    final playerService = ref.read(playerServiceProvider);
    await playerService.toggleReady(player.id, !player.isReady);
    ref.read(currentPlayerProvider.notifier).set(player.copyWith(isReady: !player.isReady));
    _loadPlayers();
  }

  Future<void> _startGame() async {
    if (_isStarting) return;
    setState(() => _isStarting = true);

    try {
      final room = ref.read(currentRoomProvider);
      if (room == null) return;

      final roomService = ref.read(roomServiceProvider);
      await roomService.startGame(room.id);

      final realtimeService = ref.read(realtimeServiceProvider);
      await realtimeService.broadcast(widget.roomCode, 'game_started', {'room_id': room.id});

      if (mounted) {
        context.goNamed('game', pathParameters: {'roomCode': widget.roomCode});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Game could not start: $e')));
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  bool get _canStart {
    final isHost = ref.read(isHostProvider);
    if (!isHost) return false;
    if (_players.length < GameConstants.minPlayers) return false;
    return _players.where((p) => !p.isHost).every((p) => p.isReady);
  }

  String get _inviteLink {
    if (kIsWeb) {
      final uri = Uri.base;
      final origin = '${uri.scheme}://${uri.host}${uri.port != 80 && uri.port != 443 && uri.port != 0 ? ":${uri.port}" : ""}';
      return '$origin/#/?room=${widget.roomCode}';
    }

    const webAppUrl = String.fromEnvironment('WEB_APP_URL', defaultValue: 'https://stalkeet123.github.io/betsandguesses');
    return '$webAppUrl/#/?room=${widget.roomCode}';
  }

  Future<void> _copyText(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _leaveLobby() async {
    final player = ref.read(currentPlayerProvider);
    if (player != null) {
      await ref.read(playerServiceProvider).leaveRoom(player.id);
    }
    ref.read(realtimeServiceProvider).leaveRoom(widget.roomCode);
    ref.read(currentRoomProvider.notifier).set(null);
    ref.read(currentPlayerProvider.notifier).set(null);
    if (mounted) context.goNamed('home');
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(currentRoomProvider);
    final currentPlayer = ref.watch(currentPlayerProvider);
    final isHost = ref.watch(isHostProvider);

    if (room != null) {
      ref.listen(playersStreamProvider(room.id), (prev, next) {
        next.whenData((data) {
          if (mounted) {
            setState(() {
              _players = data.map((e) => Player.fromJson(e)).toList();
            });
          }
        });
      });
    }

    return Scaffold(
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
                    Colors.black.withValues(alpha: 0.14),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.22),
                  ],
                ),
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
                          padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildLobbyTopBar(),
                              const SizedBox(height: 6),
                              _buildRoomInfoPanel(),
                              const SizedBox(height: 10),
                              _buildPlayersPanel(),
                              const SizedBox(height: 10),
                              _buildActionsPanel(isHost, currentPlayer),
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
    );
  }

  Widget _buildLobbyTopBar() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildGoldRule()),
            const SizedBox(width: 12),
            const Expanded(
              flex: 5,
              child: Text(
                'PRIVATE LOBBY',
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'RehnCondensed',
                  color: AppColors.ivory,
                  fontSize: 31,
                  fontWeight: FontWeight.w900,
                  height: 0.9,
                  letterSpacing: 1.6,
                  shadows: [
                    Shadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 2)),
                    Shadow(color: AppColors.brass, blurRadius: 8),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                tooltip: 'Leave lobby',
                onPressed: _leaveLobby,
                icon: const Icon(Icons.exit_to_app_rounded),
                color: AppColors.brassLight,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.feltDark.withValues(alpha: 0.82),
                  side: BorderSide(color: AppColors.brassLight.withValues(alpha: 0.72), width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoomCodePill() {
    final spacedCode = widget.roomCode.split('').join('  ');

    return Container(
      height: 56,
      decoration: _darkGoldDecoration(radius: 18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _copyText(widget.roomCode, 'Room code copied.'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      spacedCode,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'RehnCondensed',
                        color: AppColors.brassLight,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        height: 0.9,
                        letterSpacing: 0,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.brassLight.withValues(alpha: 0.58), width: 1.4),
                  ),
                  child: const Icon(Icons.copy_rounded, color: AppColors.brassLight, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.08);
  }

  Widget _buildRoomInfoPanel() {
    final qrData = _inviteLink;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.feltDark.withValues(alpha: 0.92),
            AppColors.felt.withValues(alpha: 0.82),
            AppColors.feltDark.withValues(alpha: 0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.brassLight.withValues(alpha: 0.78), width: 1.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          BoxShadow(color: AppColors.brass.withValues(alpha: 0.14), blurRadius: 18),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.ivory,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.brassLight.withValues(alpha: 0.88), width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6)),
              ],
            ),
            child: QrImageView(data: qrData, version: QrVersions.auto, size: 132),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSpark(),
              const SizedBox(width: 10),
              Text(
                'Scan to join',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.ivory,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  shadows: const [Shadow(color: Colors.black54, blurRadius: 7, offset: Offset(0, 2))],
                ),
              ),
              const SizedBox(width: 10),
              _buildSpark(),
            ],
          ),
          const SizedBox(height: 8),
          _buildRoomCodePill(),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ElevatedButton.icon(
              onPressed: () => _copyText(qrData, 'Invitation link copied.'),
              icon: const Icon(Icons.link_rounded, size: 18),
              label: const Text('COPY INVITE LINK'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brass,
                foregroundColor: AppColors.ink,
                textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                  side: BorderSide(color: AppColors.ivory.withValues(alpha: 0.72), width: 1.2),
                ),
                elevation: 5,
                shadowColor: Colors.black54,
                padding: const EdgeInsets.symmetric(horizontal: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: _darkGoldDecoration(radius: 16),
      child: Column(
        children: [
          Transform.translate(
            offset: const Offset(0, -1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.feltDark.withValues(alpha: 0.98),
                  AppColors.felt.withValues(alpha: 0.95),
                ]),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                border: Border.all(color: AppColors.brassLight.withValues(alpha: 0.72), width: 1.1),
              ),
              child: const Text(
                'PLAYERS',
                style: TextStyle(
                  fontFamily: 'RehnCondensed',
                  color: AppColors.brassLight,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (_players.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Text(
                'Waiting for players...',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 276, maxHeight: 322),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _players.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.brassLight.withValues(alpha: 0.12),
                ),
                itemBuilder: (context, index) => _buildPlayerRow(_players[index], index),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayerRow(Player player, int index) {
    final isReady = player.isReady || player.isHost;

    return SizedBox(
      height: 46,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [player.color.withValues(alpha: 0.86), player.color.withValues(alpha: 0.5)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.brassLight, width: 1.7),
              boxShadow: [
                BoxShadow(color: player.color.withValues(alpha: 0.44), blurRadius: 10),
              ],
            ),
            child: Center(
              child: Text(
                player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.ivory, fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.ivory,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      shadows: const [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
                    ),
                  ),
                ),
                if (player.isHost) ...[
                  const SizedBox(width: 10),
                  _buildHostBadge(),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _buildReadyBadge(isReady),
        ],
      ),
    ).animate().fadeIn(delay: (55 * index).ms).slideX(begin: 0.03);
  }

  Widget _buildActionsPanel(bool isHost, Player? currentPlayer) {
    final isPlayerReady = currentPlayer?.isReady == true || currentPlayer?.isHost == true;
    final primaryEnabled = isHost ? (_canStart && !_isStarting) : currentPlayer != null;
    final primaryLabel = isHost ? 'START GAME' : (isPlayerReady ? 'READY' : 'MARK READY');
    final primaryIcon = isHost ? Icons.workspace_premium_rounded : (isPlayerReady ? Icons.check_rounded : Icons.circle_outlined);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _darkGoldDecoration(radius: 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: primaryEnabled
                  ? () {
                      if (isHost) {
                        _startGame();
                      } else {
                        _toggleReady();
                      }
                    }
                  : null,
              icon: _isStarting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.ink),
                    )
                  : Icon(primaryIcon, size: 27),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(primaryLabel),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryEnabled ? AppColors.brass : AppColors.surfaceLight,
                foregroundColor: primaryEnabled ? AppColors.ink : AppColors.textMuted,
                disabledBackgroundColor: AppColors.surfaceLight.withValues(alpha: 0.68),
                disabledForegroundColor: AppColors.textMuted,
                elevation: primaryEnabled ? 9 : 0,
                shadowColor: Colors.black.withValues(alpha: 0.42),
                textStyle: const TextStyle(
                  fontFamily: 'RehnCondensed',
                  fontSize: 35,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  height: 0.95,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.ivory.withValues(alpha: 0.76), width: 1.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyBadge(bool isReady) {
    return Container(
      width: 108,
      height: 30,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isReady
              ? [const Color(0xFF62C15A), const Color(0xFF176E2E)]
              : [const Color(0xFF53606A), const Color(0xFF27313A)],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: isReady ? 0.2 : 0.28), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isReady ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isReady ? const Color(0xFFD4F5BC) : AppColors.ivory.withValues(alpha: 0.84),
            size: 17,
          ),
          const SizedBox(width: 6),
          Text(
            isReady ? 'READY' : 'NOT READY',
            style: TextStyle(
              color: AppColors.ivory.withValues(alpha: isReady ? 0.98 : 0.86),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.brassLight.withValues(alpha: 0.72), width: 1),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'HOST',
            style: TextStyle(color: AppColors.brassLight, fontWeight: FontWeight.w900, fontSize: 11, height: 1),
          ),
          SizedBox(width: 4),
          Icon(Icons.workspace_premium_rounded, color: AppColors.brassLight, size: 14),
        ],
      ),
    );
  }

  Widget _buildGoldRule() {
    return Container(
      height: 1.4,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.brassLight.withValues(alpha: 0.84),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildSpark() {
    return const Icon(Icons.auto_awesome_rounded, color: AppColors.brassLight, size: 18);
  }

  BoxDecoration _darkGoldDecoration({required double radius}) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.feltDark.withValues(alpha: 0.96),
          AppColors.felt.withValues(alpha: 0.82),
          AppColors.feltDark.withValues(alpha: 0.98),
        ],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.brassLight.withValues(alpha: 0.74), width: 1.45),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.38), blurRadius: 18, offset: const Offset(0, 9)),
        BoxShadow(color: AppColors.brass.withValues(alpha: 0.12), blurRadius: 18),
      ],
    );
  }
}
