import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/game_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_asset_image.dart';
import '../../../features/room/providers/room_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final String? prefilledRoomCode;
  const HomeScreen({super.key, this.prefilledRoomCode});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _nameController = TextEditingController();
  final _roomCodeController = TextEditingController();
  final _random = Random();
  bool _isLoading = false;
  String? _prefilledRoomCode;

  @override
  void initState() {
    super.initState();
    _prefilledRoomCode = widget.prefilledRoomCode;
    if (_prefilledRoomCode != null && _prefilledRoomCode!.isNotEmpty) {
      _roomCodeController.text = _prefilledRoomCode!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final savedName = ref.read(playerNameProvider);
      if (savedName.isNotEmpty) {
        _nameController.text = savedName;
      }
      ref.read(audioServiceProvider).stopAmbience();

      if (savedName.isNotEmpty &&
          _prefilledRoomCode != null &&
          _prefilledRoomCode!.isNotEmpty) {
        _joinRoom();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('Enter your name first.');
      return;
    }

    setState(() => _isLoading = true);
    ref.read(playerNameProvider.notifier).setName(name);

    try {
      final roomService = ref.read(roomServiceProvider);
      final playerService = ref.read(playerServiceProvider);
      final room = await roomService.createRoom('temp');

      final player = await playerService.joinRoom(
        roomId: room.id,
        name: name,
        avatarColor: _pickAvatarColor(),
        isHost: true,
      );

      await roomService.updateRoom(room.id, {'host_id': player.id});
      ref.read(currentPlayerProvider.notifier).set(player);
      ref
          .read(currentRoomProvider.notifier)
          .set(room.copyWith(hostId: player.id));

      if (mounted) {
        context.goNamed('lobby', pathParameters: {'roomCode': room.code});
      }
    } catch (e) {
      _showSnack('Room could not be created: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinRoom() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('Enter your name first.');
      return;
    }
    ref.read(playerNameProvider.notifier).setName(name);

    final code = _roomCodeController.text.trim().toUpperCase();
    if (code.length != GameConstants.roomCodeLength) {
      _showSnack(
        'Enter a ${GameConstants.roomCodeLength}-character room code.',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final roomService = ref.read(roomServiceProvider);
      final playerService = ref.read(playerServiceProvider);
      final room = await roomService.findRoomByCode(code);
      if (room == null) {
        _showSnack('Room not found.');
        return;
      }

      if (!room.canJoinLobby) {
        _showSnack('That table is already playing.');
        return;
      }

      final existingPlayers = await playerService.getPlayers(room.id);
      final usedColors = existingPlayers.map((p) => p.avatarColor).toSet();
      final availableColor = _pickAvatarColor(usedColors);

      final player = await playerService.joinRoom(
        roomId: room.id,
        name: name,
        avatarColor: availableColor,
      );

      ref.read(currentPlayerProvider.notifier).set(player);
      ref.read(currentRoomProvider.notifier).set(room);

      if (mounted) {
        context.goNamed('lobby', pathParameters: {'roomCode': room.code});
      }
    } catch (e) {
      _showSnack('Could not join: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _goPremium() {
    context.pushNamed('premium');
  }

  String _pickAvatarColor([Set<String> usedColors = const {}]) {
    final availableColors = GameConstants.avatarColors
        .where((color) => !usedColors.contains(color))
        .toList();
    final palette = availableColors.isEmpty
        ? GameConstants.avatarColors
        : availableColors;
    return palette[_random.nextInt(palette.length)];
  }

  @override
  Widget build(BuildContext context) {
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
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final logoHeight = (constraints.maxHeight * 0.2)
                        .clamp(92.0, 158.0)
                        .toDouble();

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: logoHeight,
                                child: CachedAssetImage(
                                  AppAssetPaths.logo,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildNameCard(),
                              const SizedBox(height: 10),
                              _buildCreateLobbyButton(),
                              const SizedBox(height: 10),
                              _buildJoinLobbyCard(),
                              const SizedBox(height: 10),
                              _buildPremiumButton(),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameCard() {
    return _FormPlaque(
      title: 'YOUR NAME',
      child: TextField(
        controller: _nameController,
        textAlign: TextAlign.left,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.ivory,
          fontWeight: FontWeight.w900,
        ),
        decoration: const InputDecoration(
          isDense: true,
          hintText: 'Enter your name',
          prefixIcon: Icon(
            Icons.person_outline_rounded,
            color: AppColors.brassLight,
          ),
        ),
      ),
    );
  }

  Widget _buildCreateLobbyButton() {
    return _CasinoMenuButton(
      label: 'CREATE LOBBY',
      icon: Icons.groups_rounded,
      isLoading: _isLoading,
      onPressed: _isLoading ? null : _createRoom,
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFF0A8), Color(0xFFFFC42E), Color(0xFFB56A09)],
      ),
      foregroundColor: AppColors.ink,
    );
  }

  Widget _buildJoinLobbyCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.feltDark.withValues(alpha: 0.96),
            AppColors.felt.withValues(alpha: 0.76),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.brassLight.withValues(alpha: 0.32),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _RoundIcon(icon: Icons.login_rounded, color: AppColors.ivory),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'JOIN LOBBY',
                  style: const TextStyle(
                    fontFamily: 'RehnCondensed',
                    color: AppColors.ivory,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    height: 0.92,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _roomCodeController,
                  textAlign: TextAlign.left,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: GameConstants.roomCodeLength,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.ivory,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Room code',
                    counterText: '',
                    prefixIcon: Icon(
                      Icons.tag_rounded,
                      color: AppColors.brassLight,
                    ),
                  ),
                  onSubmitted: (_) => _joinRoom(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 68,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _joinRoom,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: AppColors.brass,
                    foregroundColor: AppColors.ink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, size: 26),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumButton() {
    return OutlinedButton.icon(
      onPressed: _goPremium,
      icon: const Icon(Icons.workspace_premium_rounded, size: 20),
      label: const Text('GO PREMIUM'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        foregroundColor: AppColors.brassLight,
        side: BorderSide(color: AppColors.brassLight.withValues(alpha: 0.5)),
        backgroundColor: AppColors.feltDark.withValues(alpha: 0.64),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _FormPlaque extends StatelessWidget {
  final String title;
  final Widget child;

  const _FormPlaque({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.ivory.withValues(alpha: 0.98),
            const Color(0xFFEBD9B1),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.brassLight.withValues(alpha: 0.42),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'RehnCondensed',
                  color: AppColors.felt,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _CasinoMenuButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Gradient gradient;
  final Color foregroundColor;
  final bool isLoading;

  const _CasinoMenuButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.gradient,
    required this.foregroundColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.ivory.withValues(alpha: 0.62),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.2),
                      border: Border.all(
                        color: AppColors.brassLight.withValues(alpha: 0.44),
                        width: 1.1,
                      ),
                    ),
                    child: isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.ink,
                            ),
                          )
                        : Icon(icon, color: foregroundColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: 'RehnCondensed',
                          color: foregroundColor,
                          fontSize: 31,
                          fontWeight: FontWeight.w900,
                          height: 0.92,
                          letterSpacing: 0,
                          shadows: [
                            Shadow(
                              color: Colors.white.withValues(
                                alpha: foregroundColor == AppColors.ink
                                    ? 0.34
                                    : 0.14,
                              ),
                              blurRadius: 1,
                              offset: const Offset(0, 1),
                            ),
                            Shadow(
                              color: Colors.black.withValues(
                                alpha: foregroundColor == AppColors.ivory
                                    ? 0.7
                                    : 0.22,
                              ),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _RoundIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.32),
        border: Border.all(
          color: AppColors.brassLight.withValues(alpha: 0.7),
          width: 1.2,
        ),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}
