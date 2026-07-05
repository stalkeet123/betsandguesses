import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
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
      ref.read(audioServiceProvider).startAmbience();
      ref.read(gameServiceProvider).prefetchQuestions();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    if (_isLoading) return;

    if (kIsWeb) {
      _showSnack('Web version is player-only.');
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('Enter your name first.');
      return;
    }

    ref.read(audioServiceProvider).playClick();
    ref.read(audioServiceProvider).startAmbience();
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
      _rememberPlayerForRoom(room.id, player.id);

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
    if (_isLoading || ref.read(currentPlayerProvider) != null) return;

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

    ref.read(audioServiceProvider).playClick();
    ref.read(audioServiceProvider).startAmbience();
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
      final previousPlayerId = _rememberedPlayerForRoom(room.id);
      final activePlayers = existingPlayers
          .where((player) => player.isConnected)
          .toList();
      final isReturningPlayer = activePlayers.any(
        (player) => player.id == previousPlayerId,
      );

      if (!isReturningPlayer &&
          activePlayers.length >= GameConstants.maxPlayers) {
        _showSnack('That table is full.');
        return;
      }

      final normalizedName = name.toLowerCase();
      final nameTaken = activePlayers.any(
        (player) =>
            player.id != previousPlayerId &&
            player.name.trim().toLowerCase() == normalizedName,
      );
      if (nameTaken) {
        _showSnack('That name is already taken in this lobby.');
        return;
      }

      final usedColors = existingPlayers.map((p) => p.avatarColor).toSet();
      final availableColor = _pickAvatarColor(usedColors);

      final player = await playerService.joinRoom(
        roomId: room.id,
        name: name,
        avatarColor: availableColor,
        previousPlayerId: previousPlayerId,
      );
      _rememberPlayerForRoom(room.id, player.id);
      await ref.read(realtimeServiceProvider).broadcast(
        room.code,
        'player_joined',
        {'player_id': player.id},
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

  String? _rememberedPlayerForRoom(String roomId) {
    final prefs = ref.read(sharedPrefsProvider);
    return prefs.getString(_playerMemoryKey(roomId));
  }

  void _rememberPlayerForRoom(String roomId, String playerId) {
    final prefs = ref.read(sharedPrefsProvider);
    prefs.setString(_playerMemoryKey(roomId), playerId);
  }

  String _playerMemoryKey(String roomId) => 'lobby_player_id_$roomId';

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _goPremium() {
    if (kIsWeb) return;

    ref.read(audioServiceProvider).playClick();
    ref.read(audioServiceProvider).startAmbience();
    context.pushNamed('premium');
  }

  void _showHowToPlaySheet() {
    ref.read(audioServiceProvider).playClick();
    _showHomeSheet(
      title: 'HOW TO PLAY',
      icon: Icons.menu_book_rounded,
      child: Column(
        children: [
          _sheetStep('1', 'Answer numerical party questions.'),
          _sheetStep('2', 'All guesses land on the betting board.'),
          _sheetStep('3', 'Bet chips on the closest guess without going over.'),
          _sheetStep('4', 'Correct bets pay out. Most chips wins.'),
        ],
      ),
    );
  }

  void _showSettingsSheet() {
    ref.read(audioServiceProvider).playClick();
    final audioService = ref.read(audioServiceProvider);

    _showHomeSheet(
      title: 'SETTINGS',
      icon: Icons.settings_rounded,
      child: StatefulBuilder(
        builder: (context, setModalState) {
          final isMuted = audioService.isMuted;
          return Column(
            children: [
              Container(
                height: 72,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF06351F).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.brassLight.withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: AppColors.brassLight,
                      size: 30,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'SOUND',
                        style: _homeTextStyle(
                          color: AppColors.ivory,
                          size: 26,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: !isMuted,
                      activeThumbColor: AppColors.brassLight,
                      activeTrackColor: AppColors.brass,
                      inactiveThumbColor: AppColors.textMuted,
                      inactiveTrackColor: Colors.black26,
                      onChanged: (enabled) async {
                        await audioService.setMuted(!enabled);
                        setModalState(() {});
                        if (mounted) setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showHomeSheet({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFF7D5),
                    Color(0xFFF2D691),
                    Color(0xFFFFF4C3),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.ivory, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _roundIcon(icon, size: 52, iconSize: 29),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: _homeTextStyle(
                            color: AppColors.feltDark,
                            size: 34,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: AppColors.feltDark,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.38),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  child,
                ],
              ),
            ),
          ),
        );
      },
    );
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
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.18,
                  colors: [
                    const Color(0xFF17844E).withValues(alpha: 0.28),
                    const Color(0xFF052719).withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.36),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, _) {
                  final designHeight = kIsWeb ? 720.0 : 840.0;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 420,
                          height: designHeight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildLogoMarquee(),
                              const SizedBox(height: 6),
                              _buildSubtitleWithLines(),
                              SizedBox(height: kIsWeb ? 16 : 18),
                              if (kIsWeb) ...[
                                _buildWebPlayerBadge(),
                                const SizedBox(height: 12),
                              ],
                              _buildNamePanel(),
                              const SizedBox(height: 10),
                              if (!kIsWeb) ...[
                                _buildHeroActionButton(
                                  label: 'CREATE LOBBY',
                                  icon: Icons.groups_rounded,
                                  isLoading: _isLoading,
                                  onPressed: _isLoading ? null : _createRoom,
                                ),
                                const SizedBox(height: 10),
                              ],
                              _buildJoinLobbyPanel(),
                              if (!kIsWeb) ...[
                                const SizedBox(height: 10),
                                _buildPremiumButton(),
                              ],
                              SizedBox(height: kIsWeb ? 14 : 16),
                              _buildBottomActions(),
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

  Widget _buildLogoMarquee() {
    return SizedBox(
      height: 188,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.62,
                  colors: [
                    AppColors.brassLight.withValues(alpha: 0.34),
                    AppColors.brass.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 6,
            right: 6,
            bottom: 8,
            child: Container(
              height: 22,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brassLight.withValues(alpha: 0.34),
                    blurRadius: 42,
                    spreadRadius: 18,
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 30,
            top: 72,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.brassLight,
              size: 34,
            ),
          ),
          const Positioned(
            right: 34,
            top: 82,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.brassLight,
              size: 30,
            ),
          ),
          Positioned.fill(
            child: CachedAssetImage(AppAssetPaths.logo, fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitleWithLines() {
    return Row(
      children: [
        Expanded(child: _goldRule()),
        const SizedBox(width: 16),
        Text(
          'PARTY QUIZ & BETTING GAME',
          style: _homeTextStyle(
            color: AppColors.brassLight,
            size: 17,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: _goldRule()),
      ],
    );
  }

  Widget _buildWebPlayerBadge() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF062E1F).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.brassLight.withValues(alpha: 0.56),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.sports_esports_rounded,
            color: AppColors.brassLight,
            size: 25,
          ),
          const SizedBox(width: 10),
          Text(
            'WEB PLAYER MODE',
            style: _homeTextStyle(
              color: AppColors.ivory,
              size: 24,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNamePanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: _creamPanelDecoration(radius: 28),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _thinGoldRule()),
              const SizedBox(width: 10),
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.brass,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'YOUR NAME',
                style: _homeTextStyle(
                  color: AppColors.feltDark,
                  size: 27,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.brass,
                size: 16,
              ),
              const SizedBox(width: 10),
              Expanded(child: _thinGoldRule()),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 66,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF948D7D),
                  Color(0xFF5D584C),
                  Color(0xFF7E7462),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: TextField(
              controller: _nameController,
              textAlign: TextAlign.left,
              style: _homeTextStyle(
                color: AppColors.ivory,
                size: 26,
                letterSpacing: 0,
              ),
              cursorColor: AppColors.brassLight,
              decoration: InputDecoration(
                filled: false,
                hintText: 'Your name',
                hintStyle: _homeTextStyle(
                  color: AppColors.ivory.withValues(alpha: 0.6),
                  size: 25,
                  letterSpacing: 0,
                ),
                prefixIcon: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.brassLight,
                  size: 30,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 19,
                  horizontal: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return SizedBox(
      height: 76,
      child: DecoratedBox(
        decoration: _goldButtonDecoration(radius: 22),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _roundIcon(icon),
                  const SizedBox(width: 18),
                  Expanded(
                    child: isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: AppColors.ink,
                              ),
                            ),
                          )
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              label,
                              style: _homeTextStyle(
                                color: AppColors.ink,
                                size: 47,
                                letterSpacing: 0,
                                shadow: true,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.ink,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJoinLobbyPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF062E1F).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: AppColors.brassLight.withValues(alpha: 0.78),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _outlineRoundIcon(Icons.login_rounded),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  kIsWeb ? 'JOIN GAME' : 'JOIN LOBBY',
                  style: _homeTextStyle(
                    color: AppColors.ivory,
                    size: 41,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.brassLight,
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildRoomCodeField()),
              const SizedBox(width: 14),
              SizedBox(
                width: 74,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _joinRoom,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: AppColors.brass,
                    foregroundColor: AppColors.ink,
                    elevation: 7,
                    shadowColor: Colors.black45,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, size: 38),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCodeField() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF042819).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.brassLight.withValues(alpha: 0.32),
          width: 1.4,
        ),
      ),
      child: TextField(
        controller: _roomCodeController,
        textAlign: TextAlign.left,
        textCapitalization: TextCapitalization.characters,
        maxLength: GameConstants.roomCodeLength,
        style: _homeTextStyle(
          color: AppColors.ivory,
          size: 24,
          letterSpacing: 4,
        ),
        cursorColor: AppColors.brassLight,
        decoration: InputDecoration(
          hintText: 'Room code',
          counterText: '',
          hintStyle: _homeTextStyle(
            color: AppColors.ivory.withValues(alpha: 0.46),
            size: 22,
            letterSpacing: 3,
          ),
          prefixIcon: const Icon(
            Icons.tag_rounded,
            color: AppColors.brassLight,
            size: 28,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 17,
            horizontal: 12,
          ),
        ),
        onSubmitted: (_) => _joinRoom(),
      ),
    );
  }

  Widget _buildPremiumButton() {
    return SizedBox(
      height: 70,
      child: DecoratedBox(
        decoration: _goldButtonDecoration(radius: 22, light: true),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: _goPremium,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _roundIcon(Icons.workspace_premium_rounded),
                  const SizedBox(width: 18),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'GO PREMIUM',
                        style: _homeTextStyle(
                          color: AppColors.ink,
                          size: 43,
                          letterSpacing: 0,
                          shadow: true,
                        ),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.ink,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Row(
      children: [
        Expanded(
          child: _bottomActionButton(
            label: 'HOW TO PLAY',
            icon: Icons.menu_book_rounded,
            onTap: _showHowToPlaySheet,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _bottomActionButton(
            label: 'SETTINGS',
            icon: Icons.settings_rounded,
            onTap: _showSettingsSheet,
          ),
        ),
      ],
    );
  }

  Widget _bottomActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 74,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF06351F).withValues(alpha: 0.64),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.brassLight.withValues(alpha: 0.7),
                width: 1.6,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppColors.brassLight, size: 30),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: _homeTextStyle(
                      color: AppColors.ivory,
                      size: 20,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetStep(String number, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF06351F).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brassLight.withValues(alpha: 0.42)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.brassLight,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: _homeTextStyle(
                color: AppColors.ink,
                size: 20,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.ivory,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1.18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundIcon(IconData icon, {double size = 58, double iconSize = 30}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF4D277), Color(0xFFAD842F)],
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.ivory.withValues(alpha: 0.28),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: AppColors.ink, size: iconSize),
    );
  }

  Widget _outlineRoundIcon(IconData icon) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.brassLight, width: 2),
      ),
      child: Icon(icon, color: AppColors.ivory, size: 34),
    );
  }

  Widget _goldRule() {
    return Container(
      height: 1.5,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.brassLight.withValues(alpha: 0.75),
          ],
        ),
      ),
    );
  }

  Widget _thinGoldRule() {
    return Container(
      height: 1.2,
      color: AppColors.brass.withValues(alpha: 0.34),
    );
  }

  BoxDecoration _creamPanelDecoration({required double radius}) {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF7D5), Color(0xFFF3E2B8), Color(0xFFFFFBE7)],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.ivory, width: 1.8),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 18,
          offset: const Offset(0, 9),
        ),
      ],
    );
  }

  BoxDecoration _goldButtonDecoration({
    required double radius,
    bool light = false,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: light
            ? const [Color(0xFFFFF7C5), Color(0xFFFFCE48), Color(0xFFFFF1A4)]
            : const [Color(0xFFFFF099), Color(0xFFFFC12A), Color(0xFFE19513)],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: AppColors.ivory.withValues(alpha: 0.72),
        width: 1.7,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.34),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  TextStyle _homeTextStyle({
    required Color color,
    required double size,
    required double letterSpacing,
    bool shadow = false,
  }) {
    return TextStyle(
      fontFamily: 'RehnCondensed',
      color: color,
      fontSize: size,
      fontWeight: FontWeight.w900,
      height: 0.95,
      letterSpacing: letterSpacing,
      shadows: shadow
          ? [
              Shadow(
                color: Colors.white.withValues(alpha: 0.4),
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
              Shadow(
                color: Colors.black.withValues(alpha: 0.38),
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ]
          : null,
    );
  }
}
