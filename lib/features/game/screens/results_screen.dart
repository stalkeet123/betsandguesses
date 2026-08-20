import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/constants/game_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_asset_image.dart';
import '../../../features/game/providers/game_providers.dart';
import '../../../features/player/models/player_model.dart';
import '../../../features/party/models/party_moment.dart';
import '../../../features/party/models/party_snapshot.dart';
import '../../../features/party/providers/party_local_media_provider.dart';

import '../../../features/room/models/room_model.dart';
import '../../../features/room/providers/room_providers.dart';

const _partyCardOrange = Color(0xFFE47A32);
const _partyCardOrangeSoft = Color(0xFFF0A060);

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
  List<PartyMoment> _partyMoments = const [];
  List<PartyRecapRound> _partyRecap = const [];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 5),
    );
    _confettiController.play();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final audio = ref.read(audioServiceProvider);
      audio.stopTransientEffects();
      audio.startLobbyMusic();
      audio.playEpicFanfare();
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

    final playersFuture = ref.read(playerServiceProvider).getPlayers(room.id);
    final recapFuture = room.gameMode == GameMode.party
        ? ref.read(partyGameServiceProvider).getRecap(room.id)
        : Future.value(const <PartyRecapRound>[]);
    final players = await playersFuture;
    players.sort((a, b) {
      final scoreOrder = b.bankScore.compareTo(a.bankScore);
      if (scoreOrder != 0) return scoreOrder;
      final nameOrder = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (nameOrder != 0) return nameOrder;
      return a.id.compareTo(b.id);
    });

    final partyMoments = ref
        .read(partyLocalMediaProvider)
        .where((moment) => moment.roomId == room.id)
        .toList(growable: false);
    var partyRecap = const <PartyRecapRound>[];
    try {
      partyRecap = await recapFuture;
    } catch (error, stackTrace) {
      debugPrint('Party recap load failed: $error\n$stackTrace');
    }

    if (mounted) {
      setState(() {
        _sortedPlayers = players;
        _partyMoments = partyMoments;
        _partyRecap = partyRecap;
      });
    }
  }

  List<Player> get _winners {
    if (_sortedPlayers.isEmpty) return const [];
    final winningScore = _sortedPlayers.first.bankScore;
    return _sortedPlayers
        .where((player) => player.bankScore == winningScore)
        .toList(growable: false);
  }

  int _rankForIndex(int index) {
    final score = _sortedPlayers[index].bankScore;
    return _sortedPlayers.indexWhere((player) => player.bankScore == score) + 1;
  }

  void _goHome() {
    if (_hasLeftResults) return;
    _hasLeftResults = true;
    final roomId = ref.read(currentRoomProvider)?.id;
    if (roomId != null) {
      ref.read(partyLocalMediaProvider.notifier).clearRoom(roomId);
    }
    ref.read(realtimeServiceProvider).leaveRoom(widget.roomCode);
    ref.read(currentRoomProvider.notifier).set(null);
    ref.read(currentPlayerProvider.notifier).set(null);
    ref.read(gameStateProvider.notifier).reset();
    context.goNamed('home');
  }

  void _openLobby(Room room) {
    if (!mounted || _hasLeftResults) return;
    _hasLeftResults = true;
    ref.read(partyLocalMediaProvider.notifier).clearRoom(room.id);
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
        final resetRoom = room.gameMode == GameMode.party
            ? await ref.read(partyGameServiceProvider).resetToLobby(room.id)
            : await ref.read(roomServiceProvider).resetToLobbyAtomic(room.id);
        if (resetRoom == null) {
          throw StateError('Secure lobby reset is unavailable.');
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

  String _formatPartyProfit(int value) {
    final formatted = _formatScore(value);
    return value > 0 ? '+$formatted' : formatted;
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

    final winners = _winners;
    final isParty = room?.gameMode == GameMode.party;

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
                              _buildWinnerCard(
                                winners,
                                compact: isCompact,
                                isParty: isParty,
                              ),
                              SizedBox(height: isCompact ? 8 : 12),
                              Expanded(
                                child: _buildScoreboard(isParty: isParty),
                              ),
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

  Widget _buildWinnerCard(
    List<Player> winners, {
    required bool compact,
    required bool isParty,
  }) {
    final hasWinner = winners.isNotEmpty;
    final isFullTie =
        winners.length > 1 && winners.length == _sortedPlayers.length;
    final ribbonLabel = isFullTie
        ? 'TIE GAME'
        : winners.length > 1
        ? 'CO-WINNERS'
        : 'WINNER';
    final winnerNames = isFullTie
        ? 'EVERYONE'
        : winners
              .map((player) => player.name)
              .join(winners.length == 2 ? ' & ' : ', ');

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        compact ? 12 : 16,
        16,
        compact ? 12 : 16,
      ),
      decoration: _darkPanelDecoration(radius: 18),
      child: !hasWinner
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
                _buildRibbon(ribbonLabel),
                SizedBox(height: compact ? 8 : 12),
                Text(
                  winnerNames,
                  maxLines: 3,
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
                  isParty ? 'FINAL PROFIT' : 'FINAL SCORE',
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
                    isParty
                        ? _formatPartyProfit(winners.first.bankScore)
                        : _formatScore(winners.first.bankScore),
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

  Widget _buildScoreboard({required bool isParty}) {
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
                  child: _buildBoardHeader(
                    isParty ? 'PROFIT' : 'FINAL SCORE',
                    alignRight: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _sortedPlayers.isEmpty
                ? Center(
                    child: Text(
                      isParty
                          ? 'Profits will appear here.'
                          : 'Scores will appear here.',
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
                    itemBuilder: (context, index) => _buildScoreRow(
                      _sortedPlayers[index],
                      index,
                      isParty: isParty,
                    ),
                  ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.05);
  }

  Widget _buildScoreRow(Player player, int index, {required bool isParty}) {
    final rank = _rankForIndex(index);
    final isWinner = rank == 1;
    final rankColor = switch (rank) {
      1 => AppColors.brassLight,
      2 => AppColors.chipSilver,
      3 => AppColors.neonOrange,
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
                  rank <= 3
                      ? Icons.military_tech_rounded
                      : Icons.circle_rounded,
                  color: rankColor,
                  size: rank <= 3 ? 24 : 10,
                ),
                const SizedBox(width: 4),
                Text(
                  '$rank',
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
                isParty
                    ? _formatPartyProfit(player.bankScore)
                    : _formatScore(player.bankScore),
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
    final room = ref.read(currentRoomProvider);
    return Column(
      children: [
        if (room?.gameMode == GameMode.party && _partyRecap.isNotEmpty) ...[
          SizedBox(
            width: double.infinity,
            child: _buildActionButton(
              label: 'PARTY RECAP',
              icon: Icons.photo_library_rounded,
              isGold: false,
              onTap: _openPartyRecap,
            ),
          ),
          const SizedBox(height: 8),
        ],
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

  void _openPartyRecap() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.ink,
      builder: (_) =>
          _PartyRecapSheet(rounds: _partyRecap, moments: _partyMoments),
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

class _PartyRecapSheet extends StatefulWidget {
  final List<PartyRecapRound> rounds;
  final List<PartyMoment> moments;

  const _PartyRecapSheet({required this.rounds, required this.moments});

  @override
  State<_PartyRecapSheet> createState() => _PartyRecapSheetState();
}

class _PartyRecapSheetState extends State<_PartyRecapSheet> {
  late final PageController _pageController;
  late final List<GlobalKey> _cardKeys;
  int _index = 0;
  bool _isSharing = false;
  final Map<int, Uint8List> _renderedCards = {};
  final Map<int, Future<Uint8List>> _renderJobs = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
    _cardKeys = List.generate(widget.rounds.length, (_) => GlobalKey());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.rounds.isNotEmpty) _prewarmCard(0);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  PartyMoment? _momentForRound(int roundNumber) {
    for (final moment in widget.moments) {
      if (moment.roundNumber == roundNumber) return moment;
    }
    return null;
  }

  Future<Uint8List> _renderCard(int index) {
    final cached = _renderedCards[index];
    if (cached != null) return Future.value(cached);
    return _renderJobs
        .putIfAbsent(index, () async {
          await WidgetsBinding.instance.endOfFrame;
          final boundary =
              _cardKeys[index].currentContext?.findRenderObject()
                  as RenderRepaintBoundary?;
          if (boundary == null) throw StateError('Recap card is not ready.');
          final image = await boundary.toImage(pixelRatio: 2);
          try {
            final byteData = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            if (byteData == null) {
              throw StateError('Recap image could not be made.');
            }
            final bytes = byteData.buffer.asUint8List();
            _renderedCards[index] = bytes;
            if (mounted) setState(() {});
            return bytes;
          } finally {
            image.dispose();
          }
        })
        .catchError((Object error) {
          _renderJobs.remove(index);
          throw error;
        });
  }

  void _prewarmCard(int index) {
    if (index < 0 ||
        index >= widget.rounds.length ||
        _renderedCards.containsKey(index)) {
      return;
    }
    _renderCard(index).catchError((_) => Uint8List(0));
  }

  Future<void> _shareCurrentCard() async {
    if (_isSharing) return;
    final shareBox = context.findRenderObject() as RenderBox?;
    setState(() => _isSharing = true);
    try {
      final bytes = await _renderCard(_index);
      final recap = widget.rounds[_index];
      final resultText = recap.challengeType == PartyChallengeType.choice
          ? 'chose ${recap.choiceLabel(recap.result) ?? 'an option'}'
          : recap.challengeType == PartyChallengeType.binary
          ? (recap.result == 1
                ? 'completed the challenge'
                : 'missed the challenge')
          : 'did ${recap.result} ${recap.answerUnit}';
      await SharePlus.instance.share(
        ShareParams(
          text:
              '${recap.performerName} $resultText — '
              'Bets & Guesses Party Mode',
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: 'bets-and-guesses-round-${recap.roundNumber}.png',
            ),
          ],
          fileNameOverrides: [
            'bets-and-guesses-round-${recap.roundNumber}.png',
          ],
          sharePositionOrigin: shareBox == null
              ? null
              : shareBox.localToGlobal(Offset.zero) & shareBox.size,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not share: $error')));
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ink,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'PARTY RECAP',
                    style: const TextStyle(
                      fontFamily: 'RehnCondensed',
                      color: AppColors.brassLight,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.ivory,
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.rounds.length,
              onPageChanged: (value) {
                setState(() => _index = value);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _prewarmCard(value);
                });
              },
              itemBuilder: (context, index) {
                final recap = widget.rounds[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: RepaintBoundary(
                        key: _cardKeys[index],
                        child: _PartyShareCard(
                          recap: recap,
                          moment: _momentForRound(recap.roundNumber),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_index + 1}/${widget.rounds.length}',
                    style: GoogleFonts.outfit(
                      color: AppColors.ivory.withValues(alpha: 0.62),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _isSharing ? null : _shareCurrentCard,
                  icon: _isSharing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ios_share_rounded),
                  label: Text(_isSharing ? 'PREPARING…' : 'SHARE'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brassLight,
                    foregroundColor: AppColors.ink,
                    minimumSize: const Size(150, 52),
                    textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PartyShareCard extends StatelessWidget {
  final PartyRecapRound recap;
  final PartyMoment? moment;

  const _PartyShareCard({required this.recap, required this.moment});

  @override
  Widget build(BuildContext context) {
    final isBinary = recap.challengeType == PartyChallengeType.binary;
    final isChoice = recap.challengeType == PartyChallengeType.choice;
    final headline = isChoice
        ? (recap.choiceLabel(recap.result) ?? 'CHOICE').toUpperCase()
        : isBinary
        ? (recap.result == 1 ? 'DID IT' : 'FAILED')
        : '${recap.result}\n${recap.answerUnit.toUpperCase()}';
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: ColoredBox(
        color: const Color(0xFF05080D),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (moment != null)
              Image.memory(moment!.bytes, fit: BoxFit.cover, cacheWidth: 1080)
            else
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF162A3A),
                      Color(0xFF08121D),
                      Color(0xFF24130B),
                    ],
                  ),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.42, 1],
                  colors: [
                    Color(0x44000000),
                    Color(0x55000000),
                    Color(0xF205080D),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        color: _partyCardOrangeSoft,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'BETS & GUESSES',
                        style: GoogleFonts.outfit(
                          color: AppColors.ivory,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'ROUND ${recap.roundNumber}',
                        style: GoogleFonts.outfit(
                          color: _partyCardOrangeSoft,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    recap.performerName.toUpperCase(),
                    style: GoogleFonts.outfit(
                      color: _partyCardOrangeSoft,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    headline,
                    style: const TextStyle(
                      fontFamily: 'RehnCondensed',
                      color: AppColors.ivory,
                      fontSize: 60,
                      fontWeight: FontWeight.w900,
                      height: 0.8,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isChoice
                        ? '${recap.performerName.toUpperCase()} CHOSE'
                        : isBinary
                        ? '${recap.durationSeconds}-SECOND CHALLENGE'
                        : 'IN ${recap.durationSeconds} SECONDS',
                    style: GoogleFonts.outfit(
                      color: _partyCardOrange,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    recap.challengeText,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: AppColors.ivory.withValues(alpha: 0.76),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _RecapStat(
                          label: isChoice
                              ? 'ROOM GOT IT'
                              : isBinary
                              ? 'ROOM SAID YES'
                              : 'ROOM LINE',
                          value: recap.crowdGuess == null
                              ? '—'
                              : isChoice || isBinary
                              ? '${recap.crowdGuess}%'
                              : '${recap.crowdGuess}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _RecapStat(
                          label: 'RESULT',
                          value: isChoice
                              ? (recap.result == 0 ? 'A' : 'B')
                              : isBinary
                              ? (recap.result == 1 ? 'SUCCESS' : 'FAILED')
                              : '${recap.result}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _RecapStat(
                          label: 'EARNED',
                          value: '+${recap.performerBonus}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecapStat extends StatelessWidget {
  final String label;
  final String value;

  const _RecapStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _partyCardOrange.withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: AppColors.ivory.withValues(alpha: 0.52),
              fontSize: 7,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: GoogleFonts.outfit(
                color: _partyCardOrangeSoft,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
