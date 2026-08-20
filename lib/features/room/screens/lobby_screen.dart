import 'dart:async';

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
import '../../../core/widgets/web_promo_banner.dart';
import '../../../features/game/models/question_model.dart';
import '../../../features/game/providers/game_providers.dart';
import '../../../features/party/providers/party_poll_session_provider.dart';
import '../../../features/player/models/player_model.dart';
import '../../../features/room/models/room_model.dart';
import '../../../features/room/providers/room_providers.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  final String roomCode;

  const LobbyScreen({super.key, required this.roomCode});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  List<Player> _players = [];
  int _playerStreamRevision = 0;
  int _latestPlayerLoadId = 0;
  Timer? _playerRefreshDebounce;
  bool _isStarting = false;
  bool _isReadyLoading = false;
  bool _isNavigatingToGame = false;

  List<Player> get _activePlayers =>
      _players.where((player) => player.isConnected).toList(growable: false);

  bool _samePlayerList(List<Player> a, List<Player> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.id != right.id ||
          left.deviceId != right.deviceId ||
          left.name != right.name ||
          left.avatarColor != right.avatarColor ||
          left.score != right.score ||
          left.bankScore != right.bankScore ||
          left.isHost != right.isHost ||
          left.isReady != right.isReady ||
          left.isConnected != right.isConnected) {
        return false;
      }
    }
    return true;
  }

  void _setPlayersIfChanged(List<Player> players) {
    if (_samePlayerList(_players, players)) return;
    setState(() => _players = players);
  }

  @override
  void initState() {
    super.initState();
    _loadPlayers();
    _setupRealtimeListener();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final audio = ref.read(audioServiceProvider);
      audio.startLobbyMusic();
      unawaited(audio.prepareGameAudio());
      ref.read(gameServiceProvider).prefetchQuestions();
    });
  }

  @override
  void dispose() {
    _playerRefreshDebounce?.cancel();
    super.dispose();
  }

  void _schedulePlayerRefresh() {
    _playerRefreshDebounce?.cancel();
    _playerRefreshDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      unawaited(_loadPlayers());
    });
  }

  void _setupRealtimeListener() {
    final room = ref.read(currentRoomProvider);
    final currentPlayer = ref.read(currentPlayerProvider);
    if (room == null) return;

    final realtimeService = ref.read(realtimeServiceProvider);
    unawaited(
      realtimeService
          .joinRoom(
            widget.roomCode,
            onPhaseChange: (_) {},
            onGuessSubmitted: (_) {},
            onGuessesRevealed: (_) {},
            onBetPlaced: (_) {},
            onBetRemoved: (_) {},
            onScoreUpdate: (_) {},
            onAnswerRevealed: (_) {},
            onGameStarted: (payload) {
              _enterStartedGamePayload(payload);
            },
            onGameEnded: (_) {},
            onPlayerJoined: (_) {
              _schedulePlayerRefresh();
            },
            onPlayerLeft: (payload) {
              final kickedPlayerId = payload['player_id'] as String?;
              final currentPlayer = ref.read(currentPlayerProvider);
              // Only react if WE were the one kicked
              if (kickedPlayerId != null &&
                  currentPlayer != null &&
                  kickedPlayerId == currentPlayer.id) {
                ref.read(skipAutoJoinProvider.notifier).set(true);
                ref.read(realtimeServiceProvider).leaveRoom(widget.roomCode);
                ref.read(currentRoomProvider.notifier).set(null);
                ref.read(currentPlayerProvider.notifier).set(null);
                if (mounted) {
                  context.goNamed('home');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('You have been removed from the lobby.'),
                    ),
                  );
                }
              }
              // The database stream is authoritative; this refresh also
              // covers a delayed or temporarily disconnected stream.
              _schedulePlayerRefresh();
            },
            presencePayload: currentPlayer == null
                ? null
                : {
                    'device_id': currentPlayer.deviceId,
                    'player_id': currentPlayer.id,
                    'name': currentPlayer.name,
                  },
            onPresenceChanged: (_) {
              // Presence may briefly be partial while clients subscribe or
              // reconnect. It is only a refresh hint; database player rows are
              // the stable source for what the lobby renders.
              _schedulePlayerRefresh();
            },
          )
          .then((_) async {
            final player = ref.read(currentPlayerProvider);
            if (player == null) return;
            return realtimeService.broadcast(widget.roomCode, 'player_joined', {
              'player_id': player.id,
              'device_id': player.deviceId,
            });
          })
          .catchError((Object error, StackTrace stackTrace) {
            debugPrint(
              'Lobby realtime subscription failed: $error\n$stackTrace',
            );
          }),
    );
  }

  Future<void> _loadPlayers() async {
    if (!mounted) return;
    final room = ref.read(currentRoomProvider);
    if (room == null) return;

    final loadId = ++_latestPlayerLoadId;
    final streamRevisionAtStart = _playerStreamRevision;
    final playerService = ref.read(playerServiceProvider);
    try {
      final players = await playerService.getPlayers(room.id);
      if (!mounted ||
          loadId != _latestPlayerLoadId ||
          streamRevisionAtStart != _playerStreamRevision) {
        return;
      }
      _setPlayersIfChanged(
        _anchorCurrentPlayer(
          playerService.collapseDuplicateConnectedPlayers(players),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Lobby player refresh failed: $error\n$stackTrace');
    }
  }

  List<Player> _anchorCurrentPlayer(List<Player> players) {
    final current = ref.read(currentPlayerProvider);
    if (current == null || !current.isConnected) return players;
    if (players.any(
      (player) =>
          player.id == current.id || player.deviceId == current.deviceId,
    )) {
      return players;
    }
    return [...players, current]
      ..sort((left, right) => left.joinedAt.compareTo(right.joinedAt));
  }

  void _applyPlayerStreamSnapshot(List<Map<String, dynamic>> data) {
    if (!mounted) return;
    _playerStreamRevision++;
    final playerService = ref.read(playerServiceProvider);
    final players = _anchorCurrentPlayer(
      playerService.collapseDuplicateConnectedPlayers(
        data.map(Player.fromJson).toList(growable: false),
      ),
    );
    _syncCurrentPlayer(players);
    _setPlayersIfChanged(players);
  }

  void _syncCurrentPlayer(List<Player> players) {
    final current = ref.read(currentPlayerProvider);
    if (current == null) return;
    final index = players.indexWhere(
      (player) =>
          player.id == current.id || player.deviceId == current.deviceId,
    );
    if (index == -1) return;
    final authoritative = players[index];
    if (_samePlayerList([current], [authoritative])) return;
    ref.read(currentPlayerProvider.notifier).set(authoritative);
  }

  void _enterStartedRoom(Room startedRoom) {
    if (_isNavigatingToGame || !mounted) return;
    if (startedRoom.status != RoomStatus.playing) {
      ref.read(currentRoomProvider.notifier).set(startedRoom);
      return;
    }

    ref.read(currentRoomProvider.notifier).set(startedRoom);
    _isNavigatingToGame = true;
    context.goNamed('game', pathParameters: {'roomCode': widget.roomCode});
  }

  void _enterStartedGamePayload(Map<String, dynamic> payload) {
    if (_isNavigatingToGame || !mounted) return;
    _isNavigatingToGame = true;
    _seedStartedGame(payload);
    context.goNamed('game', pathParameters: {'roomCode': widget.roomCode});
  }

  Future<void> _toggleReady() async {
    final player = ref.read(currentPlayerProvider);
    if (player == null || _isReadyLoading) return;

    setState(() => _isReadyLoading = true);
    try {
      final playerService = ref.read(playerServiceProvider);
      final updatedPlayer = await playerService.toggleReady(
        player.id,
        !player.isReady,
      );
      ref.read(currentPlayerProvider.notifier).set(updatedPlayer);
      await _loadPlayers();
    } finally {
      if (mounted) setState(() => _isReadyLoading = false);
    }
  }

  Future<void> _openPaywall() async {
    await context.pushNamed('premium');
    if (mounted) {
      ref.invalidate(premiumStatusProvider);
    }
  }

  Future<void> _startGame() async {
    if (_isStarting) return;

    final isPremium = ref.read(premiumStatusProvider).value ?? false;
    if (!isPremium && _activePlayers.length > GameConstants.freeMaxPlayers) {
      await _openPaywall();
      return;
    }

    setState(() => _isStarting = true);

    try {
      final room = ref.read(currentRoomProvider);
      if (room == null) return;

      if (room.gameMode == GameMode.party) {
        final snapshot = await ref
            .read(partyPollSessionProvider.notifier)
            .startGame(
              room.id,
              bettingDurationSeconds: GameConstants.partyBetTimerSeconds,
            );
        if (snapshot == null) {
          final message =
              ref.read(partyPollSessionProvider).errorMessage ??
              'Party game could not start.';
          throw StateError(message);
        }
        ref.read(currentRoomProvider.notifier).set(snapshot.room);

        final partyQuestion = Question(
          id: snapshot.round.question.id,
          textTr: snapshot.round.question.text,
          textEn: snapshot.round.question.text,
          answer: null,
          answerUnit: 'player',
          category: 'Party Poll',
          source: snapshot.round.question.rules,
        );
        final partyScores = Map<String, int>.from(snapshot.scores);
        _seedGameState(
          snapshot.room,
          partyQuestion,
          round: snapshot.round.number,
          phase: RoundPhase.betting,
          scores: partyScores,
        );

        unawaited(
          ref
              .read(realtimeServiceProvider)
              .broadcast(widget.roomCode, 'game_started', {
                'room_id': snapshot.room.id,
                'mode': GameMode.party.name,
                'round': snapshot.round.number,
                'phase': RoundPhase.betting.name,
                'state_version': snapshot.stateVersion,
                'question': partyQuestion.toJson(),
                'scores': partyScores,
                'bank_scores': partyScores,
                'phase_ends_at': snapshot.round.phaseEndsAt?.toIso8601String(),
              }),
        );
        if (mounted) {
          _isNavigatingToGame = true;
          context.goNamed(
            'game',
            pathParameters: {'roomCode': widget.roomCode},
          );
        }
        return;
      }

      final gameService = ref.read(gameServiceProvider);
      final secureStart = await gameService.startGameSecure(
        roomId: room.id,
        durationSeconds: GameConstants.guessTimerSeconds,
      );
      final question = secureStart.question;
      final legacyStartingScores = secureStart.scores;
      final startedRoom = secureStart.room;
      final deadline = startedRoom.phaseEndsAt;
      final playerService = ref.read(playerServiceProvider);
      final lobbyPlayers = playerService.collapseDuplicateConnectedPlayers(
        await playerService.getPlayers(room.id),
      );
      _players = lobbyPlayers
          .map(
            (player) => player.copyWith(
              score: legacyStartingScores[player.id] ?? player.score,
            ),
          )
          .toList();
      final startingScores = <String, int>{
        for (final player in _players) player.id: player.score,
      };
      _seedGameState(
        startedRoom,
        question,
        phase: startedRoom.roundPhase,
        scores: startingScores,
      );
      ref.read(currentRoomProvider.notifier).set(startedRoom);

      final realtimeService = ref.read(realtimeServiceProvider);
      unawaited(
        realtimeService
            .broadcast(widget.roomCode, 'game_started', {
              'room_id': room.id,
              'round': 1,
              'phase': startedRoom.roundPhase.name,
              'question': question.toJson(),
              'scores': legacyStartingScores,
              'bank_scores': startingScores,
              'phase_ends_at': deadline?.toIso8601String(),
            })
            .catchError((Object error, StackTrace stackTrace) {
              debugPrint('Game-start broadcast failed: $error\n$stackTrace');
            }),
      );

      if (mounted) {
        _isNavigatingToGame = true;
        context.goNamed('game', pathParameters: {'roomCode': widget.roomCode});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Game could not start: $e')));
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  void _seedStartedGame(Map<String, dynamic> payload) {
    final room = ref.read(currentRoomProvider);
    if (room == null) return;

    final questionData = payload['question'] as Map<String, dynamic>?;
    if (questionData == null) return;

    final question = Question.fromJson(questionData);
    final round = payload['round'] as int? ?? 1;
    final scores = _scoresFromPayload(
      payload['bank_scores'] ?? payload['scores'],
    );
    final phase = RoundPhase.fromString(
      payload['phase'] as String? ?? RoundPhase.guessing.name,
    );
    final deadlineValue = payload['phase_ends_at'];
    final deadline = deadlineValue is String
        ? DateTime.tryParse(deadlineValue)?.toUtc()
        : null;

    ref
        .read(currentRoomProvider.notifier)
        .set(
          room.copyWith(
            status: RoomStatus.playing,
            currentRound: round,
            roundPhase: phase,
            currentQuestionId: question.id,
            phaseEndsAt: deadline,
          ),
        );
    _seedGameState(room, question, round: round, phase: phase, scores: scores);
  }

  void _seedGameState(
    Room room,
    Question question, {
    int round = 1,
    RoundPhase phase = RoundPhase.guessing,
    Map<String, int>? scores,
  }) {
    ref
        .read(gameStateProvider.notifier)
        .initialize(
          room.id,
          room.code,
          room.maxRounds,
          currentRound: round,
          phase: phase,
          currentQuestion: question,
          scores:
              scores ??
              {for (final player in _players) player.id: player.score},
        );
  }

  Map<String, int>? _scoresFromPayload(Object? rawScores) {
    if (rawScores is! Map) return null;
    return rawScores.map((key, value) {
      final score = value is int ? value : int.tryParse('$value') ?? 0;
      return MapEntry('$key', score);
    });
  }

  bool get _canStart {
    final isHost = ref.read(isHostProvider);
    if (!isHost) return false;
    final players = _activePlayers;
    final room = ref.read(currentRoomProvider);
    final minimumPlayers = room?.gameMode == GameMode.party
        ? 3
        : GameConstants.minPlayers;
    if (players.length < minimumPlayers) return false;
    return players.where((p) => !p.isHost).every((p) => p.isReady);
  }

  String get _inviteLink {
    const defaultWebUrl = String.fromEnvironment(
      'WEB_APP_URL',
      defaultValue: 'https://bets-and-guesses.com',
    );

    if (kIsWeb) {
      final uri = Uri.base;
      final isLocalhost =
          uri.host == 'localhost' ||
          uri.host == '127.0.0.1' ||
          uri.host == '0.0.0.0' ||
          uri.host.isEmpty;
      if (!isLocalhost) {
        final origin =
            '${uri.scheme}://${uri.host}${uri.port != 80 && uri.port != 443 && uri.port != 0 ? ":${uri.port}" : ""}';
        return '$origin/#/?room=${widget.roomCode}';
      }
    }

    return '$defaultWebUrl/#/?room=${widget.roomCode}';
  }

  Future<void> _copyText(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _leaveLobby() async {
    final player = ref.read(currentPlayerProvider);
    ref.read(skipAutoJoinProvider.notifier).set(true);

    // 1. Broadcast FIRST (while record still exists and channel is active)
    if (player != null) {
      await ref.read(realtimeServiceProvider).broadcast(
        widget.roomCode,
        'player_left',
        {'player_id': player.id},
      );
    }

    // 2. Then delete from DB
    if (player != null) {
      await ref.read(playerServiceProvider).leaveRoom(player.id);
    }

    // 3. Then leave channel and clear state
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
    final activePlayers = _activePlayers;

    if (room != null) {
      ref.listen(playersStreamProvider(room.id), (prev, next) {
        next.whenData(_applyPlayerStreamSnapshot);
        if (next.hasError && prev?.hasError != true) {
          _schedulePlayerRefresh();
        }
      });
      ref.listen(roomStreamProvider(room.id), (prev, next) {
        next.whenData((data) {
          if (data.isEmpty) return;
          final updatedRoom = Room.fromJson(data.first);
          _enterStartedRoom(updatedRoom);
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
                  final contentWidth = constraints.maxWidth
                      .clamp(0.0, 560.0)
                      .toDouble();

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
                              _buildPlayersPanel(activePlayers),
                              const SizedBox(height: 10),
                              _buildActionsPanel(isHost, currentPlayer),
                              if (kIsWeb) ...[
                                const SizedBox(height: 16),
                                const WebPromoBanner(),
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
            Expanded(
              flex: 5,
              child: Text(
                ref.read(currentRoomProvider)?.gameMode == GameMode.party
                    ? 'PARTY LOBBY'
                    : 'CLASSIC LOBBY',
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
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
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
                  side: BorderSide(
                    color: AppColors.brassLight.withValues(alpha: 0.72),
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
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
                    border: Border.all(
                      color: AppColors.brassLight.withValues(alpha: 0.58),
                      width: 1.4,
                    ),
                  ),
                  child: const Icon(
                    Icons.copy_rounded,
                    color: AppColors.brassLight,
                    size: 20,
                  ),
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
        border: Border.all(
          color: AppColors.brassLight.withValues(alpha: 0.78),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.brass.withValues(alpha: 0.14),
            blurRadius: 18,
          ),
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
              border: Border.all(
                color: AppColors.brassLight.withValues(alpha: 0.88),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 132,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSpark(),
              const SizedBox(width: 10),
              Text(
                'SHARE TO INVITE',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.ivory,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  shadows: const [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 7,
                      offset: Offset(0, 2),
                    ),
                  ],
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
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                  side: BorderSide(
                    color: AppColors.ivory.withValues(alpha: 0.72),
                    width: 1.2,
                  ),
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

  Widget _buildPlayersPanel(List<Player> players) {
    return Container(
      height: 322,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: _darkGoldDecoration(radius: 16),
      child: Column(
        children: [
          Transform.translate(
            offset: const Offset(0, -1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.feltDark.withValues(alpha: 0.98),
                    AppColors.felt.withValues(alpha: 0.95),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
                border: Border.all(
                  color: AppColors.brassLight.withValues(alpha: 0.72),
                  width: 1.1,
                ),
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
          Expanded(
            child: players.isEmpty
                ? Center(
                    child: Text(
                      'Waiting for players...',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    key: const PageStorageKey('lobby-player-list'),
                    padding: EdgeInsets.zero,
                    itemCount: players.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.brassLight.withValues(alpha: 0.12),
                    ),
                    itemBuilder: (context, index) => KeyedSubtree(
                      key: ValueKey(players[index].id),
                      child: _buildPlayerRow(players[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerRow(Player player) {
    final isReady = player.isReady || player.isHost;
    final isHost = ref.read(isHostProvider);

    return SizedBox(
      height: 46,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  player.color.withValues(alpha: 0.86),
                  player.color.withValues(alpha: 0.5),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.brassLight, width: 1.7),
              boxShadow: [
                BoxShadow(
                  color: player.color.withValues(alpha: 0.44),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: Text(
                player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppColors.ivory,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
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
                      shadows: const [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
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
          if (isHost && !player.isHost) ...[
            IconButton(
              tooltip: 'Kick player',
              icon: const Icon(
                Icons.remove_circle_outline_rounded,
                color: AppColors.neonRed,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () async {
                await ref.read(playerServiceProvider).leaveRoom(player.id);
                await ref.read(realtimeServiceProvider).broadcast(
                  widget.roomCode,
                  'player_left',
                  {'player_id': player.id},
                );
              },
            ),
            const SizedBox(width: 8),
          ],
          _buildReadyBadge(isReady),
        ],
      ),
    );
  }

  Widget _buildActionsPanel(bool isHost, Player? currentPlayer) {
    final isPremium = ref.watch(premiumStatusProvider).value ?? false;
    final exceedsLimit =
        !isPremium && _activePlayers.length > GameConstants.freeMaxPlayers;

    final isPlayerReady =
        currentPlayer?.isReady == true || currentPlayer?.isHost == true;
    final primaryEnabled = isHost
        ? (exceedsLimit ? !_isStarting : (_canStart && !_isStarting))
        : currentPlayer != null;
    final primaryLabel = isHost
        ? (exceedsLimit ? 'UPGRADE TO PLAY' : 'START GAME')
        : (isPlayerReady ? 'READY' : 'MARK READY');
    final primaryIcon = isHost
        ? (exceedsLimit
              ? Icons.workspace_premium_rounded
              : Icons.play_arrow_rounded)
        : (isPlayerReady ? Icons.check_rounded : Icons.circle_outlined);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _darkGoldDecoration(radius: 16),
      child: Column(
        children: [
          if (isHost && exceedsLimit) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.brassLight.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.brassLight,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Free limit: ${GameConstants.freeMaxPlayers} players (${_activePlayers.length} in lobby)',
                      style: const TextStyle(
                        color: AppColors.brassLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: primaryEnabled
                  ? () {
                      if (isHost) {
                        if (exceedsLimit) {
                          _openPaywall();
                        } else {
                          _startGame();
                        }
                      } else {
                        _toggleReady();
                      }
                    }
                  : null,
              icon: (_isStarting || _isReadyLoading)
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.ink,
                      ),
                    )
                  : Icon(primaryIcon, size: 27),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(primaryLabel),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryEnabled
                    ? (exceedsLimit ? AppColors.brassLight : AppColors.brass)
                    : AppColors.surfaceLight,
                foregroundColor: primaryEnabled
                    ? AppColors.ink
                    : AppColors.textMuted,
                disabledBackgroundColor: AppColors.surfaceLight.withValues(
                  alpha: 0.68,
                ),
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
                  side: BorderSide(
                    color: AppColors.ivory.withValues(alpha: 0.76),
                    width: 1.4,
                  ),
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
        border: Border.all(
          color: Colors.white.withValues(alpha: isReady ? 0.2 : 0.28),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isReady
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: isReady
                ? const Color(0xFFD4F5BC)
                : AppColors.ivory.withValues(alpha: 0.84),
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
        border: Border.all(
          color: AppColors.brassLight.withValues(alpha: 0.72),
          width: 1,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'HOST',
            style: TextStyle(
              color: AppColors.brassLight,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              height: 1,
            ),
          ),
          SizedBox(width: 4),
          Icon(
            Icons.workspace_premium_rounded,
            color: AppColors.brassLight,
            size: 14,
          ),
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
    return const Icon(
      Icons.auto_awesome_rounded,
      color: AppColors.brassLight,
      size: 18,
    );
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
      border: Border.all(
        color: AppColors.brassLight.withValues(alpha: 0.74),
        width: 1.45,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.38),
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
