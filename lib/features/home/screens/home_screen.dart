import 'dart:math';

import 'package:flutter/foundation.dart'
    show ValueListenable, ValueNotifier, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/game_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_asset_image.dart';
import '../../../core/widgets/web_promo_banner.dart';
import '../../../core/router/app_router.dart';
import '../../../features/game/screens/debug_scene_editor_screen.dart';
import '../../../features/party/theme/party_palette.dart';
import '../../../features/room/providers/room_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final String? prefilledRoomCode;
  const HomeScreen({super.key, this.prefilledRoomCode});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  final _nameController = TextEditingController();
  final _roomCodeController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _random = Random();
  bool _isLoading = false;
  String? _prefilledRoomCode;
  bool _showQrJoinGuide = false;

  @override
  void initState() {
    super.initState();
    _prefilledRoomCode = widget.prefilledRoomCode;
    if (_prefilledRoomCode != null && _prefilledRoomCode!.isNotEmpty) {
      _roomCodeController.text = _prefilledRoomCode!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final skipAutoJoin = ref.read(skipAutoJoinProvider);
      final shouldShowOnboarding =
          !kIsWeb &&
          !skipAutoJoin &&
          !ref.read(onboardingSeenProvider) &&
          (_prefilledRoomCode == null || _prefilledRoomCode!.isEmpty);
      if (shouldShowOnboarding) {
        if (!mounted) return;
        context.goNamed('onboarding');
        return;
      }

      if (skipAutoJoin) {
        ref.read(skipAutoJoinProvider.notifier).set(false);
        final savedName = ref.read(playerNameProvider);
        if (savedName.isNotEmpty) {
          _nameController.text = savedName;
        }
        ref.read(audioServiceProvider).startMainBgm();
        ref.read(gameServiceProvider).prefetchQuestions();
        return;
      }

      final savedName = ref.read(playerNameProvider);
      if (savedName.isNotEmpty) {
        _nameController.text = savedName;
      }
      ref.read(audioServiceProvider).startMainBgm();
      ref.read(gameServiceProvider).prefetchQuestions();

      if (savedName.isNotEmpty &&
          _prefilledRoomCode != null &&
          _prefilledRoomCode!.isNotEmpty) {
        _joinRoom();
      } else if (savedName.isEmpty &&
          _prefilledRoomCode != null &&
          _prefilledRoomCode!.isNotEmpty) {
        // QR arrival with no name — activate guided flow
        setState(() => _showQrJoinGuide = true);
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _nameFocusNode.requestFocus();
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _nameFocusNode.dispose();
    _nameController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  Future<void> _showCreateLobbySetup() async {
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
    final isPremium = await ref
        .read(premiumStatusProvider.future)
        .catchError((_) => false);
    if (!mounted) return;

    final categoriesFuture = ref
        .read(gameServiceProvider)
        .getQuestionCategories();
    var selectedRounds = isPremium
        ? GameConstants.defaultRounds
        : GameConstants.freeMaxRounds;
    final selectedPartyChallengesPerPlayer =
        GameConstants.partyDefaultChallengesPerPlayer;
    var selectedMaxPlayers = GameConstants.freeMaxPlayers;
    var selectedCategory = GameConstants.defaultCategory;
    var selectedMode = GameMode.classic;
    final setupThemeMode = ValueNotifier<GameMode>(selectedMode);

    _showHomeSheet(
      title: 'SETUP',
      icon: Icons.tune_rounded,
      child: StatefulBuilder(
        builder: (context, setModalState) {
          final usesPremiumSetup =
              !isPremium &&
              (selectedMaxPlayers > GameConstants.freeMaxPlayers ||
                  selectedRounds > GameConstants.freeMaxRounds ||
                  (selectedMode == GameMode.classic &&
                      selectedCategory != GameConstants.defaultCategory));

          return Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color:
                      (selectedMode == GameMode.party
                              ? PartyPalette.nightDeep
                              : AppColors.ink)
                          .withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        (selectedMode == GameMode.party
                                ? PartyPalette.orangeSoft
                                : AppColors.brass)
                            .withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    for (final mode in GameMode.values)
                      Expanded(
                        child: _modeSetupButton(
                          mode: mode,
                          selected: selectedMode == mode,
                          onTap: () {
                            setModalState(() {
                              selectedMode = mode;
                              setupThemeMode.value = mode;
                              if (mode == GameMode.party &&
                                  selectedMaxPlayers < 3) {
                                selectedMaxPlayers = 3;
                              }
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (selectedMode == GameMode.classic) ...[
                _setupSlider(
                  icon: Icons.casino_rounded,
                  label: 'ROUNDS',
                  value: selectedRounds,
                  min: GameConstants.minRounds,
                  max: GameConstants.maxRounds,
                  premiumStart: GameConstants.freeMaxRounds + 1,
                  isPremiumLocked:
                      !isPremium &&
                      selectedRounds > GameConstants.freeMaxRounds,
                  onChanged: (value) {
                    setModalState(() => selectedRounds = value);
                  },
                ),
                const SizedBox(height: 10),
                _setupSlider(
                  icon: Icons.groups_rounded,
                  label: 'PLAYERS',
                  value: selectedMaxPlayers,
                  min: GameConstants.minPlayers,
                  max: GameConstants.maxPlayers,
                  valueText: selectedMaxPlayers == GameConstants.maxPlayers
                      ? '${GameConstants.maxPlayers}+'
                      : '$selectedMaxPlayers',
                  premiumStart: GameConstants.freeMaxPlayers + 1,
                  isPremiumLocked:
                      !isPremium &&
                      selectedMaxPlayers > GameConstants.freeMaxPlayers,
                  partyTheme: false,
                  onChanged: (value) {
                    setModalState(() => selectedMaxPlayers = value);
                  },
                ),
              ] else ...[
                _setupSlider(
                  icon: Icons.groups_rounded,
                  label: 'PLAYERS',
                  value: selectedMaxPlayers,
                  min: 3,
                  max: GameConstants.maxPlayers,
                  valueText: selectedMaxPlayers == GameConstants.maxPlayers
                      ? '${GameConstants.maxPlayers}+'
                      : '$selectedMaxPlayers',
                  premiumStart: GameConstants.freeMaxPlayers + 1,
                  isPremiumLocked:
                      !isPremium &&
                      selectedMaxPlayers > GameConstants.freeMaxPlayers,
                  partyTheme: true,
                  onChanged: (value) {
                    setModalState(() => selectedMaxPlayers = value);
                  },
                ),
                const SizedBox(height: 10),
                _setupSlider(
                  icon: Icons.casino_rounded,
                  label: 'ROUNDS',
                  value: selectedRounds,
                  min: GameConstants.minRounds,
                  max: GameConstants.maxRounds,
                  premiumStart: GameConstants.freeMaxRounds + 1,
                  isPremiumLocked:
                      !isPremium &&
                      selectedRounds > GameConstants.freeMaxRounds,
                  partyTheme: true,
                  onChanged: (value) {
                    setModalState(() => selectedRounds = value);
                  },
                ),
              ],
              if (selectedMode == GameMode.classic) ...[
                const SizedBox(height: 10),
                FutureBuilder<List<String>>(
                  future: categoriesFuture,
                  builder: (context, snapshot) {
                    final categories = [
                      GameConstants.defaultCategory,
                      ...?snapshot.data,
                    ];
                    return _categoryPicker(
                      categories: categories,
                      selectedCategory: selectedCategory,
                      isPremium: isPremium,
                      onSelected: (category) {
                        setModalState(() => selectedCategory = category);
                      },
                    );
                  },
                ),
              ] else ...[
                const SizedBox(height: 18),
                Expanded(child: _partyModeGuideCard()),
              ],
              if (selectedMode == GameMode.classic) const Spacer(),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (usesPremiumSetup) {
                      _goPremium();
                      return;
                    }
                    _createRoom(
                      maxRounds: selectedRounds,
                      maxPlayers: selectedMaxPlayers,
                      category: selectedCategory,
                      gameMode: selectedMode,
                      partyChallengesPerPlayer:
                          selectedPartyChallengesPerPlayer,
                      partyAvailableItems: const <String>[],
                    );
                  },
                  icon: Icon(
                    usesPremiumSetup
                        ? Icons.workspace_premium_rounded
                        : Icons.groups_rounded,
                    size: 25,
                  ),
                  label: Text(
                    usesPremiumSetup ? 'UPGRADE TO CREATE' : 'CREATE LOBBY',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: usesPremiumSetup
                        ? AppColors.brassLight
                        : selectedMode == GameMode.party
                        ? PartyPalette.orangeSoft
                        : AppColors.brass,
                    foregroundColor: AppColors.ink,
                    elevation: 10,
                    shadowColor:
                        (selectedMode == GameMode.party
                                ? PartyPalette.orange
                                : AppColors.brass)
                            .withValues(alpha: 0.38),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      themeMode: setupThemeMode,
    );
  }

  Future<void> _createRoom({
    required int maxRounds,
    required int maxPlayers,
    required String category,
    required GameMode gameMode,
    int partyChallengesPerPlayer =
        GameConstants.partyDefaultChallengesPerPlayer,
    List<String> partyAvailableItems = const [],
  }) async {
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
    ref.read(audioServiceProvider).startMainBgm();
    setState(() => _isLoading = true);
    ref.read(playerNameProvider.notifier).setName(name);

    try {
      final roomService = ref.read(roomServiceProvider);
      final playerService = ref.read(playerServiceProvider);
      final deviceId = ref.read(deviceIdProvider);
      var room = await roomService.createRoom(
        'temp',
        maxRounds: maxRounds,
        maxPlayers: maxPlayers,
        category: category,
        gameMode: gameMode,
      );

      final player = await playerService.joinRoom(
        roomId: room.id,
        deviceId: deviceId,
        name: name,
        avatarColor: _pickAvatarColor(),
        isHost: true,
      );

      if (gameMode == GameMode.party) {
        room = await roomService.configurePartyRoom(
          roomId: room.id,
          availableItems: partyAvailableItems,
          challengesPerPlayer: partyChallengesPerPlayer,
        );
      }

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
      _nameFocusNode.requestFocus();
      return;
    }
    if (_showQrJoinGuide) {
      setState(() => _showQrJoinGuide = false);
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
    ref.read(audioServiceProvider).startMainBgm();
    setState(() => _isLoading = true);
    try {
      final roomService = ref.read(roomServiceProvider);
      final playerService = ref.read(playerServiceProvider);
      final deviceId = ref.read(deviceIdProvider);
      final room = await roomService.findRoomByCode(code);
      if (room == null) {
        _showSnack('Room not found.');
        return;
      }

      if (!room.canJoinLobby) {
        _showSnack('That table is already playing.');
        return;
      }

      final player = await playerService.joinRoom(
        roomId: room.id,
        deviceId: deviceId,
        name: name,
        avatarColor: _pickAvatarColor(),
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
    if (kIsWeb) return;

    ref.read(audioServiceProvider).playClick();
    ref.read(audioServiceProvider).startMainBgm();
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
                height: 76,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1E1E1E),
                      Color(0xFF121212),
                      Color(0xFF080808),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.brassLight.withValues(alpha: 0.34),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.brassLight.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.brassLight.withValues(alpha: 0.38),
                        ),
                      ),
                      child: Icon(
                        isMuted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: AppColors.brassLight,
                        size: 27,
                      ),
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
                    Text(
                      isMuted ? 'OFF' : 'ON',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
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
    ValueListenable<GameMode>? themeMode,
  }) {
    final sheet = showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      isScrollControlled: true,
      builder: (context) {
        Widget buildSurface(GameMode mode) {
          final isParty = mode == GameMode.party;
          final isSetup = title == 'SETUP';
          final mediaQuery = MediaQuery.of(context);
          final setupHeight = min(
            780.0,
            max(
              0.0,
              mediaQuery.size.height -
                  mediaQuery.padding.vertical -
                  mediaQuery.viewInsets.bottom -
                  28,
            ),
          );
          final accent = isParty
              ? PartyPalette.orangeSoft
              : AppColors.brassLight;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                0,
                18,
                18 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: ConstrainedBox(
                constraints: isSetup
                    ? BoxConstraints.tightFor(height: setupHeight)
                    : BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.97,
                      ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  decoration: BoxDecoration(
                    gradient: isParty
                        ? PartyPalette.backgroundGradient
                        : const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF0E4C34),
                              Color(0xFF062C1B),
                              Color(0xFF1A0E09),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: accent.withValues(alpha: isParty ? 0.56 : 0.46),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 28,
                        offset: const Offset(0, 16),
                      ),
                      if (isParty)
                        BoxShadow(
                          color: PartyPalette.orange.withValues(alpha: 0.12),
                          blurRadius: 34,
                          spreadRadius: -8,
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
                              isParty && title == 'SETUP'
                                  ? 'PARTY SETUP'
                                  : title,
                              style: _homeTextStyle(
                                color: AppColors.ivory,
                                size: 34,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                            color: AppColors.ivory,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (isSetup)
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return ClipRect(
                                child: Align(
                                  alignment: Alignment.center,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.center,
                                    child: SizedBox(
                                      width: constraints.maxWidth,
                                      height: constraints.maxHeight,
                                      child: child,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      else
                        Flexible(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: child,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        if (themeMode == null) return buildSurface(GameMode.classic);
        return ValueListenableBuilder<GameMode>(
          valueListenable: themeMode,
          builder: (context, mode, _) => buildSurface(mode),
        );
      },
    );
    if (themeMode is ValueNotifier<GameMode>) {
      sheet.whenComplete(themeMode.dispose);
    }
  }

  Widget _modeSetupButton({
    required GameMode mode,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isParty = mode == GameMode.party;
    final accent = isParty ? PartyPalette.orangeSoft : AppColors.brassLight;
    return Material(
      color: selected ? accent : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isParty ? Icons.celebration_rounded : Icons.casino_rounded,
                size: 19,
                color: selected ? AppColors.ink : accent,
              ),
              const SizedBox(width: 7),
              Text(
                mode.displayName,
                style: GoogleFonts.outfit(
                  color: selected ? AppColors.ink : AppColors.ivory,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _partyModeGuideCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      decoration: BoxDecoration(
        color: PartyPalette.nightDeep.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: PartyPalette.orangeSoft.withValues(alpha: 0.38),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: PartyPalette.orange.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.how_to_vote_rounded,
                  color: PartyPalette.orangeSoft,
                  size: 18,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'PARTY POLL — READ THE ROOM',
                  style: GoogleFonts.outfit(
                    color: PartyPalette.cream,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _partyGuideBullet(
            icon: Icons.groups_rounded,
            title: 'ONE QUESTION, EVERYONE PLAYS',
            description:
                'Pick who fits the prompt. Your pick is your vote; your chip is your risk.',
          ),
          const SizedBox(height: 18),
          _partyGuideBullet(
            icon: Icons.local_fire_department_rounded,
            title: 'SPLIT OR COMMIT',
            description:
                'Back one player for two votes, or two players for one vote each. Chip value does not change voting power.',
          ),
          const SizedBox(height: 18),
          _partyGuideBullet(
            icon: Icons.emoji_events_rounded,
            title: 'REVEAL, THEN SETTLE',
            description:
                'Bets stay hidden until the reveal. Winning picks pay 2×; every losing stake is simply lost.',
          ),
        ],
      ),
    );
  }

  Widget _partyGuideBullet({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: PartyPalette.orangeSoft),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$title: ',
                  style: GoogleFonts.outfit(
                    color: PartyPalette.cream,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: description,
                  style: GoogleFonts.outfit(
                    color: PartyPalette.creamMuted.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.42,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _setupSlider({
    bool partyTheme = false,
    required IconData icon,
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
    int? premiumStart,
    bool isPremiumLocked = false,
    String? valueText,
    Widget? trailing,
  }) {
    final premiumRange = premiumStart != null && premiumStart <= max
        ? premiumStart
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isPremiumLocked
              ? const [Color(0xFF5B3917), Color(0xFF2B170C)]
              : partyTheme
              ? const [Color(0xFF2B614C), Color(0xFF12352C)]
              : const [Color(0xFF083D28), Color(0xFF052416)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              (isPremiumLocked
                      ? AppColors.brassLight
                      : partyTheme
                      ? PartyPalette.orangeSoft
                      : AppColors.feltLight)
                  .withValues(alpha: 0.48),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: partyTheme
                    ? PartyPalette.orangeSoft
                    : AppColors.brassLight,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: _homeTextStyle(
                      color: AppColors.ivory,
                      size: 22,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (trailing != null) trailing,
              if (premiumRange != null) ...[
                _premiumBadge('$premiumRange+'),
                const SizedBox(width: 8),
              ],
              if (isPremiumLocked) ...[
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.brassLight,
                  size: 18,
                ),
                const SizedBox(width: 7),
              ],
              Container(
                width: valueText != null && valueText.length > 2 ? 52 : 42,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: isPremiumLocked
                      ? AppColors.goldGradient
                      : const LinearGradient(
                          colors: [Color(0xFFF7E6C2), Color(0xFFD7A84A)],
                        ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  valueText ?? '$value',
                  style: _homeTextStyle(
                    color: AppColors.ink,
                    size: 22,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: partyTheme
                  ? PartyPalette.orangeSoft
                  : AppColors.brassLight,
              inactiveTrackColor: AppColors.ivory.withValues(alpha: 0.18),
              thumbColor: partyTheme
                  ? PartyPalette.orangeSoft
                  : AppColors.brassLight,
              overlayColor:
                  (partyTheme ? PartyPalette.orangeSoft : AppColors.brassLight)
                      .withValues(alpha: 0.18),
              trackHeight: 6,
              tickMarkShape: SliderTickMarkShape.noTickMark,
            ),
            child: Stack(
              children: [
                Slider(
                  min: min.toDouble(),
                  max: max.toDouble(),
                  divisions: max - min,
                  value: value.clamp(min, max).toDouble(),
                  onChanged: (next) => onChanged(next.round()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.brassLight.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.brassLight.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            color: AppColors.brassLight,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.brassLight,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryPicker({
    required List<String> categories,
    required String selectedCategory,
    required bool isPremium,
    required ValueChanged<String> onSelected,
  }) {
    final lockedSelection =
        !isPremium && selectedCategory != GameConstants.defaultCategory;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: lockedSelection
              ? const [Color(0xFF5B3917), Color(0xFF28150B)]
              : const [Color(0xFF083D28), Color(0xFF052416)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (lockedSelection ? AppColors.brassLight : AppColors.feltLight)
              .withValues(alpha: 0.48),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.category_rounded,
                color: AppColors.brassLight,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                'CATEGORY',
                style: _homeTextStyle(
                  color: AppColors.ivory,
                  size: 22,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              if (lockedSelection) _premiumBadge('PREMIUM'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.ivory.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  lockedSelection
                      ? Icons.lock_rounded
                      : Icons.check_circle_rounded,
                  color: lockedSelection
                      ? AppColors.brassLight
                      : AppColors.neonGreen,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selectedCategory,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ivory,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (lockedSelection)
                  const Text(
                    'PREMIUM',
                    style: TextStyle(
                      color: AppColors.brassLight,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              final itemWidth = (constraints.maxWidth - gap) / 2;
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 178),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: categories.map((category) {
                      final selected = selectedCategory == category;
                      final locked =
                          !isPremium &&
                          category != GameConstants.defaultCategory;
                      return SizedBox(
                        width: itemWidth,
                        height: 46,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => onSelected(category),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.brassLight
                                  : Colors.black.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selected
                                    ? AppColors.ivory
                                    : AppColors.brassLight.withValues(
                                        alpha: 0.22,
                                      ),
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.brassLight.withValues(
                                          alpha: 0.22,
                                        ),
                                        blurRadius: 12,
                                        offset: const Offset(0, 5),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                if (locked) ...[
                                  Icon(
                                    Icons.lock_rounded,
                                    size: 14,
                                    color: selected
                                        ? AppColors.ink
                                        : AppColors.brassLight,
                                  ),
                                  const SizedBox(width: 5),
                                ],
                                Flexible(
                                  child: Text(
                                    category,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: selected
                                          ? AppColors.ink
                                          : AppColors.ivory,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
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
                builder: (context, constraints) {
                  final designHeight = kIsWeb ? 780.0 : 840.0;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
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
                              SizedBox(height: kIsWeb ? 12 : 18),
                              if (kIsWeb) ...[
                                _dimIfGuide(child: _buildWebPlayerBadge()),
                                const SizedBox(height: 10),
                              ],
                              _buildNamePanel(),
                              const SizedBox(height: 10),
                              if (!kIsWeb) ...[
                                _dimIfGuide(
                                  child: _buildHeroActionButton(
                                    label: 'CREATE LOBBY',
                                    icon: Icons.groups_rounded,
                                    isLoading: _isLoading,
                                    onPressed: _isLoading
                                        ? null
                                        : _showCreateLobbySetup,
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                              _buildJoinLobbyPanel(),
                              if (!kIsWeb) ...[
                                const SizedBox(height: 10),
                                _dimIfGuide(child: _buildPremiumButton()),
                              ],
                              SizedBox(height: kIsWeb ? 10 : 12),
                              _dimIfGuide(child: _buildBottomActions()),
                              if (kIsWeb) ...[
                                const SizedBox(height: 12),
                                _dimIfGuide(child: const WebPromoBanner()),
                              ],
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
          if (kDebugMode)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Preview Onboarding',
                    onPressed: () => context.pushNamed('onboarding'),
                    icon: const Icon(Icons.slideshow_rounded),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    tooltip: 'Screenshot scene editor',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DebugSceneEditorScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.design_services_rounded),
                  ),
                ],
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

  Widget _dimIfGuide({required Widget child}) {
    if (!_showQrJoinGuide) return child;
    return AnimatedOpacity(
      opacity: 0.38,
      duration: const Duration(milliseconds: 400),
      child: IgnorePointer(child: child),
    );
  }

  Widget _buildNamePanel() {
    final panel = Container(
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
                _showQrJoinGuide ? 'ENTER YOUR NAME' : 'YOUR NAME',
                style: _homeTextStyle(
                  color: AppColors.ivory,
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
                  Color(0xFF0B3D2A),
                  Color(0xFF042416),
                  Color(0xFF1C120C),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _showQrJoinGuide
                    ? AppColors.brassLight.withValues(alpha: 0.9)
                    : AppColors.brassLight.withValues(alpha: 0.32),
                width: _showQrJoinGuide ? 2.4 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
                if (_showQrJoinGuide)
                  BoxShadow(
                    color: AppColors.brassLight.withValues(alpha: 0.6),
                    blurRadius: 22,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: TextField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              textAlign: TextAlign.left,
              style: _homeTextStyle(
                color: AppColors.ivory,
                size: 26,
                letterSpacing: 0,
              ),
              cursorColor: AppColors.brassLight,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _joinRoom(),
              decoration: InputDecoration(
                filled: false,
                hintText: _showQrJoinGuide
                    ? 'Type your name to join'
                    : 'Your name',
                hintStyle: _homeTextStyle(
                  color: AppColors.ivory.withValues(alpha: 0.6),
                  size: _showQrJoinGuide ? 22 : 25,
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

    if (!_showQrJoinGuide) return panel;

    return panel;
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
          width: _showQrJoinGuide ? 2.4 : 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          if (_showQrJoinGuide)
            BoxShadow(
              color: AppColors.brassLight.withValues(alpha: 0.3),
              blurRadius: 28,
              spreadRadius: 4,
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
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildRoomCodeField()),
              const SizedBox(width: 14),
              _buildJoinButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJoinButton() {
    final isQrJoin = _showQrJoinGuide;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      width: isQrJoin ? 118 : 74,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: isQrJoin
            ? [
                BoxShadow(
                  color: AppColors.brassLight.withValues(alpha: 0.55),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _joinRoom,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          backgroundColor: AppColors.brass,
          foregroundColor: AppColors.ink,
          elevation: 7,
          shadowColor: Colors.black45,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: Icon(
          isQrJoin ? Icons.login_rounded : Icons.arrow_forward_rounded,
          size: 30,
        ),
        label: isQrJoin
            ? const Text('JOIN', style: TextStyle(fontWeight: FontWeight.w900))
            : const SizedBox.shrink(),
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
          color: _showQrJoinGuide
              ? AppColors.brassLight.withValues(alpha: 0.9)
              : AppColors.brassLight.withValues(alpha: 0.32),
          width: _showQrJoinGuide ? 1.8 : 1.4,
        ),
        boxShadow: _showQrJoinGuide
            ? [
                BoxShadow(
                  color: AppColors.brassLight.withValues(alpha: 0.5),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: _roomCodeController,
        textAlign: TextAlign.left,
        textCapitalization: TextCapitalization.characters,
        readOnly: _showQrJoinGuide,
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
          prefixIcon: Icon(
            _showQrJoinGuide ? Icons.qr_code_rounded : Icons.tag_rounded,
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
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0B442E),
                  Color(0xFF052A19),
                  Color(0xFF1B100A),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.brassLight.withValues(alpha: 0.48),
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF083D28), Color(0xFF052416)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.feltLight.withValues(alpha: 0.46)),
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
        colors: [Color(0xFF0E4C34), Color(0xFF062C1B), Color(0xFF1A0E09)],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: AppColors.brassLight.withValues(alpha: 0.44),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 22,
          offset: const Offset(0, 12),
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
