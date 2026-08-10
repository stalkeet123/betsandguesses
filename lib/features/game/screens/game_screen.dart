import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/constants/game_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/services/realtime_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_asset_image.dart';
import '../../../features/game/models/bet_model.dart';
import '../../../features/game/models/guess_model.dart';
import '../../../features/game/models/question_model.dart';
import '../../../features/game/providers/game_providers.dart';
import '../../../features/game/services/game_service.dart';
import '../../../features/game/services/game_sync_policy.dart';
import '../../../features/player/models/player_model.dart';
import '../../../features/party/models/party_snapshot.dart';
import '../../../features/party/providers/party_session_provider.dart';
import '../../../features/party/theme/party_palette.dart';
import '../../../features/party/widgets/party_single_scene_layer.dart';
import '../../../features/room/models/room_model.dart';
import '../../../features/room/providers/room_providers.dart';
import '../models/game_state.dart';
import '../widgets/poker_chip.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String roomCode;

  const GameScreen({super.key, required this.roomCode});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with WidgetsBindingObserver {
  List<Player> _players = [];
  Timer? _timer;
  Timer? _realtimeRetryTimer;
  Timer? _roomSyncDebounceTimer;
  int _timerSeconds = 0;
  final List<String> _usedQuestionIds = [];
  String _guessInput = '';
  int? _selectedChipValue;
  String? _selectedBetId;
  bool _isBetOperationInFlight = false;
  bool _isSubmittingGuess = false;
  bool _isRevealingGuesses = false;
  Set<String> _roundWinners = {};
  Map<String, int> _roundPayouts = {};
  Timer? _slotScanTimer;
  Timer? _roundAdvanceTimer;
  Timer? _questionStartTimer;
  final List<Timer> _revealEffectTimers = [];
  final ValueNotifier<int?> _scanSlotIndexNotifier = ValueNotifier(null);
  bool _showWinnerBadge = false;
  final Set<String> _incomingOtherBetIds = {};
  final Set<String> _playedOtherBetEntryIds = {};
  int _revealSequenceId = 0;
  int? _revealedResultRound;
  int? _revealedQuestionAudioRound;
  bool _isResyncing = false;
  bool _resyncRequested = false;
  DateTime? _phaseDeadline;
  final List<_PendingBetEvent> _pendingBetEvents = [];
  PartySnapshot? _partySnapshot;
  bool _isPartyCommandInFlight = false;
  Timer? _partySnapshotWatchdogTimer;
  Timer? _partyTransitionFallbackTimer;
  String? _partySnapshotWatchdogKey;
  int _partySnapshotWatchdogAttempt = 0;
  bool _isRefreshingPartyPlayers = false;
  bool _isAppInForeground = true;
  bool _isActive = true;
  bool _isDisposed = false;
  late final AudioService _audioService;
  late final RealtimeService _realtimeService;

  bool get _canUseRef =>
      mounted && _isActive && _isAppInForeground && !_isDisposed;

  @override
  void initState() {
    super.initState();
    _audioService = ref.read(audioServiceProvider);
    _realtimeService = ref.read(realtimeServiceProvider);
    WidgetsBinding.instance.addObserver(this);
    _bootstrapVisibleGameState();
    _initializeGame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppAssetPaths.warmUpBoardImages(context).catchError((_) {});
    });
  }

  void _bootstrapVisibleGameState() {
    final room = ref.read(currentRoomProvider);
    if (room == null || room.status != RoomStatus.playing) return;

    final phase = room.roundPhase;
    _syncAudioForPhase(phase);
    if (phase == RoundPhase.guessing) {
      _startTimer(GameConstants.guessTimerSeconds, deadline: room.phaseEndsAt);
    } else if (phase == RoundPhase.betting) {
      _startTimer(
        room.gameMode == GameMode.party
            ? GameConstants.partyBetTimerSeconds
            : GameConstants.betTimerSeconds,
        deadline: room.phaseEndsAt,
      );
    }
    if (phase == RoundPhase.question || phase == RoundPhase.guessing) {
      _playQuestionRevealForRoundOnce(max(1, room.currentRound));
    }
  }

  @override
  void activate() {
    super.activate();
    _isActive = true;
  }

  @override
  void deactivate() {
    _isActive = false;
    _timer?.cancel();
    _timer = null;
    _stopPartySnapshotWatchdog();
    _partyTransitionFallbackTimer?.cancel();
    _partyTransitionFallbackTimer = null;
    super.deactivate();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _isActive = false;
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
    _realtimeRetryTimer?.cancel();
    _roomSyncDebounceTimer?.cancel();
    _partySnapshotWatchdogTimer?.cancel();
    _partyTransitionFallbackTimer?.cancel();
    _roundAdvanceTimer?.cancel();
    _questionStartTimer?.cancel();
    _cancelRevealEffects();
    _scanSlotIndexNotifier.dispose();
    unawaited(_realtimeService.leaveRoom(widget.roomCode));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isAppInForeground = true;
      if (_canUseRef) {
        unawaited(_resyncFromServer(refreshRealtime: true));
      }
    } else {
      _isAppInForeground = false;
      _stopTimer(clearDeadline: false);
      _stopPartySnapshotWatchdog();
      _partyTransitionFallbackTimer?.cancel();
      _partyTransitionFallbackTimer = null;
    }
  }

  void _syncAudioForPhase(RoundPhase phase) {
    final audio = ref.read(audioServiceProvider);
    switch (phase) {
      case RoundPhase.idle:
      case RoundPhase.betting:
      case RoundPhase.partyReady:
        audio.startLobbyMusic();
        break;
      case RoundPhase.question:
        audio.stopBackgroundMusic(immediate: true);
        break;
      case RoundPhase.guessing:
      case RoundPhase.partyAction:
        audio.startQuestionMusic();
        break;
      case RoundPhase.revealGuesses:
      case RoundPhase.partyResultEntry:
      case RoundPhase.partyResultConfirm:
      case RoundPhase.revealAnswer:
      case RoundPhase.scoring:
        audio.startMainBgm();
        break;
    }
  }

  Future<void> _initializeGame() async {
    var room = ref.read(currentRoomProvider);
    if (room == null) return;

    final roomService = ref.read(roomServiceProvider);
    room = await roomService.getRoom(room.id);
    ref.read(currentRoomProvider.notifier).set(room);

    final playerService = ref.read(playerServiceProvider);
    _players = await playerService.getPlayers(room.id);
    _restoreCurrentPlayer(room.id);

    if (room.gameMode == GameMode.party) {
      unawaited(_setupRealtime());
      await _resyncPartySnapshot(roomOverride: room);
      return;
    }

    final gameNotifier = ref.read(gameStateProvider.notifier);
    final scores = <String, int>{};
    for (final player in _players) {
      scores[player.id] = player.score;
    }

    final seededState = ref.read(gameStateProvider);
    Question? currentQuestion = seededState.roomId == room.id
        ? seededState.currentQuestion
        : null;
    final currentQuestionId = room.currentQuestionId;
    if (currentQuestionId != null && currentQuestion?.id != currentQuestionId) {
      currentQuestion = await ref
          .read(gameServiceProvider)
          .getQuestionForRoom(room.id);
    }

    gameNotifier.initialize(
      room.id,
      room.code,
      room.maxRounds,
      currentRound: room.currentRound,
      phase: room.roundPhase,
      currentQuestion: currentQuestion,
      scores: scores,
    );

    // Realtime improves responsiveness, but it must never block the first
    // question, timer, audio, or navigation. Server snapshots remain the
    // authoritative startup path while the channel connects in parallel.
    unawaited(_setupRealtime());

    if (room.roundPhase == RoundPhase.question) {
      _playQuestionRevealForRoundOnce(max(1, room.currentRound));
      _scheduleQuestionStart(room, primary: ref.read(isHostProvider));
      return;
    }

    await _resyncFromServer(roomOverride: room);
    _playQuestionRevealOnce(ref.read(gameStateProvider).currentQuestion);
  }

  void _playQuestionRevealOnce(Question? question) {
    if (question == null) return;
    final stateRound = ref.read(gameStateProvider).currentRound;
    final roomRound = ref.read(currentRoomProvider)?.currentRound ?? 0;
    _playQuestionRevealForRoundOnce(max(1, max(stateRound, roomRound)));
  }

  void _playQuestionRevealForRoundOnce(int round) {
    if (_revealedQuestionAudioRound == round) return;
    _revealedQuestionAudioRound = round;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_canUseRef) return;
      final state = ref.read(gameStateProvider);
      if (state.currentRound != round || state.phase != RoundPhase.question) {
        return;
      }
      unawaited(ref.read(audioServiceProvider).playQuestionReveal());
    });
  }

  Player? _restoreCurrentPlayer(String roomId) {
    if (!_canUseRef) return null;
    final existing = ref.read(currentPlayerProvider);
    final deviceId = ref.read(deviceIdProvider);
    Player? resolved;
    for (final player in _players) {
      if (player.roomId == roomId && player.deviceId == deviceId) {
        resolved = player;
        break;
      }
    }
    resolved ??= existing?.roomId == roomId ? existing : null;
    if (resolved != null && resolved.id != existing?.id) {
      ref.read(currentPlayerProvider.notifier).set(resolved);
    }
    return resolved;
  }

  Future<void> _setupRealtime({bool resyncAfterConnect = false}) async {
    if (!_canUseRef) return;
    _realtimeRetryTimer?.cancel();
    _realtimeRetryTimer = null;
    final realtimeService = _realtimeService;
    final roomId = ref.read(currentRoomProvider)?.id;
    try {
      await realtimeService.joinRoom(
        widget.roomCode,
        roomId: roomId,
        onPhaseChange: (payload) {
          try {
            if (!_canUseRef) return;
            if (ref.read(currentRoomProvider)?.gameMode == GameMode.party) {
              _schedulePartyRealtimeResync();
              return;
            }
            final phase = RoundPhase.fromString(
              payload['phase'] as String? ?? 'idle',
            );
            final round = (payload['round'] as num?)?.toInt();
            if (round == null) return;
            final currentState = ref.read(gameStateProvider);
            if (!GameSyncPolicy.shouldApplyPhase(
              currentRound: currentState.currentRound,
              currentPhase: currentState.phase,
              eventRound: round,
              eventPhase: phase,
            )) {
              return;
            }
            if (_isResyncing) _resyncRequested = true;

            final isNewRound = round > currentState.currentRound;
            final deadline = _deadlineFromPayload(payload);
            final gameNotifier = ref.read(gameStateProvider.notifier);

            gameNotifier.setRound(round);
            gameNotifier.updatePhase(phase);
            _syncAudioForPhase(phase);

            if (phase == RoundPhase.question || phase == RoundPhase.guessing) {
              final questionData = payload['question'] as Map<String, dynamic>?;
              if (questionData != null) {
                final question = Question.fromJson(questionData);
                gameNotifier.setQuestion(question);
                if (!_usedQuestionIds.contains(question.id)) {
                  _usedQuestionIds.add(question.id);
                }
                _playQuestionRevealOnce(question);
              }
              if (isNewRound) {
                _roundWinners.clear();
                _incomingOtherBetIds.clear();
                _playedOtherBetEntryIds.clear();
                _selectedBetId = null;
                gameNotifier.resetForNewRound();
              }

              if (phase == RoundPhase.guessing) {
                _guessInput = '';
                _isSubmittingGuess = false;
                _startTimer(
                  GameConstants.guessTimerSeconds,
                  deadline: deadline,
                );
              }
            }

            if (phase == RoundPhase.betting) {
              _startTimer(GameConstants.betTimerSeconds, deadline: deadline);
            }

            if (phase == RoundPhase.revealAnswer ||
                phase == RoundPhase.scoring) {
              _stopTimer();
            }
          } catch (e, st) {
            debugPrint('Error in onPhaseChange: $e\n$st');
          }
        },
        onGuessSubmitted: (_) {
          if (_canUseRef) unawaited(_maybeAutoRevealGuesses());
        },
        onGuessesRevealed: (payload) {
          if (!_canUseRef) return;
          if (!_payloadMatchesCurrentRound(payload)) return;
          final guessesData = payload['guesses'] as List<dynamic>?;
          if (guessesData != null) {
            final guesses = guessesData
                .map((g) => Guess.fromJson(g as Map<String, dynamic>))
                .toList();
            ref.read(gameStateProvider.notifier).setGuesses(guesses);
          }
        },
        onBetPlaced: (payload) {
          if (_canUseRef) _applyBetPlacedPayload(payload);
        },
        onBetRemoved: (payload) {
          if (_canUseRef) _applyBetRemovedPayload(payload);
        },
        onBetRowChanged: (record, isDelete) {
          if (_canUseRef) {
            _applyBetDatabaseChange(record, isDelete: isDelete);
          }
        },
        onRoomRowChanged: _applyRoomDatabaseChange,
        onPlayerJoined: (_) => unawaited(_refreshPartyPlayers()),
        onPlayerLeft: (_) => unawaited(_refreshPartyPlayers()),
        onScoreUpdate: (payload) {
          if (!_canUseRef) return;
          if (!_payloadMatchesCurrentRound(payload)) return;
          final scoresData = payload['scores'] as Map<String, dynamic>?;
          if (scoresData != null) {
            final scores = scoresData.map((k, v) => MapEntry(k, v as int));
            ref.read(gameStateProvider.notifier).setScores(scores);
          }
        },
        onAnswerRevealed: (payload) {
          try {
            if (!_canUseRef) return;
            if (!_payloadMatchesCurrentRound(payload)) return;
            final answer = (payload['answer'] as num?)?.toInt();
            final winningGuessId = payload['winning_guess_id'] as String?;
            if (answer != null) {
              ref
                  .read(gameStateProvider.notifier)
                  .revealAnswer(answer: answer, winningGuessId: winningGuessId);
              _syncAudioForPhase(RoundPhase.revealAnswer);
              unawaited(_startRevealSequence(ref.read(gameStateProvider)));
              _scheduleRoundAdvance();
            }
          } catch (e, st) {
            debugPrint('Error in onAnswerRevealed: $e\n$st');
          }
        },
        onGameStarted: (payload) {
          if (!_canUseRef) return;
          final questionData = payload['question'] as Map<String, dynamic>?;
          if (questionData == null) return;

          final round = payload['round'] as int? ?? 1;
          final phase = RoundPhase.fromString(
            payload['phase'] as String? ?? RoundPhase.guessing.name,
          );
          final question = Question.fromJson(questionData);
          final scores = _scoresFromPayload(payload['scores']);
          final deadline = _deadlineFromPayload(payload);
          final gameNotifier = ref.read(gameStateProvider.notifier);
          gameNotifier.startGame(
            round: round,
            phase: phase,
            question: question,
            scores: scores,
          );
          if (!_usedQuestionIds.contains(question.id)) {
            _usedQuestionIds.add(question.id);
          }
          _playQuestionRevealOnce(question);
          if (phase == RoundPhase.guessing) {
            _guessInput = '';
            _isSubmittingGuess = false;
            _startTimer(GameConstants.guessTimerSeconds, deadline: deadline);
          }
          _syncAudioForPhase(phase);
        },
        onGameEnded: (_) {
          if (_canUseRef) {
            context.goNamed(
              'results',
              pathParameters: {'roomCode': widget.roomCode},
            );
          }
        },
      );
      if (resyncAfterConnect && _canUseRef) {
        unawaited(_resyncFromServer());
      }
    } catch (error, stackTrace) {
      debugPrint('Realtime subscription failed: $error\n$stackTrace');
      if (!_canUseRef) return;
      _realtimeRetryTimer = Timer(const Duration(seconds: 2), () {
        if (_canUseRef) {
          unawaited(_setupRealtime(resyncAfterConnect: true));
        }
      });
    }
  }

  Map<String, int>? _scoresFromPayload(Object? rawScores) {
    if (rawScores is! Map) return null;
    return rawScores.map((key, value) {
      final score = value is int ? value : int.tryParse('$value') ?? 0;
      return MapEntry('$key', score);
    });
  }

  DateTime? _deadlineFromPayload(Map<String, dynamic> payload) {
    final raw = payload['phase_ends_at'];
    if (raw is DateTime) return raw.toUtc();
    if (raw is String) return DateTime.tryParse(raw)?.toUtc();
    return null;
  }

  int? _eventRound(Map<String, dynamic> payload) {
    final direct = (payload['round'] as num?)?.toInt();
    if (direct != null) return direct;
    final bet = payload['bet'];
    if (bet is Map) return (bet['round_number'] as num?)?.toInt();
    return null;
  }

  bool _payloadMatchesCurrentRound(Map<String, dynamic> payload) {
    final eventRound = _eventRound(payload);
    if (eventRound == null) return true;
    return GameSyncPolicy.isCurrentRound(
      currentRound: ref.read(gameStateProvider).currentRound,
      eventRound: eventRound,
    );
  }

  void _applyBetPlacedPayload(
    Map<String, dynamic> payload, {
    bool recordDuringResync = true,
    bool ignoreCurrentPlayer = true,
  }) {
    try {
      if (!_payloadMatchesCurrentRound(payload)) return;
      final betData = payload['bet'] as Map<String, dynamic>?;
      if (betData == null) return;
      final currentPlayer = ref.read(currentPlayerProvider);
      final bet = Bet.fromJson(betData);
      if (ignoreCurrentPlayer && bet.playerId == currentPlayer?.id) return;

      if (_isResyncing && recordDuringResync) {
        _pendingBetEvents.add(
          _PendingBetEvent(
            isRemoval: false,
            payload: Map.of(payload),
            ignoreCurrentPlayer: ignoreCurrentPlayer,
          ),
        );
      }
      if (bet.playerId != currentPlayer?.id) {
        _incomingOtherBetIds.add(bet.id);
        _playedOtherBetEntryIds.remove(bet.id);
      }
      ref.read(gameStateProvider.notifier).addBet(bet);
    } catch (e, st) {
      debugPrint('Error in onBetPlaced: $e\n$st');
    }
  }

  void _applyBetDatabaseChange(
    Map<String, dynamic> record, {
    required bool isDelete,
  }) {
    final round = (record['round_number'] as num?)?.toInt();
    if (isDelete) {
      final betId = record['id'] as String?;
      if (betId == null) return;
      _applyBetRemovedPayload({
        if (round != null) 'round': round,
        'bet_id': betId,
        'player_id': record['player_id'],
        'slot_index': record['slot_index'],
      });
      return;
    }

    final data = Map<String, dynamic>.from(record);
    final playerId = data['player_id'] as String?;
    final player = playerId == null ? null : _playerById(playerId);
    data['player_name'] = player?.name;
    data['player_color'] = player?.avatarColor;

    // The database row can beat the RPC response on a slow connection.
    // Reconcile it against the local chip immediately so the bank never counts
    // the same bet twice while waiting for that response.
    final currentPlayer = ref.read(currentPlayerProvider);
    final clientActionId = data['client_action_id'] as String?;
    if (playerId == currentPlayer?.id &&
        clientActionId != null &&
        clientActionId.isNotEmpty) {
      ref
          .read(gameStateProvider.notifier)
          .replaceBet('local-$clientActionId', Bet.fromJson(data));
      return;
    }
    _applyBetPlacedPayload({'bet': data}, ignoreCurrentPlayer: false);
  }

  void _applyRoomDatabaseChange(Map<String, dynamic> record) {
    if (!_canUseRef) return;
    try {
      final room = Room.fromJson(record);
      final currentRoom = ref.read(currentRoomProvider);
      if (currentRoom != null) {
        if (room.stateVersion < currentRoom.stateVersion) return;
        final sameAuthority =
            room.stateVersion == currentRoom.stateVersion &&
            room.status == currentRoom.status &&
            room.currentRound == currentRoom.currentRound &&
            room.roundPhase == currentRoom.roundPhase &&
            room.currentQuestionId == currentRoom.currentQuestionId &&
            room.phaseEndsAt == currentRoom.phaseEndsAt;
        if (sameAuthority) return;
      }

      ref.read(currentRoomProvider.notifier).set(room);
      if (room.status == RoomStatus.finished) {
        _roomSyncDebounceTimer?.cancel();
        if (_canUseRef) {
          context.goNamed(
            'results',
            pathParameters: {'roomCode': widget.roomCode},
          );
        }
        return;
      }

      if (room.gameMode == GameMode.party) {
        _schedulePartyRealtimeResync(roomOverride: room);
        return;
      }

      final gameState = ref.read(gameStateProvider);
      final newRound = room.currentRound > gameState.currentRound;
      final questionChanged =
          room.currentQuestionId != null &&
          room.currentQuestionId != gameState.currentQuestion?.id;
      if (newRound || questionChanged) {
        ref
            .read(gameStateProvider.notifier)
            .beginAuthoritativeRound(room.currentRound, room.roundPhase);
        _guessInput = '';
        _selectedChipValue = null;
        _selectedBetId = null;
        _isSubmittingGuess = false;
        _roundWinners.clear();
        _roundPayouts.clear();
        _revealedResultRound = null;
      } else {
        final notifier = ref.read(gameStateProvider.notifier);
        notifier.setRound(room.currentRound);
        notifier.updatePhase(room.roundPhase);
      }

      _syncAudioForPhase(room.roundPhase);
      if (room.roundPhase == RoundPhase.question) {
        _playQuestionRevealForRoundOnce(max(1, room.currentRound));
      }
      if (room.roundPhase == RoundPhase.guessing) {
        _questionStartTimer?.cancel();
        _startTimer(
          GameConstants.guessTimerSeconds,
          deadline: room.phaseEndsAt,
        );
      } else if (room.roundPhase == RoundPhase.betting) {
        _questionStartTimer?.cancel();
        _startTimer(GameConstants.betTimerSeconds, deadline: room.phaseEndsAt);
      } else {
        _stopTimer();
      }
      if (room.roundPhase == RoundPhase.question) {
        _scheduleQuestionStart(room);
      } else if (room.roundPhase == RoundPhase.revealAnswer ||
          room.roundPhase == RoundPhase.scoring) {
        _scheduleRoundAdvance(deadline: room.phaseEndsAt);
      }
      if (_canUseRef) setState(() {});

      _roomSyncDebounceTimer?.cancel();
      _roomSyncDebounceTimer = Timer(const Duration(milliseconds: 80), () {
        if (_canUseRef) {
          unawaited(
            _resyncFromServer(roomOverride: room, synchronizeClock: false),
          );
        }
      });
    } catch (error, stackTrace) {
      debugPrint('Room realtime sync failed: $error\n$stackTrace');
    }
  }

  void _applyBetRemovedPayload(
    Map<String, dynamic> payload, {
    bool recordDuringResync = true,
  }) {
    try {
      if (!_payloadMatchesCurrentRound(payload)) return;
      if (_isResyncing && recordDuringResync) {
        _pendingBetEvents.add(
          _PendingBetEvent(isRemoval: true, payload: Map.of(payload)),
        );
      }

      final betId = payload['bet_id'] as String?;
      final playerId = payload['player_id'] as String?;
      final slotIndex = (payload['slot_index'] as num?)?.toInt();
      if (betId != null) {
        _incomingOtherBetIds.remove(betId);
        _playedOtherBetEntryIds.remove(betId);
        ref.read(gameStateProvider.notifier).removeBetById(betId);
        return;
      }
      if (playerId != null && slotIndex != null) {
        ref
            .read(gameStateProvider.notifier)
            .removeBetForSlot(playerId, slotIndex);
      }
    } catch (e, st) {
      debugPrint('Error in onBetRemoved: $e\n$st');
    }
  }

  Future<void> _resyncFromServer({
    bool refreshRealtime = false,
    Room? roomOverride,
    bool synchronizeClock = true,
  }) async {
    if (!_canUseRef) return;
    if (_isResyncing) {
      _resyncRequested = true;
      return;
    }
    final currentRoom = roomOverride ?? ref.read(currentRoomProvider);
    if (currentRoom == null) return;
    if (currentRoom.gameMode == GameMode.party) {
      await _resyncPartySnapshot(
        refreshRealtime: refreshRealtime,
        roomOverride: roomOverride,
        synchronizeClock: synchronizeClock,
      );
      return;
    }

    _isResyncing = true;
    _resyncRequested = false;
    _pendingBetEvents.clear();
    try {
      if (refreshRealtime) await _setupRealtime();

      final roomService = ref.read(roomServiceProvider);
      final playerService = ref.read(playerServiceProvider);
      final gameService = ref.read(gameServiceProvider);
      final gameNotifier = ref.read(gameStateProvider.notifier);

      if (synchronizeClock) {
        try {
          await roomService.synchronizeServerClock(force: refreshRealtime);
        } catch (_) {
          // The local fallback remains available for older schemas or outages.
        }
      }

      final room = roomOverride ?? await roomService.getRoom(currentRoom.id);
      ref.read(currentRoomProvider.notifier).set(room);

      if (room.status == RoomStatus.finished) {
        if (mounted) {
          context.goNamed(
            'results',
            pathParameters: {'roomCode': widget.roomCode},
          );
        }
        return;
      }

      _players = await playerService.getPlayers(room.id);
      final currentPlayer = _restoreCurrentPlayer(room.id);
      final scores = <String, int>{
        for (final player in _players) player.id: player.score,
      };
      final phase = room.roundPhase;
      final round = room.currentRound;
      final oldState = ref.read(gameStateProvider);
      var enrichedGuesses = <Guess>[];
      var bets = <Bet>[];
      Question? question;
      String? winningGuessId;

      if (round > 0) {
        final guesses = await gameService.getGuesses(room.id, round);
        enrichedGuesses = guesses.map((guess) {
          final player = _playerById(guess.playerId);
          return guess.copyWith(
            playerName: player?.name,
            playerColor: player?.avatarColor,
          );
        }).toList();
        bets = await gameService.getBets(room.id, round);
        final hasQuestion =
            room.currentQuestionId != null ||
            enrichedGuesses.any((guess) => guess.questionId != null);
        question = !hasQuestion
            ? (oldState.currentRound == round ? oldState.currentQuestion : null)
            : await gameService.getQuestionForRoom(room.id);

        if (question != null) {
          if (!_usedQuestionIds.contains(question.id)) {
            _usedQuestionIds.add(question.id);
          }
        }

        if ((phase == RoundPhase.revealAnswer || phase == RoundPhase.scoring) &&
            question != null) {
          winningGuessId = enrichedGuesses
              .where((guess) => guess.isWinner)
              .map((guess) => guess.id)
              .firstOrNull;
        }
      }

      gameNotifier.applySnapshot(
        roomId: room.id,
        roomCode: room.code,
        currentRound: round,
        maxRounds: room.maxRounds,
        phase: phase,
        currentQuestion: question,
        guesses: enrichedGuesses,
        bets: bets,
        scores: scores,
        correctAnswer:
            phase == RoundPhase.revealAnswer || phase == RoundPhase.scoring
            ? question?.answer
            : null,
        winningGuessId: winningGuessId,
        hasSubmittedGuess:
            currentPlayer != null &&
            enrichedGuesses.any((guess) => guess.playerId == currentPlayer.id),
      );
      if (phase == RoundPhase.question || phase == RoundPhase.guessing) {
        _playQuestionRevealOnce(question);
      }

      _incomingOtherBetIds.clear();
      _playedOtherBetEntryIds.clear();
      final pendingBetEvents = List<_PendingBetEvent>.of(_pendingBetEvents);
      _pendingBetEvents.clear();
      for (final event in pendingBetEvents) {
        if (event.isRemoval) {
          _applyBetRemovedPayload(event.payload, recordDuringResync: false);
        } else {
          _applyBetPlacedPayload(
            event.payload,
            recordDuringResync: false,
            ignoreCurrentPlayer: event.ignoreCurrentPlayer,
          );
        }
      }

      if (round != oldState.currentRound) {
        _guessInput = '';
        _selectedChipValue = null;
        _selectedBetId = null;
        _isSubmittingGuess = false;
        _roundWinners.clear();
        _roundPayouts.clear();
        _revealedResultRound = null;
      }

      _syncAudioForPhase(phase);
      if (phase == RoundPhase.revealAnswer || phase == RoundPhase.scoring) {
        unawaited(_startRevealSequence(ref.read(gameStateProvider)));
        _scheduleRoundAdvance(deadline: room.phaseEndsAt);
      } else {
        _cancelRevealEffects();
      }

      if (phase == RoundPhase.question) {
        _scheduleQuestionStart(room);
      } else {
        _questionStartTimer?.cancel();
      }

      if (phase == RoundPhase.revealAnswer || phase == RoundPhase.scoring) {
        _stopTimer();
      } else if (phase == RoundPhase.guessing) {
        _startTimer(
          GameConstants.guessTimerSeconds,
          deadline: room.phaseEndsAt,
        );
      } else if (phase == RoundPhase.betting) {
        _startTimer(GameConstants.betTimerSeconds, deadline: room.phaseEndsAt);
      } else if (phase == RoundPhase.question && round > 0) {
        _stopTimer();
      }
      if (mounted) setState(() {});
    } finally {
      _isResyncing = false;
      final shouldResyncAgain = _resyncRequested;
      _resyncRequested = false;
      if (shouldResyncAgain && mounted) {
        unawaited(_resyncFromServer());
      }
    }
  }

  Future<void> _resyncPartySnapshot({
    bool refreshRealtime = false,
    Room? roomOverride,
    bool synchronizeClock = true,
  }) async {
    if (!_canUseRef) return;
    if (_isResyncing) {
      _resyncRequested = true;
      return;
    }
    final currentRoom = roomOverride ?? ref.read(currentRoomProvider);
    if (currentRoom == null || currentRoom.gameMode != GameMode.party) return;

    _isResyncing = true;
    _resyncRequested = false;
    try {
      if (refreshRealtime) await _setupRealtime();
      if (!_canUseRef) return;
      final roomService = ref.read(roomServiceProvider);
      final partyService = ref.read(partyGameServiceProvider);
      if (synchronizeClock) {
        try {
          await roomService.synchronizeServerClock(force: refreshRealtime);
        } catch (_) {}
      }

      final snapshot = await partyService.getSnapshot(currentRoom.id);
      if (!_canUseRef) return;
      _applyPartySnapshot(snapshot);
    } catch (error, stackTrace) {
      debugPrint('Party snapshot sync failed: $error\n$stackTrace');
    } finally {
      _isResyncing = false;
      final shouldRepeat = _resyncRequested;
      _resyncRequested = false;
      if (shouldRepeat && _canUseRef) {
        unawaited(_resyncPartySnapshot());
      }
    }
  }

  void _schedulePartyRealtimeResync({Room? roomOverride}) {
    _roomSyncDebounceTimer?.cancel();
    _roomSyncDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (!_canUseRef) return;
      unawaited(
        _resyncPartySnapshot(
          roomOverride: roomOverride,
          synchronizeClock: false,
        ),
      );
    });
  }

  Future<void> _refreshPartyPlayers() async {
    if (!_canUseRef || _isRefreshingPartyPlayers) return;
    final room = ref.read(currentRoomProvider);
    if (room == null || room.gameMode != GameMode.party) return;
    _isRefreshingPartyPlayers = true;
    try {
      final players = await ref.read(playerServiceProvider).getPlayers(room.id);
      if (!_canUseRef) return;
      _players = players;
      _restoreCurrentPlayer(room.id);
      setState(() {});
    } catch (error, stackTrace) {
      debugPrint('Party player refresh failed: $error\n$stackTrace');
    } finally {
      _isRefreshingPartyPlayers = false;
    }
  }

  void _schedulePartySnapshotWatchdog(PartySnapshot snapshot) {
    final phase = snapshot.round.phase;
    final needsWatchdog =
        phase == PartyRoundPhase.ready ||
        phase == PartyRoundPhase.action ||
        phase == PartyRoundPhase.resultEntry ||
        phase == PartyRoundPhase.resultConfirm;
    if (!needsWatchdog) {
      _stopPartySnapshotWatchdog();
      return;
    }

    final key =
        '${snapshot.round.number}:${phase.name}:${snapshot.stateVersion}';
    if (_partySnapshotWatchdogKey != key) {
      _partySnapshotWatchdogTimer?.cancel();
      _partySnapshotWatchdogTimer = null;
      _partySnapshotWatchdogKey = key;
      _partySnapshotWatchdogAttempt = 0;
    }
    if (_partySnapshotWatchdogTimer != null) return;

    final delay = GameSyncPolicy.partyWatchdogDelay(
      _partySnapshotWatchdogAttempt,
    );
    _partySnapshotWatchdogTimer = Timer(delay, () {
      _partySnapshotWatchdogTimer = null;
      if (!_canUseRef || _partySnapshotWatchdogKey != key) return;
      _partySnapshotWatchdogAttempt++;
      unawaited(_resyncPartySnapshot(synchronizeClock: false));
    });
  }

  void _stopPartySnapshotWatchdog() {
    _partySnapshotWatchdogTimer?.cancel();
    _partySnapshotWatchdogTimer = null;
    _partySnapshotWatchdogKey = null;
    _partySnapshotWatchdogAttempt = 0;
  }

  void _applyPartySnapshot(PartySnapshot snapshot) {
    if (!_canUseRef) return;
    final previous = _partySnapshot;
    if (previous != null &&
        snapshot.round.number == previous.round.number &&
        snapshot.stateVersion < previous.stateVersion) {
      return;
    }

    final round = snapshot.round;
    if (previous == null ||
        previous.round.number != round.number ||
        previous.round.phase != round.phase) {
      _partyTransitionFallbackTimer?.cancel();
      _partyTransitionFallbackTimer = null;
    }
    final question = Question(
      id: round.challenge.id,
      textTr: round.challenge.text,
      textEn: round.challenge.text,
      answer: round.phase == PartyRoundPhase.reveal
          ? round.proposedResult
          : null,
      answerUnit: round.challenge.answerUnit,
      category: 'Party Challenge',
      source: round.challenge.rules,
    );
    // Count challenges own four authored board boundaries. They are represented
    // as anonymous guesses so the established five-slot Classic board remains
    // reusable. Binary challenges render their own YES/NO board.
    final guesses = round.challenge.betBoundaries
        .asMap()
        .entries
        .map(
          (entry) => Guess(
            id: 'party-boundary-${round.challenge.id}-${entry.key}',
            roomId: snapshot.room.id,
            roundNumber: round.number,
            playerId: 'party-boundary-${entry.key}',
            questionId: round.challenge.id,
            value: entry.value,
          ),
        )
        .toList(growable: false);
    final sortedPartyGuesses = List<Guess>.of(guesses)
      ..sort((a, b) => a.value.compareTo(b.value));
    final winningPartySlot =
        round.phase == PartyRoundPhase.reveal && round.proposedResult != null
        ? round.challenge.betSlotForResult(round.proposedResult!) ??
              ref
                  .read(gameServiceProvider)
                  .determineWinningBetSlotIndex(
                    sortedPartyGuesses,
                    round.proposedResult!,
                  )
        : null;
    final bets = round.bets
        .map((bet) {
          final player = bet.playerId == null
              ? null
              : _playerById(bet.playerId!);
          return Bet(
            id: bet.id,
            roomId: snapshot.room.id,
            roundNumber: round.number,
            playerId: bet.playerId ?? 'hidden-${bet.id}',
            slotIndex: bet.slotIndex,
            chips: bet.chips,
            payoutMultiplier: round.challenge.isBinary
                ? 2
                : GameConstants.boardOdds[bet.slotIndex],
            won: winningPartySlot == bet.slotIndex,
            playerName: player?.name,
            playerColor: player?.avatarColor,
            positionX: bet.positionX,
            positionY: bet.positionY,
          );
        })
        .toList(growable: false);

    final currentPlayer = ref.read(currentPlayerProvider);
    ref.read(currentRoomProvider.notifier).set(snapshot.room);
    ref
        .read(gameStateProvider.notifier)
        .applySnapshot(
          roomId: snapshot.room.id,
          roomCode: snapshot.room.code,
          currentRound: round.number,
          maxRounds: snapshot.turnCount,
          phase: round.phase.gamePhase,
          currentQuestion: question,
          guesses: guesses,
          bets: bets,
          scores: snapshot.scores,
          correctAnswer: round.phase == PartyRoundPhase.reveal
              ? round.proposedResult
              : null,
          winningGuessId: null,
          hasSubmittedGuess: false,
        );
    _partySnapshot = snapshot;
    ref.read(partySessionProvider.notifier).setSnapshot(snapshot);
    if (previous?.round.number != round.number) {
      _guessInput = '';
      _selectedChipValue = null;
      _selectedBetId = null;
      _isSubmittingGuess = false;
      _roundWinners.clear();
      _roundPayouts.clear();
      _revealedResultRound = null;
    }
    _syncAudioForPhase(round.phase.gamePhase);
    switch (round.phase) {
      case PartyRoundPhase.guessing:
        _startTimer(
          GameConstants.guessTimerSeconds,
          deadline: round.phaseEndsAt,
        );
        break;
      case PartyRoundPhase.betting:
        _startTimer(
          GameConstants.partyBetTimerSeconds,
          deadline: round.phaseEndsAt,
        );
        break;
      case PartyRoundPhase.action:
        _startTimer(
          round.challenge.durationSeconds,
          deadline: round.phaseEndsAt,
        );
        break;
      case PartyRoundPhase.reveal:
        _stopTimer();
        unawaited(_startRevealSequence(ref.read(gameStateProvider)));
        if (ref.read(isHostProvider)) {
          _scheduleRoundAdvance(
            deadline: round.phaseEndsAt,
            fallback: const Duration(
              seconds: GameConstants.partyRoundResultsSeconds,
            ),
          );
        } else {
          _roundAdvanceTimer?.cancel();
          _roundAdvanceTimer = Timer(
            _phaseDelay(
                  round.phaseEndsAt,
                  const Duration(
                    seconds: GameConstants.partyRoundResultsSeconds,
                  ),
                ) +
                const Duration(seconds: 1),
            () {
              if (_canUseRef) unawaited(_resyncPartySnapshot());
            },
          );
        }
        break;
      case PartyRoundPhase.ready:
      case PartyRoundPhase.resultEntry:
      case PartyRoundPhase.resultConfirm:
        _stopTimer();
        break;
    }
    _schedulePartySnapshotWatchdog(snapshot);
    if (currentPlayer?.id == round.performer.id &&
        round.phase != PartyRoundPhase.betting) {
      _selectedChipValue = null;
      _selectedBetId = null;
    }
    if (_canUseRef) setState(() {});
  }

  Future<void> _broadcastPartyState(PartySnapshot snapshot) async {
    await _realtimeService.broadcast(widget.roomCode, 'phase_change', {
      'phase': snapshot.round.phase.gamePhase.name,
      'round': snapshot.round.number,
      'state_version': snapshot.stateVersion,
    });
  }

  Future<void> _runPartyCommand(
    Future<PartySnapshot> Function() command,
  ) async {
    if (_isPartyCommandInFlight) return;
    _isPartyCommandInFlight = true;
    try {
      final snapshot = await command();
      if (!_canUseRef) return;
      _applyPartySnapshot(snapshot);
      unawaited(_broadcastPartyState(snapshot));
    } catch (error, stackTrace) {
      debugPrint('Party command failed: $error\n$stackTrace');
      _showGameMessage('Could not continue: $error');
      if (_canUseRef) {
        await _resyncPartySnapshot(synchronizeClock: false);
      }
    } finally {
      _isPartyCommandInFlight = false;
      if (_canUseRef) setState(() {});
    }
  }

  void _showGameMessage(String message) {
    if (!_canUseRef) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _goToResults() {
    if (!_canUseRef) return;
    context.goNamed('results', pathParameters: {'roomCode': widget.roomCode});
  }

  void _startTimer(int fallbackSeconds, {DateTime? deadline}) {
    _stopTimer();
    _phaseDeadline = deadline;
    _timerSeconds = deadline == null
        ? fallbackSeconds
        : GameSyncPolicy.remainingSeconds(
            deadline: deadline,
            now: ref.read(roomServiceProvider).serverNow,
          );

    // Defer the provider update until after the build cycle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_canUseRef) {
        ref.read(gameTimerProvider.notifier).setTimer(_timerSeconds);
      }
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_canUseRef) {
        timer.cancel();
        if (identical(_timer, timer)) _timer = null;
        return;
      }
      final deadline = _phaseDeadline;
      final remaining = deadline == null
          ? max(0, _timerSeconds - 1)
          : GameSyncPolicy.remainingSeconds(
              deadline: deadline,
              now: ref.read(roomServiceProvider).serverNow,
            );
      if (remaining > 0) {
        _timerSeconds = remaining;
        ref.read(gameTimerProvider.notifier).setTimer(_timerSeconds);
        if (_timerSeconds == 10) {
          _audioService.startTicking();
        }
      } else {
        timer.cancel();
        _timer = null;
        _timerSeconds = 0;
        ref.read(gameTimerProvider.notifier).setTimer(0);
        _audioService.stopTicking();
        _audioService.playTimeUp();
        _handleTimerFinished();
      }
    });
  }

  void _stopTimer({bool clearDeadline = true}) {
    _timer?.cancel();
    _timer = null;
    if (clearDeadline) _phaseDeadline = null;
    unawaited(_audioService.stopTicking());
  }

  void _schedulePartyTransitionFallback({
    required String roomId,
    required PartyRoundPhase expectedPhase,
  }) {
    _partyTransitionFallbackTimer?.cancel();
    final playerId = ref.read(currentPlayerProvider)?.id ?? '';
    final staggerMs = playerId.hashCode.abs() % 1500;
    _partyTransitionFallbackTimer = Timer(
      Duration(milliseconds: 2000 + staggerMs),
      () async {
        _partyTransitionFallbackTimer = null;
        if (!_canUseRef) return;
        await _resyncPartySnapshot(synchronizeClock: false);
        if (!_canUseRef) return;
        final round = _partySnapshot?.round;
        if (round == null || round.phase != expectedPhase) return;
        final deadline = round.phaseEndsAt;
        if (GameSyncPolicy.isInteractionWindowOpen(
          deadline: deadline,
          now: ref.read(roomServiceProvider).serverNow,
          networkSafetyMargin: Duration.zero,
        )) {
          return;
        }
        switch (expectedPhase) {
          case PartyRoundPhase.guessing:
            await _revealGuesses();
            break;
          case PartyRoundPhase.betting:
            await _revealAnswer();
            break;
          case PartyRoundPhase.action:
            await _runPartyCommand(
              () => ref.read(partyGameServiceProvider).openResultEntry(roomId),
            );
            break;
          case PartyRoundPhase.ready:
          case PartyRoundPhase.resultEntry:
          case PartyRoundPhase.resultConfirm:
          case PartyRoundPhase.reveal:
            break;
        }
      },
    );
  }

  void _handleTimerFinished() {
    if (!_canUseRef) return;
    final gameState = ref.read(gameStateProvider);
    final room = ref.read(currentRoomProvider);
    if (room?.gameMode == GameMode.party) {
      final isHost = ref.read(isHostProvider);
      if (gameState.phase == RoundPhase.guessing) {
        if (isHost) {
          _revealGuesses();
        } else {
          _schedulePartyTransitionFallback(
            roomId: room!.id,
            expectedPhase: PartyRoundPhase.guessing,
          );
        }
      } else if (gameState.phase == RoundPhase.betting) {
        _lockBettingWindow();
        if (isHost) {
          _revealAnswer();
        } else {
          _schedulePartyTransitionFallback(
            roomId: room!.id,
            expectedPhase: PartyRoundPhase.betting,
          );
        }
      } else if (gameState.phase == RoundPhase.partyAction) {
        if (isHost) {
          _runPartyCommand(
            () => ref.read(partyGameServiceProvider).openResultEntry(room!.id),
          );
        } else {
          _schedulePartyTransitionFallback(
            roomId: room!.id,
            expectedPhase: PartyRoundPhase.action,
          );
        }
      }
      return;
    }
    if (gameState.phase == RoundPhase.guessing) {
      _revealGuesses();
    } else if (gameState.phase == RoundPhase.betting) {
      _revealAnswer();
    }
  }

  Future<void> _startRound(int round) async {
    final room = ref.read(currentRoomProvider);
    if (room == null ||
        room.currentRound != round ||
        room.roundPhase != RoundPhase.question) {
      return;
    }
    _questionStartTimer?.cancel();

    final gameService = ref.read(gameServiceProvider);
    final realtimeService = ref.read(realtimeServiceProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);

    final secureQuestion = await gameService.claimNextQuestion(
      roomId: room.id,
      roundNumber: round,
      durationSeconds: GameConstants.guessTimerSeconds,
    );
    if (secureQuestion == null) {
      await _resyncFromServer();
      return;
    }
    final question = secureQuestion.question;
    _usedQuestionIds.add(question.id);
    final claimedRoom = secureQuestion.room;
    ref.read(currentRoomProvider.notifier).set(claimedRoom);

    gameNotifier.setRound(round);
    gameNotifier.setQuestion(question);
    gameNotifier.updatePhase(RoundPhase.guessing);
    _syncAudioForPhase(RoundPhase.guessing);
    _cancelRevealEffects();
    _roundWinners.clear();
    _roundPayouts.clear();
    _revealedResultRound = null;
    gameNotifier.resetForNewRound();
    _guessInput = '';
    _selectedChipValue = null;
    _isSubmittingGuess = false;

    await realtimeService.broadcast(widget.roomCode, 'phase_change', {
      'phase': RoundPhase.guessing.name,
      'round': round,
      'question': question.toJson(),
      'phase_ends_at': claimedRoom.phaseEndsAt?.toIso8601String(),
    });

    _startTimer(
      GameConstants.guessTimerSeconds,
      deadline: claimedRoom.phaseEndsAt,
    );
    if (mounted) setState(() {});
    _playQuestionRevealOnce(question);
  }

  Future<void> _revealGuesses() async {
    final room = ref.read(currentRoomProvider);
    if (room == null) return;
    final gameState = ref.read(gameStateProvider);
    if (_isRevealingGuesses || gameState.phase != RoundPhase.guessing) return;
    _isRevealingGuesses = true;

    try {
      if (room.gameMode == GameMode.party) {
        await _runPartyCommand(
          () => ref
              .read(partyGameServiceProvider)
              .advanceToBetting(
                room.id,
                durationSeconds: GameConstants.partyBetTimerSeconds,
              ),
        );
        return;
      }
      final gameService = ref.read(gameServiceProvider);
      final realtimeService = ref.read(realtimeServiceProvider);
      final gameNotifier = ref.read(gameStateProvider.notifier);
      final claimedRoom = await ref
          .read(roomServiceProvider)
          .claimPhaseTransition(
            roomId: room.id,
            round: gameState.currentRound,
            expectedPhase: RoundPhase.guessing.name,
            nextPhase: RoundPhase.betting.name,
            durationSeconds: GameConstants.betTimerSeconds,
          );
      if (claimedRoom == null) {
        await _resyncFromServer();
        return;
      }

      final guesses = await gameService.getGuesses(
        room.id,
        gameState.currentRound,
      );
      final enrichedGuesses = guesses.map((guess) {
        final player = _playerById(guess.playerId);
        return guess.copyWith(
          playerName: player?.name,
          playerColor: player?.avatarColor,
        );
      }).toList();

      gameNotifier.setGuesses(enrichedGuesses);
      gameNotifier.updatePhase(RoundPhase.betting);
      _syncAudioForPhase(RoundPhase.betting);
      _stopTimer();

      await realtimeService.broadcast(widget.roomCode, 'guesses_revealed', {
        'round': gameState.currentRound,
        'guesses': enrichedGuesses
            .map(
              (g) => {
                ...g.toJson(),
                'id': g.id,
                'player_name': g.playerName,
                'player_color': g.playerColor,
              },
            )
            .toList(),
      });

      await realtimeService.broadcast(widget.roomCode, 'phase_change', {
        'phase': RoundPhase.betting.name,
        'round': gameState.currentRound,
        'phase_ends_at': claimedRoom.phaseEndsAt?.toIso8601String(),
      });

      _startTimer(
        GameConstants.betTimerSeconds,
        deadline: claimedRoom.phaseEndsAt,
      );
    } finally {
      _isRevealingGuesses = false;
    }
  }

  Future<void> _revealAnswer() async {
    final room = ref.read(currentRoomProvider);
    if (room == null) return;

    if (room.gameMode == GameMode.party) {
      _stopTimer();
      await _runPartyCommand(
        () => ref.read(partyGameServiceProvider).beginReady(room.id),
      );
      return;
    }

    final gameService = ref.read(gameServiceProvider);
    final realtimeService = ref.read(realtimeServiceProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);
    final gameState = ref.read(gameStateProvider);
    _stopTimer();

    final bets = await gameService.getBets(room.id, gameState.currentRound);
    late final RoundSettlementResult settlement;
    try {
      settlement = await gameService.settleRound(
        roomId: room.id,
        roundNumber: gameState.currentRound,
      );
    } catch (error, stackTrace) {
      debugPrint('Atomic round settlement failed: $error\n$stackTrace');
      await _resyncFromServer();
      return;
    }
    final correctAnswer = settlement.answer;
    final winningGuessId = settlement.winningGuessId;
    final newScores = settlement.scores;
    final payouts = settlement.payouts;
    ref
        .read(currentRoomProvider.notifier)
        .set(
          room.copyWith(
            roundPhase: RoundPhase.revealAnswer,
            stateVersion: settlement.stateVersion,
            phaseEndsAt: settlement.phaseEndsAt,
          ),
        );

    gameNotifier.revealAnswer(
      answer: correctAnswer,
      winningGuessId: winningGuessId,
      bets: bets,
      scores: newScores,
    );
    _syncAudioForPhase(RoundPhase.revealAnswer);
    unawaited(
      _startRevealSequence(ref.read(gameStateProvider), payouts: payouts),
    );

    await realtimeService.broadcast(widget.roomCode, 'answer_revealed', {
      'round': gameState.currentRound,
      'answer': correctAnswer,
      'winning_guess_id': winningGuessId,
    });
    await realtimeService.broadcast(widget.roomCode, 'score_update', {
      'round': gameState.currentRound,
      'scores': newScores,
    });
    await realtimeService.broadcast(widget.roomCode, 'phase_change', {
      'phase': RoundPhase.revealAnswer.name,
      'round': gameState.currentRound,
    });

    _scheduleRoundAdvance(deadline: settlement.phaseEndsAt);
  }

  void _playRevealAudioForCurrentPlayer(GameState gameState) {
    final payout = _currentPlayerRoundPayout(gameState);
    final audio = ref.read(audioServiceProvider);
    if (payout > 0) {
      audio.playPayout();
    } else {
      audio.playChipLoss();
    }
  }

  Future<void> _startRevealSequence(
    GameState gameState, {
    Map<String, int>? payouts,
  }) async {
    final correctAnswer = gameState.correctAnswer;
    if (correctAnswer == null ||
        _revealedResultRound == gameState.currentRound) {
      return;
    }
    _revealedResultRound = gameState.currentRound;

    _cancelRevealEffects();
    final sequenceId = _revealSequenceId;
    await ref.read(audioServiceProvider).playResultReveal();
    if (!_canUseRef || sequenceId != _revealSequenceId) return;

    final resolvedPayouts =
        payouts ??
        (_partySnapshot?.round.phase == PartyRoundPhase.reveal
            ? _partyRoundPayouts(gameState.bets)
            : ref
                  .read(gameServiceProvider)
                  .calculatePayouts(
                    guesses: gameState.sortedGuesses,
                    bets: gameState.bets,
                    correctAnswer: correctAnswer,
                  ));
    final winners = resolvedPayouts.entries
        .where((entry) => entry.value > 0)
        .map((entry) => entry.key)
        .toSet();
    final winningSlotIndex = _winningBetSlotIndex(gameState);
    final scanOrder = _partySnapshot?.round.challenge.isBinary == true
        ? [0, 1, 0, 1, if (winningSlotIndex != null) winningSlotIndex]
        : [
            4,
            3,
            2,
            1,
            0,
            4,
            3,
            2,
            1,
            0,
            if (winningSlotIndex != null) winningSlotIndex,
          ];

    var step = 0;
    setState(() {
      _roundPayouts = resolvedPayouts;
      _roundWinners = winners;
      _showWinnerBadge = false;
      _scanSlotIndexNotifier.value = scanOrder.isEmpty ? null : scanOrder.first;
    });

    _slotScanTimer = Timer.periodic(const Duration(milliseconds: 240), (timer) {
      if (!_canUseRef || sequenceId != _revealSequenceId) {
        timer.cancel();
        return;
      }
      step++;
      if (step >= scanOrder.length) {
        timer.cancel();
        setState(() {
          _showWinnerBadge = true;
        });
        _scanSlotIndexNotifier.value = winningSlotIndex;
        _playRevealAudioForCurrentPlayer(gameState);
        _revealEffectTimers.add(
          Timer(const Duration(milliseconds: 240), () {
            if (_canUseRef) _audioService.playClink();
          }),
        );
        return;
      }
      _audioService.playClick();
      _scanSlotIndexNotifier.value = scanOrder[step];
    });
  }

  void _cancelRevealEffects() {
    _revealSequenceId++;
    _slotScanTimer?.cancel();
    _slotScanTimer = null;
    for (final timer in _revealEffectTimers) {
      timer.cancel();
    }
    _revealEffectTimers.clear();
    _scanSlotIndexNotifier.value = null;
    _showWinnerBadge = false;
  }

  bool _isRevealPhase(GameState gameState) {
    return gameState.phase == RoundPhase.revealAnswer ||
        gameState.phase == RoundPhase.scoring;
  }

  int? _winningBetSlotIndex(GameState gameState) {
    final correctAnswer = gameState.correctAnswer;
    if (correctAnswer == null) return null;
    final partySlot = _partySnapshot?.round.challenge.betSlotForResult(
      correctAnswer,
    );
    if (partySlot != null) return partySlot;
    return ref
        .read(gameServiceProvider)
        .determineWinningBetSlotIndex(gameState.sortedGuesses, correctAnswer);
  }

  int _currentPlayerRoundPayout(GameState gameState) {
    final currentPlayer = ref.read(currentPlayerProvider);
    final partyRound = _partySnapshot?.round;
    if (currentPlayer != null &&
        partyRound?.phase == PartyRoundPhase.reveal &&
        partyRound?.performer.id == currentPlayer.id) {
      return _partyPerformerBonus(partyRound!);
    }
    final winningSlotIndex = _winningBetSlotIndex(gameState);
    if (currentPlayer == null || winningSlotIndex == null) return 0;

    var payout = 0;
    for (final bet in gameState.bets) {
      if (bet.playerId == currentPlayer.id &&
          bet.slotIndex == winningSlotIndex) {
        payout += bet.chips * bet.payoutMultiplier;
      }
    }

    return payout;
  }

  int _partyPerformerBonus(PartyRoundSnapshot round) {
    return round.performerBonus;
  }

  Map<String, int> _partyRoundPayouts(List<Bet> bets) {
    final payouts = <String, int>{};
    for (final bet in bets.where((bet) => bet.won)) {
      payouts.update(
        bet.playerId,
        (value) => value + bet.chips * bet.payoutMultiplier,
        ifAbsent: () => bet.chips * bet.payoutMultiplier,
      );
    }
    return payouts;
  }

  int _currentPlayerTotalBets(GameState gameState) {
    final currentPlayer = ref.read(currentPlayerProvider);
    if (currentPlayer == null) return 0;
    return gameState.bets
        .where((b) => b.playerId == currentPlayer.id)
        .fold(0, (sum, bet) => sum + bet.chips);
  }

  bool _canCurrentPlayerEditBets(GameState gameState) {
    if (gameState.phase != RoundPhase.betting) return false;
    final room = ref.read(currentRoomProvider);
    if (room == null) return false;

    // Classic can receive the phase broadcast before the rooms-row update.
    // Until that row arrives, its deadline still belongs to the previous phase
    // and would incorrectly lock a live betting board. The Classic RPC remains
    // the authority for rejecting genuinely late writes.
    if (room.gameMode != GameMode.party) return true;

    final deadline = _partySnapshot?.round.phaseEndsAt ?? room.phaseEndsAt;
    if (!GameSyncPolicy.isInteractionWindowOpen(
      deadline: deadline,
      now: ref.read(roomServiceProvider).serverNow,
    )) {
      return false;
    }
    final player = ref.read(currentPlayerProvider);
    return player != null && _partySnapshot?.round.performer.id != player.id;
  }

  void _lockBettingWindow() {
    _selectedChipValue = null;
    _selectedBetId = null;
    if (_canUseRef) setState(() {});
  }

  bool _isBettingClosedError(Object error) {
    return error is BettingWindowClosedException ||
        (error is PostgrestException &&
            error.code == '40001' &&
            error.message.toLowerCase().contains('betting'));
  }

  void _recoverFromClosedBettingWindow() {
    _lockBettingWindow();
    if (_canUseRef) {
      unawaited(_resyncFromServer(synchronizeClock: false));
    }
  }

  Future<void> _nextRound() async {
    if (!_canUseRef) return;
    final gameState = ref.read(gameStateProvider);
    final room = ref.read(currentRoomProvider);
    if (room == null) return;
    if (room.gameMode == GameMode.party) {
      if (!ref.read(isHostProvider)) {
        await _resyncPartySnapshot();
        return;
      }
      if (_isPartyCommandInFlight) return;
      _isPartyCommandInFlight = true;
      final partyService = ref.read(partyGameServiceProvider);
      try {
        final response = await partyService.advanceRound(room.id);
        if (!_canUseRef) return;
        if (response['finished'] == true) {
          final roomJson = response['room'];
          if (roomJson is Map) {
            ref
                .read(currentRoomProvider.notifier)
                .set(Room.fromJson(Map<String, dynamic>.from(roomJson)));
          }
          unawaited(
            _realtimeService.broadcast(widget.roomCode, 'game_ended', const {}),
          );
          _goToResults();
          return;
        }
        final snapshot = PartySnapshot.fromJson(response);
        _applyPartySnapshot(snapshot);
        unawaited(_broadcastPartyState(snapshot));
      } catch (error, stackTrace) {
        debugPrint('Party round advance failed: $error\n$stackTrace');
        if (_canUseRef) {
          await _resyncPartySnapshot(synchronizeClock: false);
        }
      } finally {
        _isPartyCommandInFlight = false;
      }
      return;
    }
    final roomService = ref.read(roomServiceProvider);
    final realtimeService = ref.read(realtimeServiceProvider);

    if (gameState.currentRound >= gameState.maxRounds) {
      final didFinish = await roomService.finishGameIfCurrent(
        roomId: room.id,
        round: gameState.currentRound,
      );
      if (!didFinish) {
        await _resyncFromServer();
        return;
      }
      // Finishing the row is authoritative. Navigate immediately instead of
      // waiting for an optional broadcast that may arrive late or fail.
      ref
          .read(currentRoomProvider.notifier)
          .set(
            room.copyWith(
              status: RoomStatus.finished,
              roundPhase: RoundPhase.idle,
            ),
          );
      unawaited(
        realtimeService.broadcast(widget.roomCode, 'game_ended', {}).catchError(
          (Object error, StackTrace stackTrace) {
            debugPrint('Game-ended broadcast failed: $error\n$stackTrace');
          },
        ),
      );
      if (!mounted || !_canUseRef) return;
      context.goNamed('results', pathParameters: {'roomCode': widget.roomCode});
    } else {
      final nextRound = gameState.currentRound + 1;
      final claimedRoom = await roomService.claimPhaseTransition(
        roomId: room.id,
        round: gameState.currentRound,
        expectedPhase: RoundPhase.revealAnswer.name,
        nextPhase: RoundPhase.question.name,
        nextRound: nextRound,
        durationSeconds: GameConstants.roundTransitionSeconds,
      );
      if (claimedRoom == null) {
        await _resyncFromServer();
        return;
      }
      ref.read(currentRoomProvider.notifier).set(claimedRoom);
      ref
          .read(gameStateProvider.notifier)
          .beginAuthoritativeRound(nextRound, RoundPhase.question);
      _syncAudioForPhase(RoundPhase.question);
      _playQuestionRevealForRoundOnce(nextRound);
      if (mounted) setState(() {});
      _scheduleQuestionStart(claimedRoom, primary: true);
    }
  }

  Duration _phaseDelay(DateTime? deadline, Duration fallback) {
    if (deadline == null) return fallback;
    final remaining = deadline
        .difference(ref.read(roomServiceProvider).serverNow)
        .inMilliseconds;
    return Duration(milliseconds: max(0, remaining));
  }

  void _scheduleQuestionStart(Room room, {bool primary = false}) {
    if (room.roundPhase != RoundPhase.question) return;
    _questionStartTimer?.cancel();
    final delay = _phaseDelay(
      room.phaseEndsAt,
      const Duration(seconds: GameConstants.roundTransitionSeconds),
    );
    final failoverGrace = primary
        ? Duration.zero
        : const Duration(milliseconds: 250);
    _questionStartTimer = Timer(delay + failoverGrace, () {
      if (!_canUseRef) return;
      final latestRoom = ref.read(currentRoomProvider);
      if (latestRoom?.currentRound == room.currentRound &&
          latestRoom?.roundPhase == RoundPhase.question) {
        unawaited(_startRound(room.currentRound));
      }
    });
  }

  void _scheduleRoundAdvance({DateTime? deadline, Duration? fallback}) {
    _roundAdvanceTimer?.cancel();
    final delay = _phaseDelay(
      deadline,
      fallback ?? const Duration(seconds: GameConstants.roundResultsSeconds),
    );
    _roundAdvanceTimer = Timer(delay, () {
      if (_canUseRef) unawaited(_nextRound());
    });
  }

  Future<void> _submitGuess(int value) async {
    if (!_canUseRef) return;
    final room = ref.read(currentRoomProvider);
    if (room == null) return;

    var gameState = ref.read(gameStateProvider);
    if (gameState.hasSubmittedGuess) return;
    var player =
        ref.read(currentPlayerProvider) ?? _restoreCurrentPlayer(room.id);
    if (player == null) {
      await _resyncFromServer();
      player =
          ref.read(currentPlayerProvider) ?? _restoreCurrentPlayer(room.id);
      gameState = ref.read(gameStateProvider);
    }
    if (player == null || gameState.hasSubmittedGuess) {
      if (player == null) {
        _showGameMessage('Player connection could not be restored.');
      }
      return;
    }

    final gameService = ref.read(gameServiceProvider);
    final realtimeService = ref.read(realtimeServiceProvider);

    if (!_canUseRef) return;
    setState(() => _isSubmittingGuess = true);

    try {
      if (room.gameMode == GameMode.party) return;
      await gameService.submitGuess(
        roomId: room.id,
        roundNumber: gameState.currentRound,
        playerId: player.id,
        questionId: gameState.currentQuestion?.id ?? '',
        value: value,
      );

      ref.read(gameStateProvider.notifier).setGuessSubmitted(true);
      await realtimeService.broadcast(widget.roomCode, 'guess_submitted', {
        'round': gameState.currentRound,
        'player_id': player.id,
      });
      await _maybeAutoRevealGuesses();
    } catch (error, stackTrace) {
      debugPrint('Guess submit failed: $error\n$stackTrace');
      _showGameMessage('Guess could not be sent. Try again.');
    } finally {
      if (_canUseRef) setState(() => _isSubmittingGuess = false);
    }
  }

  Future<void> _maybeAutoRevealGuesses() async {
    final isHost = ref.read(isHostProvider);
    final room = ref.read(currentRoomProvider);
    final gameState = ref.read(gameStateProvider);
    if (!isHost ||
        room == null ||
        gameState.phase != RoundPhase.guessing ||
        _isRevealingGuesses) {
      return;
    }

    // We intentionally removed auto-reveal here to force players to wait for the 30 second timer.
  }

  void _appendGuessDigit(String digit) {
    final gameState = ref.read(gameStateProvider);
    if (gameState.hasSubmittedGuess ||
        _isSubmittingGuess ||
        _guessInput.length >= 10) {
      return;
    }
    _playButtonFeedback();
    if (_guessInput == '0') {
      setState(() => _guessInput = digit);
    } else {
      setState(() => _guessInput += digit);
    }
  }

  void _backspaceGuessDigit() {
    final gameState = ref.read(gameStateProvider);
    if (gameState.hasSubmittedGuess ||
        _isSubmittingGuess ||
        _guessInput.isEmpty) {
      return;
    }
    _playButtonFeedback();
    setState(
      () => _guessInput = _guessInput.substring(0, _guessInput.length - 1),
    );
  }

  void _clearGuessInput() {
    final gameState = ref.read(gameStateProvider);
    if (gameState.hasSubmittedGuess || _isSubmittingGuess) return;
    _playButtonFeedback();
    setState(() => _guessInput = '');
  }

  Future<void> _submitNumpadGuess() async {
    final value = int.tryParse(_guessInput);
    if (value == null) return;
    _playButtonFeedback();
    await _submitGuess(value);
  }

  void _playButtonFeedback() {
    unawaited(ref.read(audioServiceProvider).playButtonTap());
    unawaited(HapticFeedback.selectionClick());
  }

  Future<void> _placeBet(int slotIndex, int chips, {Offset? position}) async {
    if (!_canUseRef) return;
    final room = ref.read(currentRoomProvider);
    final player = ref.read(currentPlayerProvider);
    final gameState = ref.read(gameStateProvider);
    if (room == null || player == null || _isBetOperationInFlight) {
      return;
    }
    if (!_canCurrentPlayerEditBets(gameState)) {
      _lockBettingWindow();
      return;
    }
    if (room.gameMode == GameMode.party &&
        _partySnapshot?.round.performer.id == player.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The performer does not bet this round.')),
      );
      return;
    }

    final totalBets = _currentPlayerTotalBets(gameState);
    final currentScore = gameState.scores[player.id] ?? player.score;
    if (totalBets + chips > currentScore) {
      setState(() => _selectedChipValue = null);
      ref.read(audioServiceProvider).playClick(); // error sound fallback
      return;
    }

    final gameService = ref.read(gameServiceProvider);
    final realtimeService = ref.read(realtimeServiceProvider);
    _isBetOperationInFlight = true;

    ref.read(audioServiceProvider).playDrop();

    final targetGuessId = _targetGuessIdForSlot(slotIndex, gameState);

    final safeDx = (position != null && position.dx.isFinite)
        ? position.dx
        : null;
    final safeDy = (position != null && position.dy.isFinite)
        ? position.dy
        : null;

    final clientActionId = const Uuid().v4();
    final optimisticId = 'local-$clientActionId';
    final optimisticBet = Bet(
      id: optimisticId,
      roomId: room.id,
      roundNumber: gameState.currentRound,
      playerId: player.id,
      targetGuessId: targetGuessId,
      slotIndex: slotIndex,
      chips: chips,
      payoutMultiplier:
          room.gameMode == GameMode.party &&
              _partySnapshot?.round.challenge.isBinary == true
          ? 2
          : GameConstants.boardOdds[slotIndex],
      playerName: player.name,
      playerColor: player.avatarColor,
      positionX: safeDx,
      positionY: safeDy,
    );

    final gameNotifier = ref.read(gameStateProvider.notifier);
    gameNotifier.addBet(optimisticBet);
    if (_canUseRef) setState(() {});

    try {
      if (room.gameMode == GameMode.party) {
        final partyService = ref.read(partyGameServiceProvider);
        final snapshot = await partyService.placeBet(
          roomId: room.id,
          slotIndex: slotIndex,
          chips: chips,
          clientActionId: clientActionId,
          positionX: safeDx,
          positionY: safeDy,
        );
        if (!_canUseRef) return;
        gameNotifier.removeBetById(optimisticId);
        _applyPartySnapshot(snapshot);
        unawaited(_broadcastPartyState(snapshot));
        return;
      }
      final bet = await gameService.placeBet(
        roomId: room.id,
        roundNumber: gameState.currentRound,
        playerId: player.id,
        targetGuessId: targetGuessId,
        slotIndex: slotIndex,
        chips: chips,
        clientActionId: clientActionId,
        positionX: safeDx,
        positionY: safeDy,
      );

      final placedBet = bet.copyWith(
        playerName: player.name,
        playerColor: player.avatarColor,
        positionX: safeDx,
        positionY: safeDy,
      );

      gameNotifier.replaceBet(optimisticId, placedBet);

      unawaited(
        realtimeService
            .broadcast(widget.roomCode, 'bet_placed', {
              'bet': {
                ...placedBet.toJson(),
                'id': bet.id,
                'player_name': player.name,
                'player_color': player.avatarColor,
              },
            })
            .catchError((Object error, StackTrace stackTrace) {
              debugPrint('Bet broadcast failed: $error\n$stackTrace');
            }),
      );
    } catch (error, stackTrace) {
      gameNotifier.removeBetById(optimisticId);
      if (_isBettingClosedError(error)) {
        _recoverFromClosedBettingWindow();
      } else {
        debugPrint('Bet placement failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        if (_canUseRef) {
          unawaited(_resyncFromServer(synchronizeClock: false));
        }
      }
    } finally {
      _isBetOperationInFlight = false;
    }

    _selectedBetId = null;
    if (_canUseRef) setState(() {});
  }

  Future<void> _moveBet(
    Bet sourceBet,
    int targetSlotIndex, {
    Offset? position,
  }) async {
    if (!_canUseRef) return;
    final room = ref.read(currentRoomProvider);
    final gameState = ref.read(gameStateProvider);
    if (room == null ||
        sourceBet.id.startsWith('local-') ||
        _isBetOperationInFlight) {
      return;
    }
    if (!_canCurrentPlayerEditBets(gameState)) {
      _lockBettingWindow();
      return;
    }

    final gameService = ref.read(gameServiceProvider);
    final realtimeService = ref.read(realtimeServiceProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);
    final oldBet = sourceBet;
    final targetGuessId = _targetGuessIdForSlot(targetSlotIndex, gameState);
    final safeDx = (position != null && position.dx.isFinite)
        ? position.dx
        : null;
    final safeDy = (position != null && position.dy.isFinite)
        ? position.dy
        : null;

    final optimisticBet = sourceBet.copyWith(
      targetGuessId: targetGuessId,
      slotIndex: targetSlotIndex,
      payoutMultiplier:
          room.gameMode == GameMode.party &&
              _partySnapshot?.round.challenge.isBinary == true
          ? 2
          : GameConstants.boardOdds[targetSlotIndex],
      positionX: safeDx,
      positionY: safeDy,
    );

    _isBetOperationInFlight = true;
    ref.read(audioServiceProvider).playDrop();
    gameNotifier.addBet(optimisticBet);
    if (_canUseRef) setState(() {});

    try {
      if (room.gameMode == GameMode.party) {
        final partyService = ref.read(partyGameServiceProvider);
        final snapshot = await partyService.moveBet(
          roomId: room.id,
          betId: sourceBet.id,
          slotIndex: targetSlotIndex,
          positionX: safeDx,
          positionY: safeDy,
        );
        if (!_canUseRef) return;
        _applyPartySnapshot(snapshot);
        unawaited(_broadcastPartyState(snapshot));
        return;
      }
      final movedBet = await gameService.updateBet(
        betId: sourceBet.id,
        targetGuessId: targetGuessId,
        slotIndex: targetSlotIndex,
        positionX: safeDx,
        positionY: safeDy,
      );

      final placedBet = movedBet.copyWith(
        playerName: sourceBet.playerName,
        playerColor: sourceBet.playerColor,
        positionX: safeDx,
        positionY: safeDy,
      );
      gameNotifier.addBet(placedBet);

      unawaited(
        realtimeService
            .broadcast(widget.roomCode, 'bet_placed', {
              'bet': {
                ...placedBet.toJson(),
                'id': placedBet.id,
                'player_name': placedBet.playerName,
                'player_color': placedBet.playerColor,
              },
            })
            .catchError((Object error, StackTrace stackTrace) {
              debugPrint('Bet move broadcast failed: $error\n$stackTrace');
            }),
      );
    } catch (error, stackTrace) {
      gameNotifier.addBet(oldBet);
      if (_isBettingClosedError(error)) {
        _recoverFromClosedBettingWindow();
      } else {
        debugPrint('Bet move failed: $error\n$stackTrace');
        if (_canUseRef) {
          unawaited(_resyncFromServer(synchronizeClock: false));
        }
      }
    } finally {
      _isBetOperationInFlight = false;
    }

    _selectedBetId = sourceBet.id;
    _selectedChipValue = null;
    if (_canUseRef) setState(() {});
  }

  String? _targetGuessIdForSlot(int slotIndex, GameState gameState) {
    return null;
  }

  Future<void> _removeBetById(Bet bet) async {
    if (_isBetOperationInFlight || !_canUseRef) return;
    if (!_canCurrentPlayerEditBets(ref.read(gameStateProvider))) {
      _lockBettingWindow();
      return;
    }

    final gameService = ref.read(gameServiceProvider);
    final realtimeService = ref.read(realtimeServiceProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);

    _isBetOperationInFlight = true;
    ref.read(audioServiceProvider).playClick();
    if (_selectedBetId == bet.id) _selectedBetId = null;
    gameNotifier.removeBetById(bet.id);
    if (_canUseRef) setState(() {});

    try {
      if (!bet.id.startsWith('local-')) {
        final room = ref.read(currentRoomProvider);
        if (room?.gameMode == GameMode.party) {
          final partyService = ref.read(partyGameServiceProvider);
          final snapshot = await partyService.removeBet(
            roomId: room!.id,
            betId: bet.id,
          );
          if (!_canUseRef) return;
          _applyPartySnapshot(snapshot);
          unawaited(_broadcastPartyState(snapshot));
          return;
        }
        await gameService.removeBet(bet.id);
        unawaited(
          realtimeService
              .broadcast(widget.roomCode, 'bet_removed', {
                'round': bet.roundNumber,
                'bet_id': bet.id,
                'player_id': bet.playerId,
                'slot_index': bet.slotIndex,
              })
              .catchError((Object error, StackTrace stackTrace) {
                debugPrint('Bet removal broadcast failed: $error\n$stackTrace');
              }),
        );
      }
    } catch (error, stackTrace) {
      gameNotifier.addBet(bet);
      if (_isBettingClosedError(error)) {
        _recoverFromClosedBettingWindow();
      } else {
        debugPrint('Bet removal failed: $error\n$stackTrace');
        if (_canUseRef) {
          unawaited(_resyncFromServer(synchronizeClock: false));
        }
      }
    } finally {
      _isBetOperationInFlight = false;
    }

    if (_canUseRef) setState(() {});
  }

  Bet? _selectedBet(GameState gameState) {
    final selectedId = _selectedBetId;
    if (selectedId == null) return null;
    for (final bet in gameState.bets) {
      if (bet.id == selectedId) return bet;
    }
    return null;
  }

  void _selectBetForMove(Bet bet) {
    if (_isBetOperationInFlight) return;
    ref.read(audioServiceProvider).playChip();
    setState(() {
      _selectedBetId = bet.id;
      _selectedChipValue = null;
    });
  }

  Future<void> _removeSelectedBet() async {
    final bet = _selectedBet(ref.read(gameStateProvider));
    if (bet == null) {
      setState(() {
        _selectedBetId = null;
        _selectedChipValue = null;
      });
      return;
    }
    await _removeBetById(bet);
  }

  Player? _playerById(String playerId) {
    for (final player in _players) {
      if (player.id == playerId) return player;
    }
    return null;
  }

  List<_LeaderboardEntry> _leaderboardEntries(GameState gameState) {
    final playerIds = <String>{
      ..._players.map((player) => player.id),
      ...gameState.scores.keys,
    };

    final entries = playerIds.map((playerId) {
      final player = _playerById(playerId);
      return _LeaderboardEntry(
        name: player?.name ?? 'Player',
        score: gameState.scores[playerId] ?? player?.score ?? 0,
      );
    }).toList();

    entries.sort((a, b) => b.score.compareTo(a.score));
    return entries;
  }

  Widget _buildSelectableChip({
    required String label,
    required Color color,
    required bool isAvailable,
    required int value,
    bool isSelected = false,
    bool isScoreChip = false,
    double size = 34,
  }) {
    final chip = PokerChip(
      label: label,
      color: color,
      size: size,
      isScoreChip: isScoreChip,
    );

    Widget content = chip;
    if (!isAvailable) {
      content = Opacity(opacity: 0.2, child: chip);
    }

    return GestureDetector(
      onTap: () async {
        ref.read(audioServiceProvider).playChip();
        if (_selectedBetId != null) {
          await _removeSelectedBet();
          return;
        }
        if (!isAvailable) return;
        setState(() {
          _selectedChipValue = value;
          _selectedBetId = null;
        });
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: isSelected ? 1.14 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: AppColors.brassLight.withValues(alpha: 0.72),
                  blurRadius: 18,
                  spreadRadius: 3,
                ),
            ],
          ),
          child: content,
        ),
      ),
    );
  }

  Widget _buildPortraitLogo({bool allowWebPromo = true}) {
    if (kIsWeb && allowWebPromo) {
      return const RepaintBoundary(child: _WebPromoLogo());
    }
    return const RepaintBoundary(
      child: CachedAssetImage(AppAssetPaths.logo, fit: BoxFit.contain),
    );
  }

  Widget _buildRoundTimer(GameState gameState) {
    final isReveal = _isRevealPhase(gameState);
    final isParty = ref.read(currentRoomProvider)?.gameMode == GameMode.party;
    return Row(
      children: [
        Expanded(
          child: _InfoPill(
            icon: Icons.groups_rounded,
            label: 'Round ${gameState.currentRound}/${gameState.maxRounds}',
            isParty: isParty,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Consumer(
            builder: (context, ref, child) {
              final timerSeconds = ref.watch(gameTimerProvider);
              return _InfoPill(
                icon: isReveal
                    ? Icons.emoji_events_rounded
                    : Icons.timer_rounded,
                label: isReveal
                    ? 'RESULT'
                    : timerSeconds > 0
                    ? '0:${timerSeconds.toString().padLeft(2, '0')}'
                    : '--:--',
                isParty: isParty,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(BuildContext context, GameState gameState) {
    if (_isRevealPhase(gameState)) {
      return _buildAnswerRevealCard(gameState);
    }
    if (ref.read(currentRoomProvider)?.gameMode == GameMode.party) {
      return _buildPartyQuestionCard(gameState);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFBF1), Color(0xFFF6E7C9), Color(0xFFFFFCF4)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.ivory.withValues(alpha: 0.92),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brass.withValues(alpha: 0.24),
            blurRadius: 0,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.brass.withValues(alpha: 0.52),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.auto_awesome_rounded,
                size: 12,
                color: AppColors.felt,
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 3,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    ref.read(currentRoomProvider)?.gameMode == GameMode.party
                        ? 'PARTY CHALLENGE'
                        : 'QUESTION',
                    maxLines: 1,
                    style: GoogleFonts.outfit(
                      color: AppColors.felt,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.auto_awesome_rounded,
                size: 12,
                color: AppColors.felt,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.brass.withValues(alpha: 0.52),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: gameState.currentQuestion == null
                ? const _QuestionLoadingText(color: Color(0xFF0A2C59))
                : _AdaptiveQuestionText(
                    text: gameState.currentQuestion!.getText(locale: 'en'),
                    color: const Color(0xFF0A2C59),
                    minFontSize: 20,
                    maxFontSize: 34,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartyQuestionCard(GameState gameState) {
    final round = _partySnapshot?.round;
    final requiredItems = round?.challenge.requiredItems ?? const <String>[];
    final canReroll =
        round?.phase == PartyRoundPhase.betting &&
        ref.read(currentPlayerProvider)?.isHost == true;
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: PartyPalette.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: PartyPalette.orangeSoft.withValues(alpha: 0.32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: PartyPalette.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  round == null
                      ? 'PARTY CHALLENGE'
                      : '${round.performer.name.toUpperCase()} IS UP',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: PartyPalette.orangeSoft,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
              if (canReroll)
                Tooltip(
                  message: 'Different challenge',
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    color: PartyPalette.creamMuted,
                    onPressed: _isPartyCommandInFlight || round == null
                        ? null
                        : () => _runPartyCommand(
                            () => ref
                                .read(partyGameServiceProvider)
                                .rerollChallenge(_partySnapshot!.room.id),
                          ),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ),
            ],
          ),
          if (requiredItems.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              'NEEDS  ·  ${requiredItems.join('  +  ')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: PartyPalette.blueMuted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Expanded(
            child: gameState.currentQuestion == null
                ? const _QuestionLoadingText(color: PartyPalette.blueMuted)
                : _AdaptiveQuestionText(
                    text: gameState.currentQuestion!.getText(locale: 'en'),
                    color: PartyPalette.cream,
                    minFontSize: 20,
                    maxFontSize: 33,
                  ),
          ),
        ],
      ),
    );
    return _PartyAttentionFrame(
      key: ValueKey('party-question-${round?.number ?? 0}'),
      borderRadius: 20,
      child: card,
    );
  }

  Widget _buildAnswerRevealCard(GameState gameState) {
    final payout = _currentPlayerRoundPayout(gameState);
    final totalBets = _currentPlayerTotalBets(gameState);
    final netProfit = payout - totalBets;
    final didWin = netProfit > 0;
    final resultSettled = _showWinnerBadge;
    final answer = resultSettled
        ? gameState.correctAnswer ?? gameState.currentQuestion?.answer
        : null;
    final challenge = _partySnapshot?.round.challenge;
    final isBinary = challenge?.isBinary == true;
    final isAttempt = challenge?.isAttempt == true;
    final answerText = answer == null
        ? '--'
        : isBinary
        ? (answer == 1 ? 'SUCCESS' : 'FAILED')
        : isAttempt
        ? (answer == 0 ? "DOESN'T LAND" : 'ATTEMPT $answer')
        : _formatGuessValue(answer);
    final accent = didWin && resultSettled
        ? AppColors.chipGold
        : AppColors.brassLight;
    final banner = resultSettled
        ? (netProfit > 0
              ? 'YOU WON +$netProfit'
              : (netProfit < 0 ? 'YOU LOST -${netProfit.abs()}' : 'BREAK EVEN'))
        : 'LOCKING WINNING RANGE';
    final headlineColor = didWin && resultSettled
        ? AppColors.mahoganyDark
        : Colors.white;

    return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: didWin && resultSettled
                  ? const [
                      Color(0xFFFFF8D4),
                      Color(0xFFFFC833),
                      Color(0xFFFFF5B8),
                    ]
                  : const [
                      Color(0xFF13040A),
                      Color(0xFF5B0F1A),
                      Color(0xFF23060B),
                    ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: didWin && resultSettled
                  ? Colors.white
                  : AppColors.brassLight,
              width: didWin && resultSettled ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: resultSettled ? 0.46 : 0.28),
                blurRadius: resultSettled ? 28 : 18,
                spreadRadius: resultSettled ? 2 : 0,
              ),
              if (!resultSettled)
                BoxShadow(
                  color: AppColors.burgundy.withValues(alpha: 0.38),
                  blurRadius: 24,
                  spreadRadius: -3,
                  offset: const Offset(0, 8),
                ),
              BoxShadow(
                color: Colors.white.withValues(
                  alpha: didWin && resultSettled ? 0.34 : 0.08,
                ),
                blurRadius: 10,
                spreadRadius: -4,
                offset: const Offset(-3, -3),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.34),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                isBinary || isAttempt ? 'RESULT' : 'ANSWER',
                maxLines: 1,
                style: GoogleFonts.outfit(
                  color: didWin && resultSettled
                      ? AppColors.mahoganyDark.withValues(alpha: 0.72)
                      : AppColors.brassLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                            width: 108,
                            height: 108,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  accent.withValues(alpha: 0.34),
                                  accent.withValues(alpha: 0.03),
                                ],
                              ),
                            ),
                          )
                          .animate(target: resultSettled ? 1 : 0)
                          .scale(
                            begin: const Offset(0.92, 0.92),
                            end: const Offset(1.12, 1.12),
                            duration: 420.ms,
                            curve: Curves.easeOutCubic,
                          ),
                      FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              answerText,
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: 'RehnCondensed',
                                color: headlineColor,
                                fontSize: isBinary || isAttempt ? 54 : 76,
                                fontWeight: FontWeight.w900,
                                height: 0.86,
                                letterSpacing: 0,
                                shadows: [
                                  Shadow(
                                    color: didWin && resultSettled
                                        ? Colors.white.withValues(alpha: 0.9)
                                        : Colors.black,
                                    blurRadius: didWin && resultSettled
                                        ? 6
                                        : 10,
                                    offset: const Offset(0, 3),
                                  ),
                                  if (didWin && resultSettled)
                                    const Shadow(
                                      color: Color(0xFFFFF1A0),
                                      blurRadius: 20,
                                    ),
                                  if (!resultSettled)
                                    Shadow(
                                      color: AppColors.brassLight.withValues(
                                        alpha: 0.42,
                                      ),
                                      blurRadius: 18,
                                    ),
                                ],
                              ),
                            ),
                          )
                          .animate(target: resultSettled ? 1 : 0)
                          .shake(duration: 420.ms, hz: 5),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: didWin && resultSettled
                      ? Colors.white.withValues(alpha: 0.58)
                      : Colors.black.withValues(alpha: 0.26),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: didWin && resultSettled
                        ? AppColors.mahoganyDark.withValues(alpha: 0.26)
                        : AppColors.brassLight.withValues(alpha: 0.52),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    banner,
                    maxLines: 1,
                    style: GoogleFonts.outfit(
                      color: didWin && resultSettled
                          ? AppColors.mahoganyDark
                          : Colors.white,
                      fontSize: resultSettled ? 18 : 14,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: resultSettled ? 0 : 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        )
        .animate(
          key: ValueKey('answer-${gameState.correctAnswer}-$_revealSequenceId'),
        )
        .fadeIn(duration: 180.ms)
        .scale(begin: const Offset(0.97, 0.97), duration: 260.ms);
  }

  Widget _buildChipPicker(Player? currentPlayer, GameState gameState) {
    final partyRound = _partySnapshot?.round;
    final isParty = ref.read(currentRoomProvider)?.gameMode == GameMode.party;
    if (isParty &&
        gameState.phase == RoundPhase.betting &&
        currentPlayer?.id == partyRound?.performer.id) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: PartyPalette.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: PartyPalette.orangeSoft.withValues(alpha: 0.26),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.sports_gymnastics_rounded,
              color: PartyPalette.orangeSoft,
              size: 23,
            ),
            const SizedBox(height: 3),
            Text(
              'FRIENDS ARE BETTING',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: AppColors.ivory,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              'Your performance starts after the betting timer.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: AppColors.ivory.withValues(alpha: 0.62),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ],
        ),
      );
    }

    final myBets = currentPlayer == null
        ? const <Bet>[]
        : gameState.bets
              .where((bet) => bet.playerId == currentPlayer.id)
              .toList();
    final totalOnTable = myBets.fold<int>(0, (sum, bet) => sum + bet.chips);
    final totalChips = currentPlayer == null
        ? 0
        : gameState.scores[currentPlayer.id] ??
              (currentPlayer.score > 0
                  ? currentPlayer.score
                  : GameConstants.startingScore);
    final availableChips = max(0, totalChips - totalOnTable);
    final bankLabel = '$availableChips';
    final selectedBet = _selectedBet(gameState);

    return LayoutBuilder(
      builder: (context, constraints) {
        final chipSize = 42.0;
        final dynamicChips = _getDynamicChips(totalChips);
        final chipValues = dynamicChips
            .map(
              (val) => (
                label: val.toString(),
                value: val,
                color: _getChipColor(val),
              ),
            )
            .toList();

        final canEdit = _canCurrentPlayerEditBets(gameState);
        final pickerTitle = !canEdit
            ? 'CHIPS LOCKED'
            : selectedBet != null
            ? 'TAP CHIP TO RECALL'
            : _selectedChipValue == null
            ? 'SELECT A CHIP'
            : 'TAP A BET AREA';

        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: isParty
                ? PartyPalette.surface.withValues(alpha: 0.88)
                : selectedBet != null
                ? AppColors.feltDark.withValues(alpha: 0.24)
                : Colors.transparent,
            border: Border.all(
              color: isParty
                  ? (selectedBet != null
                        ? PartyPalette.orangeSoft.withValues(alpha: 0.58)
                        : Colors.white.withValues(alpha: 0.07))
                  : selectedBet != null
                  ? AppColors.brassLight
                  : Colors.transparent,
              width: 1.2,
            ),
            boxShadow: [
              if (selectedBet != null)
                BoxShadow(
                  color: (isParty ? PartyPalette.orange : AppColors.brassLight)
                      .withValues(alpha: 0.18),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: AppColors.brassLight.withValues(alpha: 0.52),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    pickerTitle,
                    style: GoogleFonts.outfit(
                      color: AppColors.ivory.withValues(alpha: 0.78),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: AppColors.brassLight.withValues(alpha: 0.52),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    if (selectedBet != null && _selectedBetId != null) {
                      ref.read(audioServiceProvider).playChip();
                      await _removeSelectedBet();
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final chip in chipValues)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 7),
                          child: _buildSelectableChip(
                            label: chip.label,
                            color: chip.color,
                            isAvailable:
                                canEdit && availableChips >= chip.value,
                            value: chip.value,
                            isSelected: selectedBet != null
                                ? chip.value == selectedBet.chips
                                : _selectedChipValue == chip.value,
                            size: chipSize,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 26,
                child: Row(
                  children: [
                    Expanded(child: _buildChipStatPill('BANK', bankLabel)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildChipStatPill('ON TABLE', '$totalOnTable'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChipStatPill(String label, String value) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.brassLight.withValues(alpha: 0.28),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: AppColors.ivory.withValues(alpha: 0.72),
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.fade,
              style: GoogleFonts.outfit(
                color: AppColors.brassLight,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuessingScreen(GameState gameState) {
    final hasSubmitted = gameState.hasSubmittedGuess;
    final canInput =
        gameState.phase == RoundPhase.guessing &&
        gameState.currentQuestion != null;
    final canSubmit =
        canInput &&
        _guessInput.isNotEmpty &&
        !hasSubmitted &&
        !_isSubmittingGuess;

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
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final contentWidth = constraints.maxWidth
                          .clamp(0.0, 560.0)
                          .toDouble();
                      final designHeight = constraints.maxHeight
                          .clamp(650.0, 810.0)
                          .toDouble();
                      final isCompact = constraints.maxHeight < 720;
                      final tightGap = isCompact ? 6.0 : 8.0;
                      final normalGap = isCompact ? 8.0 : 12.0;

                      return Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: contentWidth,
                            height: designHeight,
                            child: Column(
                              children: [
                                Expanded(
                                  flex: isCompact ? 10 : 12,
                                  child: _buildPortraitLogo(
                                    allowWebPromo: false,
                                  ),
                                ),
                                SizedBox(height: tightGap),
                                SizedBox(
                                  height: isCompact ? 42 : 46,
                                  child: _buildRoundTimer(gameState),
                                ),
                                SizedBox(height: normalGap),
                                Expanded(
                                  flex: isCompact ? 31 : 29,
                                  child: _buildGuessQuestionCard(gameState),
                                ),
                                SizedBox(height: normalGap),
                                _buildGuessSectionTitle(),
                                SizedBox(height: tightGap),
                                _buildGuessDisplay(gameState),
                                SizedBox(height: isCompact ? 8 : 10),
                                Expanded(
                                  flex: isCompact ? 40 : 38,
                                  child: _buildGuessNumpad(
                                    canInput: canInput,
                                    hasSubmitted: hasSubmitted,
                                  ),
                                ),
                                SizedBox(height: isCompact ? 8 : 10),
                                SizedBox(
                                  height: isCompact ? 54 : 58,
                                  child: _buildSubmitGuessButton(
                                    canSubmit: canSubmit,
                                    hasSubmitted: hasSubmitted,
                                  ),
                                ),
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
            if (gameState.phase == RoundPhase.question)
              Positioned.fill(child: _buildRoundTransitionOverlay(gameState)),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundTransitionOverlay(GameState gameState) {
    final content = IgnorePointer(
      child: ColoredBox(
        color: AppColors.feltDark.withValues(alpha: 0.97),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.brassLight,
                      size: 28,
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'ROUND',
                      style: GoogleFonts.outfit(
                        color: AppColors.ivory.withValues(alpha: 0.72),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${gameState.currentRound}',
                        maxLines: 1,
                        style: const TextStyle(
                          fontFamily: 'RehnCondensed',
                          color: AppColors.brassLight,
                          fontSize: 108,
                          fontWeight: FontWeight.w900,
                          height: 0.9,
                          letterSpacing: 0,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: AppColors.brassLight.withValues(alpha: 0.35),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'NEXT QUESTION',
                          style: GoogleFonts.outfit(
                            color: AppColors.ivory,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: AppColors.brassLight.withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${gameState.currentRound} / ${gameState.maxRounds}',
                      style: GoogleFonts.outfit(
                        color: AppColors.brassLight.withValues(alpha: 0.72),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (MediaQuery.disableAnimationsOf(context)) return content;
    return content
        .animate(key: ValueKey('round-transition-${gameState.currentRound}'))
        .fadeIn(duration: 260.ms, curve: Curves.easeOut)
        .scale(
          begin: const Offset(0.96, 0.96),
          end: const Offset(1, 1),
          duration: 520.ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildGuessQuestionCard(GameState gameState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFBF1), Color(0xFFF4E0B4), Color(0xFFFFFCF4)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: AppColors.brassLight.withValues(alpha: 0.78),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
          BoxShadow(
            color: AppColors.brassLight.withValues(alpha: 0.22),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.brass.withValues(alpha: 0.52),
                ),
              ),
              const SizedBox(width: 9),
              const Icon(
                Icons.auto_awesome_rounded,
                size: 13,
                color: AppColors.brass,
              ),
              const SizedBox(width: 9),
              Text(
                'QUESTION',
                style: GoogleFonts.outfit(
                  color: AppColors.felt,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  height: 1,
                ),
              ),
              const SizedBox(width: 9),
              const Icon(
                Icons.auto_awesome_rounded,
                size: 13,
                color: AppColors.brass,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.brass.withValues(alpha: 0.52),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: gameState.currentQuestion == null
                ? const _QuestionLoadingText(color: AppColors.feltDark)
                : Column(
                    children: [
                      Expanded(
                        child: _AdaptiveQuestionText(
                          text: gameState.currentQuestion!.getText(
                            locale: 'en',
                          ),
                          color: AppColors.feltDark,
                          minFontSize: 22,
                          maxFontSize: 46,
                        ),
                      ),
                      if (ref.read(currentRoomProvider)?.gameMode ==
                              GameMode.party &&
                          gameState.currentQuestion?.source != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          gameState.currentQuestion!.source!,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: AppColors.mahoganyDark.withValues(
                              alpha: 0.76,
                            ),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuessSectionTitle() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.brassLight.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(width: 10),
        const Icon(
          Icons.auto_awesome_rounded,
          size: 13,
          color: AppColors.brassLight,
        ),
        const SizedBox(width: 10),
        Text(
          'YOUR GUESS',
          style: GoogleFonts.outfit(
            color: AppColors.brassLight,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            height: 1,
          ),
        ),
        const SizedBox(width: 10),
        const Icon(
          Icons.auto_awesome_rounded,
          size: 13,
          color: AppColors.brassLight,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.brassLight.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }

  Widget _buildRoundLeaderboardScreen(GameState gameState) {
    final entries = _leaderboardEntries(gameState);
    final isHost = ref.watch(isHostProvider);
    Guess? winningGuess;
    for (final guess in gameState.sortedGuesses) {
      if (guess.id == gameState.winningGuessId) {
        winningGuess = guess;
        break;
      }
    }

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
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isPortrait =
                          constraints.maxHeight > constraints.maxWidth;
                      final header = _buildRoundResultHero(
                        gameState,
                        winningGuess,
                      );
                      final board = _buildRoundLeaderboardList(entries);

                      if (isPortrait) {
                        return Column(
                          children: [
                            _buildRoundResultHeader(gameState),
                            const SizedBox(height: 8),
                            header,
                            const SizedBox(height: 10),
                            Expanded(child: board),
                            const SizedBox(height: 10),
                            _buildRoundLeaderboardAction(gameState, isHost),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 44,
                            child: Column(
                              children: [
                                Expanded(
                                  flex: 34,
                                  child: _buildRoundResultHeader(gameState),
                                ),
                                const SizedBox(height: 12),
                                header,
                                const SizedBox(height: 12),
                                _buildRoundLeaderboardAction(gameState, isHost),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(flex: 56, child: board),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundResultHero(GameState gameState, Guess? winningGuess) {
    final answer = gameState.correctAnswer;
    final winnerName = winningGuess?.playerName ?? 'Player';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.feltDark.withValues(alpha: 0.96),
            AppColors.felt.withValues(alpha: 0.84),
            AppColors.feltDark.withValues(alpha: 0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
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
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFE58A),
                  Color(0xFFFFB91F),
                  Color(0xFFD88700),
                ],
              ),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: AppColors.ivory.withValues(alpha: 0.72),
                width: 1.2,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, color: AppColors.ink, size: 17),
                SizedBox(width: 7),
                Text(
                  'ROUND WINNER',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                SizedBox(width: 7),
                Icon(Icons.star_rounded, color: AppColors.ink, size: 17),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                winningGuess == null ? 'No winning guess' : winnerName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: AppColors.ivory,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1,
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
              const SizedBox(height: 8),
              Text(
                winningGuess == null
                    ? 'Waiting for scores'
                    : 'Guess ${_formatGuessInput('${winningGuess.value}')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: AppColors.brassLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'ANSWER',
                    style: GoogleFonts.outfit(
                      color: AppColors.ivory.withValues(alpha: 0.78),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: AppColors.brassLight.withValues(alpha: 0.46),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  answer == null ? '--' : _formatGuessInput('$answer'),
                  maxLines: 1,
                  style: const TextStyle(
                    fontFamily: 'RehnCondensed',
                    color: AppColors.brassLight,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    height: 0.9,
                    letterSpacing: 0,
                    shadows: [
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
        ],
      ),
    );
  }

  Widget _buildRoundResultHeader(GameState gameState) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 78, child: _buildPortraitLogo()),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1.5,
                color: AppColors.brassLight.withValues(alpha: 0.44),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.brassLight,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              gameState.currentRound >= gameState.maxRounds
                  ? 'GAME OVER!'
                  : 'ROUND OVER!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'RehnCondensed',
                color: AppColors.brassLight,
                fontSize: 34,
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
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 1.5,
                color: AppColors.brassLight.withValues(alpha: 0.44),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          'Round ${gameState.currentRound} results',
          style: GoogleFonts.outfit(
            color: AppColors.ivory,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            height: 1,
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

  Widget _buildRoundLeaderboardList(List<_LeaderboardEntry> entries) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.feltDark.withValues(alpha: 0.94),
            AppColors.felt.withValues(alpha: 0.88),
            AppColors.feltDark.withValues(alpha: 0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.brassLight.withValues(alpha: 0.28),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.36),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: AppColors.brassLight,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'LEADERBOARD',
                style: GoogleFonts.outfit(
                  color: AppColors.ivory,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                '${entries.length} PLAYERS',
                style: GoogleFonts.outfit(
                  color: AppColors.brassLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      'Scores will appear here.',
                      style: GoogleFonts.outfit(
                        color: AppColors.ivory.withValues(alpha: 0.74),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _buildRoundLeaderboardRow(entries[index], index),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundLeaderboardRow(_LeaderboardEntry entry, int index) {
    final isPodium = index < 3;
    final rankColor = switch (index) {
      0 => AppColors.brassLight,
      1 => AppColors.chipSilver,
      2 => AppColors.neonOrange,
      _ => AppColors.ivory.withValues(alpha: 0.68),
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isPodium
            ? AppColors.ivory.withValues(alpha: 0.94)
            : Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPodium
              ? rankColor.withValues(alpha: 0.72)
              : Colors.white.withValues(alpha: 0.08),
          width: isPodium ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              '#${index + 1}',
              style: GoogleFonts.outfit(
                color: isPodium ? AppColors.ink : rankColor,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: 0,
              ),
            ),
          ),
          Expanded(
            child: Text(
              entry.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: isPodium ? AppColors.ink : AppColors.ivory,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 1.05,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 88,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '${entry.score}',
                maxLines: 1,
                style: GoogleFonts.outfit(
                  color: isPodium ? AppColors.mahogany : AppColors.brassLight,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundLeaderboardAction(GameState gameState, bool isHost) {
    final isLastRound = gameState.currentRound >= gameState.maxRounds;

    return SizedBox(
      width: double.infinity,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isHost
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFE58A),
                    Color(0xFFFFB91F),
                    Color(0xFFD88700),
                  ],
                )
              : LinearGradient(
                  colors: [
                    AppColors.feltDark.withValues(alpha: 0.86),
                    AppColors.felt.withValues(alpha: 0.72),
                  ],
                ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.ivory.withValues(alpha: isHost ? 0.88 : 0.28),
            width: 1.6,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: isHost
                ? () {
                    _playButtonFeedback();
                    unawaited(_nextRound());
                  }
                : null,
            child: Center(
              child: Text(
                isHost
                    ? (isLastRound ? 'FINAL RESULTS' : 'NEXT ROUND')
                    : 'WAITING FOR HOST',
                style: GoogleFonts.outfit(
                  color: isHost ? AppColors.ink : AppColors.ivory,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuessDisplay(GameState gameState) {
    final hasSubmitted = gameState.hasSubmittedGuess;
    final display = switch ((
      hasSubmitted,
      gameState.currentQuestion == null,
      _guessInput.isEmpty,
    )) {
      (true, _, _) => 'LOCKED',
      (_, true, _) => 'WAITING FOR QUESTION',
      (_, _, true) => 'ENTER YOUR GUESS',
      _ => _formatGuessInput(_guessInput),
    };

    return Container(
      width: double.infinity,
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF042F1E), Color(0xFF062817), Color(0xFF01170E)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.brassLight.withValues(alpha: 0.86),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 15,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: AppColors.brassLight.withValues(alpha: 0.22),
            blurRadius: 12,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                display,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'RehnCondensed',
                  color: hasSubmitted ? AppColors.neonGreen : AppColors.ivory,
                  fontSize: _guessInput.isEmpty || hasSubmitted ? 34 : 58,
                  fontWeight: FontWeight.w900,
                  height: 0.95,
                  letterSpacing: 0,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.62),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              if (!hasSubmitted &&
                  gameState.currentQuestion != null &&
                  _guessInput.isNotEmpty)
                Container(
                  width: 2,
                  height: 48,
                  margin: const EdgeInsets.only(left: 7),
                  color: AppColors.brassLight,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuessNumpad({
    required bool canInput,
    required bool hasSubmitted,
  }) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', 'BACK'],
    ];

    return Column(
      children: [
        for (final row in rows)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  for (final key in row) ...[
                    Expanded(
                      child: _buildNumpadKey(
                        key,
                        disabled:
                            !canInput || hasSubmitted || _isSubmittingGuess,
                      ),
                    ),
                    if (key != row.last) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNumpadKey(String key, {required bool disabled}) {
    final isBack = key == 'BACK';
    final isClear = key == 'C';
    final radius = BorderRadius.circular(11);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: disabled ? 0.56 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF6C6),
              Color(0xFFC47A12),
              Color(0xFFFFE48B),
              Color(0xFF8D520B),
            ],
            stops: [0.0, 0.36, 0.68, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 9,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: AppColors.brassLight.withValues(alpha: 0.18),
              blurRadius: 7,
              spreadRadius: -1,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(2.4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: const Color(0xFF5E3509),
            ),
            child: Padding(
              padding: const EdgeInsets.all(1.2),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7.5),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isBack
                        ? const [
                            Color(0xFF0C6D41),
                            Color(0xFF073D27),
                            Color(0xFF021B11),
                          ]
                        : const [
                            Color(0xFFFFFFF6),
                            Color(0xFFF8E5B8),
                            Color(0xFFE9BF69),
                            Color(0xFFFFF9E6),
                          ],
                    stops: isBack
                        ? const [0.0, 0.62, 1.0]
                        : const [0.0, 0.46, 0.82, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(
                        alpha: isBack ? 0.06 : 0.54,
                      ),
                      blurRadius: 5,
                      offset: const Offset(-1, -1),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isBack ? 0.24 : 0.12,
                      ),
                      blurRadius: 6,
                      offset: const Offset(1, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(7.5),
                    onTap: disabled
                        ? null
                        : () {
                            if (isBack) {
                              _backspaceGuessDigit();
                            } else if (isClear) {
                              _clearGuessInput();
                            } else {
                              _appendGuessDigit(key);
                            }
                          },
                    child: Stack(
                      children: [
                        Positioned(
                          left: 9,
                          right: 9,
                          top: 6,
                          child: Container(
                            height: 1,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(
                                alpha: isBack ? 0.16 : 0.64,
                              ),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        Center(
                          child: isBack
                              ? const Icon(
                                  Icons.backspace_outlined,
                                  color: AppColors.brassLight,
                                  size: 25,
                                )
                              : Text(
                                  key,
                                  style: TextStyle(
                                    fontFamily: 'RehnCondensed',
                                    color: AppColors.feltDark,
                                    fontSize: 40,
                                    fontWeight: FontWeight.w900,
                                    height: 0.86,
                                    letterSpacing: 0,
                                    shadows: [
                                      Shadow(
                                        color: Colors.white.withValues(
                                          alpha: 0.78,
                                        ),
                                        blurRadius: 1.5,
                                        offset: const Offset(0, 1),
                                      ),
                                      Shadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.14,
                                        ),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1.4),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitGuessButton({
    required bool canSubmit,
    required bool hasSubmitted,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF6C6),
            Color(0xFFC47A12),
            Color(0xFFFFE48B),
            Color(0xFF8D520B),
          ],
          stops: [0.0, 0.34, 0.72, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: AppColors.brassLight.withValues(
              alpha: canSubmit ? 0.32 : 0.12,
            ),
            blurRadius: 14,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            gradient: hasSubmitted
                ? const LinearGradient(
                    colors: [Color(0xFF72E66F), Color(0xFF1F8D44)],
                  )
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFFF0A8),
                      Color(0xFFFFC42E),
                      Color(0xFFD88700),
                      Color(0xFFFFD867),
                    ],
                    stops: [0.0, 0.44, 0.78, 1.0],
                  ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.26),
                blurRadius: 5,
                offset: const Offset(-1, -1),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(21),
              onTap: canSubmit ? _submitNumpadGuess : null,
              child: Stack(
                children: [
                  Positioned(
                    left: 24,
                    right: 24,
                    top: 7,
                    child: Container(
                      height: 1.3,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.mahoganyDark,
                          size: 21,
                        ),
                        const SizedBox(width: 14),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              hasSubmitted
                                  ? 'GUESS SENT'
                                  : _isSubmittingGuess
                                  ? 'SENDING...'
                                  : 'SUBMIT GUESS',
                              maxLines: 1,
                              style: const TextStyle(
                                fontFamily: 'RehnCondensed',
                                color: AppColors.feltDark,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                height: 0.9,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.mahoganyDark,
                          size: 21,
                        ),
                      ],
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

  String _formatGuessInput(String input) {
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final remaining = input.length - i;
      buffer.write(input[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
    }
    return buffer.toString();
  }

  Widget _buildPlayersStrip(GameState gameState) {
    if (ref.read(currentRoomProvider)?.gameMode == GameMode.party) {
      return _buildPartyPlayersStrip(gameState);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.feltDark.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.brass.withValues(alpha: 0.42),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.brassLight.withValues(alpha: 0.34),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'LEADERBOARD',
                style: GoogleFonts.outfit(
                  color: AppColors.ivory.withValues(alpha: 0.78),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  height: 1,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'BANK',
                style: GoogleFonts.outfit(
                  color: AppColors.brassLight.withValues(alpha: 0.72),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.brassLight.withValues(alpha: 0.34),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (_players.isEmpty) {
                  return Center(
                    child: Text(
                      'Waiting',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  );
                }

                final sortedPlayers = [..._players]
                  ..sort((a, b) {
                    final scoreA = gameState.scores[a.id] ?? a.score;
                    final scoreB = gameState.scores[b.id] ?? b.score;
                    return scoreB.compareTo(scoreA);
                  });
                final visiblePlayers = sortedPlayers.take(3).toList();

                return Column(
                  children: [
                    const SizedBox(height: 6),
                    for (var index = 0; index < visiblePlayers.length; index++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: index == visiblePlayers.length - 1 ? 0 : 5,
                          ),
                          child: _buildPlayerLeaderboardRow(
                            visiblePlayers[index],
                            index,
                            gameState.scores[visiblePlayers[index].id] ??
                                visiblePlayers[index].score,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartyPlayersStrip(GameState gameState) {
    final sortedPlayers = [..._players]
      ..sort((a, b) {
        final scoreA = gameState.scores[a.id] ?? a.score;
        final scoreB = gameState.scores[b.id] ?? b.score;
        return scoreB.compareTo(scoreA);
      });
    final visiblePlayers = sortedPlayers.take(3).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: PartyPalette.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PartyPalette.cream.withValues(alpha: 0.09)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'THE ROOM',
                style: GoogleFonts.outfit(
                  color: PartyPalette.creamMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                'CHIPS',
                style: GoogleFonts.outfit(
                  color: PartyPalette.orangeSoft,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Expanded(
            child: Column(
              children: [
                for (var index = 0; index < visiblePlayers.length; index++)
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(
                        bottom: index == visiblePlayers.length - 1 ? 0 : 5,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: index == 0
                            ? PartyPalette.orange.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.035),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: index == 0
                              ? PartyPalette.orangeSoft.withValues(alpha: 0.24)
                              : Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${index + 1}',
                            style: GoogleFonts.outfit(
                              color: index == 0
                                  ? PartyPalette.orangeSoft
                                  : PartyPalette.blueMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              visiblePlayers[index].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                color: PartyPalette.cream,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${gameState.scores[visiblePlayers[index].id] ?? visiblePlayers[index].score}',
                            style: GoogleFonts.outfit(
                              color: PartyPalette.orangeSoft,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerLeaderboardRow(Player player, int index, int score) {
    final isWinner = _roundWinners.contains(player.id);
    final isLeader = index == 0;
    final payout = _roundPayouts[player.id] ?? 0;

    Widget row = AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: isWinner
            ? AppColors.neonGreen.withValues(alpha: 0.16)
            : isLeader
            ? AppColors.brassLight.withValues(alpha: 0.13)
            : Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isWinner
              ? AppColors.neonGreen.withValues(alpha: 0.62)
              : isLeader
              ? AppColors.brassLight.withValues(alpha: 0.42)
              : Colors.white.withValues(alpha: 0.08),
          width: isWinner ? 1.3 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '#${index + 1}',
              style: GoogleFonts.outfit(
                color: isLeader ? AppColors.brassLight : AppColors.ivory,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: AppColors.ivory,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (payout > 0) ...[
            DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.neonGreen.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.neonGreen.withValues(alpha: 0.58),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    child: Text(
                      '+$payout',
                      maxLines: 1,
                      style: GoogleFonts.outfit(
                        color: AppColors.neonGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                )
                .animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                )
                .scale(
                  end: const Offset(1.08, 1.08),
                  duration: 460.ms,
                  curve: Curves.easeInOut,
                ),
            const SizedBox(width: 7),
          ],
          Text(
            '$score',
            maxLines: 1,
            style: GoogleFonts.outfit(
              color: isWinner ? AppColors.neonGreen : AppColors.brassLight,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: 0,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.48),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return row;
  }

  List<int> _getDynamicChips(int bank) {
    if (bank < 20) return const [1, 5, 10];
    if (bank < 50) return const [5, 10, 25];
    if (bank <= 150) return const [5, 10, 50];
    if (bank <= 350) return const [10, 50, 100];
    if (bank <= 1000) return const [50, 100, 500];
    return const [100, 500, 1000];
  }

  Color _getChipColor(int value) {
    if (ref.read(currentRoomProvider)?.gameMode == GameMode.party) {
      return switch (value) {
        1 => PartyPalette.plum,
        5 => PartyPalette.sage,
        10 => const Color(0xFF48657A),
        25 => PartyPalette.terracotta,
        50 => const Color(0xFF81516A),
        100 => const Color(0xFFB06F43),
        500 => PartyPalette.orange,
        1000 => PartyPalette.orangeSoft,
        _ => PartyPalette.orange,
      };
    }
    switch (value) {
      case 1:
        return AppColors.neonPink;
      case 5:
        return AppColors.feltLight;
      case 10:
        return AppColors.neonBlue;
      case 25:
        return AppColors.neonCyan;
      case 50:
        return AppColors.burgundy;
      case 100:
        return AppColors.neonPurple;
      case 500:
        return AppColors.chipGold;
      case 1000:
        return AppColors.brass;
      default:
        return AppColors.chipGold;
    }
  }

  Widget _buildBettingBoardAsset(GameState gameState, String? currentPlayerId) {
    final canEdit = _canCurrentPlayerEditBets(gameState);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final boundaryValues = _boardBoundaryValues(gameState);
        final challenge = _partySnapshot?.round.challenge;
        final isBinary = challenge?.isBinary == true;
        final isAttempt = challenge?.isAttempt == true;
        final isReveal = _isRevealPhase(gameState);
        final winningSlotIndex = isReveal
            ? _winningBetSlotIndex(gameState)
            : null;
        final activeSlots = isBinary
            ? _binaryBetSlots
            : isAttempt
            ? _attemptBetSlots
            : _betSlots;
        final orderedSlots = [
          ...activeSlots.where((slot) => !slot.isSweetSpot),
          ...activeSlots.where((slot) => slot.isSweetSpot),
        ];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: ValueListenableBuilder<int?>(
            valueListenable: _scanSlotIndexNotifier,
            builder: (context, activeRevealSlotIndex, _) {
              if (!isReveal) activeRevealSlotIndex = null;
              if (isReveal && activeRevealSlotIndex == null) {
                activeRevealSlotIndex = winningSlotIndex;
              }
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final spec in orderedSlots)
                    Positioned(
                      left: spec.rect.left * size.width,
                      top: spec.rect.top * size.height,
                      width: spec.rect.width * size.width,
                      height: spec.rect.height * size.height,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: canEdit
                            ? (details) => _handleBetSlotTap(
                                spec,
                                details.localPosition,
                                Size(
                                  spec.rect.width * size.width,
                                  spec.rect.height * size.height,
                                ),
                              )
                            : null,
                        child: _buildCodedBetSlot(
                          spec: spec,
                          isWinningReveal: activeRevealSlotIndex == spec.index,
                          boundaries: isBinary || isAttempt
                              ? const <int>[]
                              : boundaryValues,
                        ),
                      ),
                    ),
                  if (_showWinnerBadge && winningSlotIndex != null)
                    ..._buildWinParticles(size, winningSlotIndex),
                  if (!isBinary && !isAttempt)
                    ..._buildBoundaryLabels(boundaryValues, size),
                  if (!(_showWinnerBadge && winningSlotIndex != null))
                    _buildAllPlacedChips(
                      gameState.bets,
                      size,
                      currentPlayerId,
                      canEdit: canEdit,
                      isReveal: isReveal,
                      winningSlotIndex: winningSlotIndex,
                      emphasizeWinners: _showWinnerBadge,
                    ),
                  if (_showWinnerBadge && winningSlotIndex != null)
                    ..._buildPayoutFlightChips(
                      size,
                      winningSlotIndex,
                      gameState.bets,
                    ),
                  if (_showWinnerBadge && winningSlotIndex != null)
                    _buildWinnerOverlayCard(size, winningSlotIndex),
                ],
              );
            },
          ),
        );
      },
    );
  }

  List<int> _boardBoundaryValues(GameState gameState) {
    final partyBoundaries = _partySnapshot?.round.challenge.betBoundaries;
    if (partyBoundaries != null && partyBoundaries.length == 4) {
      return partyBoundaries;
    }
    return ref
        .read(gameServiceProvider)
        .boardBoundaryValues(gameState.sortedGuesses);
  }

  Future<void> _handleBetSlotTap(
    _BetSlotSpec spec,
    Offset localPosition,
    Size slotSize,
  ) async {
    if (_isBetOperationInFlight) return;

    final position = Offset(
      (localPosition.dx / slotSize.width).clamp(0.12, 0.88).toDouble(),
      (localPosition.dy / slotSize.height).clamp(0.18, 0.82).toDouble(),
    );

    final selectedBet = _selectedBet(ref.read(gameStateProvider));
    if (selectedBet != null) {
      await _moveBet(selectedBet, spec.index, position: position);
      return;
    }

    final selectedChip = _selectedChipValue;
    if (selectedChip == null) return;
    await _placeBet(spec.index, selectedChip, position: position);
  }

  Widget _buildCodedBetSlot({
    required _BetSlotSpec spec,
    required bool isWinningReveal,
    required List<int> boundaries,
  }) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 210),
      scale: isWinningReveal ? 1.026 : 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: _BetSlotSurface(
              spec: spec,
              isHovering: false,
              isWinningReveal: isWinningReveal,
              isPartyMode:
                  ref.read(currentRoomProvider)?.gameMode == GameMode.party,
            ),
          ),
          _buildBetSlotLabel(spec, boundaries),
        ],
      ),
    );
  }

  List<Widget> _buildWinParticles(Size boardSize, int winningSlotIndex) {
    final spec = _betSlotSpecFor(winningSlotIndex);
    if (spec == null) return const [];

    final center = Offset(
      (spec.rect.left + spec.rect.width * 0.5) * boardSize.width,
      (spec.rect.top + spec.rect.height * 0.5) * boardSize.height,
    );

    return [
      for (var i = 0; i < 12; i++)
        Positioned(
          left: center.dx + cos(i * pi / 6) * 12,
          top: center.dy + sin(i * pi / 6) * 8,
          child: IgnorePointer(
            child:
                Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i.isEven ? AppColors.brassLight : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.brassLight.withValues(alpha: 0.55),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    )
                    .animate(delay: (i * 35).ms)
                    .fadeOut(duration: 900.ms)
                    .move(
                      begin: Offset.zero,
                      end: Offset(cos(i * pi / 6) * 34, sin(i * pi / 6) * 26),
                      duration: 900.ms,
                      curve: Curves.easeOutCubic,
                    ),
          ),
        ),
    ];
  }

  List<Widget> _buildPayoutFlightChips(
    Size boardSize,
    int winningSlotIndex,
    List<Bet> bets,
  ) {
    final spec = _betSlotSpecFor(winningSlotIndex);
    if (spec == null) return const [];

    final winningBets = bets
        .where((bet) => bet.slotIndex == winningSlotIndex)
        .toList();
    if (winningBets.isEmpty) return const [];

    final odds = _partySnapshot?.round.challenge.isBinary == true
        ? 2
        : GameConstants.boardOdds[winningSlotIndex];
    final center = Offset(
      (spec.rect.left + spec.rect.width * 0.5) * boardSize.width,
      (spec.rect.top + spec.rect.height * 0.5) * boardSize.height,
    );
    final chipSize = (boardSize.width * 0.095).clamp(28.0, 36.0).toDouble();
    final payoutTokens = <({Bet bet, int token, int order})>[];
    var order = 0;

    for (final bet in winningBets) {
      final visualChipCount = min(odds, 4);
      for (var token = 0; token < visualChipCount && order < 18; token++) {
        payoutTokens.add((bet: bet, token: token, order: order));
        order++;
      }
      if (order >= 18) break;
    }

    return [
      for (final item in payoutTokens)
        _buildPayoutFlightChip(
          bet: item.bet,
          order: item.order,
          token: item.token,
          odds: odds,
          center: center,
          chipSize: chipSize,
          boardSize: boardSize,
        ),
    ];
  }

  Widget _buildPayoutFlightChip({
    required Bet bet,
    required int order,
    required int token,
    required int odds,
    required Offset center,
    required double chipSize,
    required Size boardSize,
  }) {
    final angle = -pi / 2 + order * 0.72;
    final radius = 14.0 + (order % 3) * 7.0;
    final start = center + Offset(cos(angle) * radius, sin(angle) * radius);
    final leaderboardTargetY = boardSize.height * 0.82;
    final flyOffset = Offset(
      -boardSize.width * 1.04 - (order % 4) * 12,
      leaderboardTargetY - start.dy + ((order % 5) - 2) * 5,
    );
    final delayMs = 150 + order * 42;
    final flightMs = 1040 + (order % 4) * 45;
    final duration = Duration(milliseconds: delayMs + flightMs);

    return Positioned(
      left: start.dx - chipSize / 2,
      top: start.dy - chipSize / 2,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          key: ValueKey('payout-flight-${bet.id}-$token-$odds'),
          tween: Tween<double>(begin: 0, end: 1),
          duration: duration,
          curve: Curves.linear,
          builder: (context, rawProgress, child) {
            final delayedProgress =
                ((rawProgress * duration.inMilliseconds) - delayMs) / flightMs;
            if (delayedProgress <= 0) {
              return const SizedBox.shrink();
            }
            final progress = delayedProgress.clamp(0.0, 1.0).toDouble();
            final launch = ((progress - 0.34) / 0.66).clamp(0.0, 1.0);
            final pop = (progress / 0.30).clamp(0.0, 1.0);
            final launchCurve = Curves.easeInOutCubic.transform(launch);
            final popCurve = Curves.easeOutBack.transform(pop).clamp(0.0, 1.12);
            final floatLift = sin(min(progress, 0.34) / 0.34 * pi) * -9;
            final opacity = launch < 0.78
                ? 1.0
                : (1 - ((launch - 0.78) / 0.22)).clamp(0.0, 1.0);
            final scale = launch == 0
                ? 0.66 + 0.39 * popCurve
                : (1.05 - 0.80 * Curves.easeInCubic.transform(launch)).clamp(
                    0.22,
                    1.08,
                  );

            return Opacity(
              opacity: opacity.toDouble(),
              child: Transform.translate(
                offset: Offset(
                  flyOffset.dx * launchCurve,
                  floatLift + flyOffset.dy * launchCurve,
                ),
                child: Transform.scale(scale: scale.toDouble(), child: child),
              ),
            );
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.brassLight.withValues(alpha: 0.42),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: PokerChip(
              label: '${bet.chips}',
              color: _getChipColor(bet.chips),
              size: chipSize,
              isScoreChip: false,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBoundaryLabels(List<int> boundaryValues, Size boardSize) {
    if (boundaryValues.length < GameConstants.maxGuessSlots) return const [];

    final labelsTopToBottom = boundaryValues.reversed.toList();
    const boundaryY = [0.209, 0.400, 0.599, 0.790];

    return [
      for (var i = 0; i < labelsTopToBottom.length; i++)
        Positioned(
          left: boardSize.width * 0.030,
          top: boardSize.height * boundaryY[i] - 23,
          width: boardSize.width * 0.940,
          height: 46,
          child: IgnorePointer(
            child: _buildBoundaryNumber(labelsTopToBottom[i]),
          ),
        ),
    ];
  }

  Widget _buildBoundaryNumber(int value) {
    if (ref.read(currentRoomProvider)?.gameMode == GameMode.party) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(minWidth: 82),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
          decoration: BoxDecoration(
            color: PartyPalette.nightDeep.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: PartyPalette.orangeSoft.withValues(alpha: 0.42),
            ),
          ),
          child: Text(
            _formatGuessValue(value),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'RehnCondensed',
              color: PartyPalette.cream,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 0.9,
            ),
          ),
        ),
      );
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(child: _BoundaryRibbonBacking()),
        FractionallySizedBox(
          widthFactor: 0.56,
          heightFactor: 0.74,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFF8C9),
                  Color(0xFFFFD25A),
                  Color(0xFFC98116),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.38),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: AppColors.brassLight.withValues(alpha: 0.28),
                  blurRadius: 12,
                  spreadRadius: -3,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _formatGuessValue(value),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'RehnCondensed',
                    color: AppColors.ink,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 0.9,
                    letterSpacing: 0,
                    shadows: [
                      Shadow(
                        color: Colors.white70,
                        blurRadius: 1,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBetSlotLabel(_BetSlotSpec slot, List<int> boundaries) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(child: _buildCasinoSlotTitle(slot, boundaries)),
          Positioned(
            top: 0,
            right: slot.isSweetSpot ? 6 : 4,
            bottom: 0,
            width: slot.isSweetSpot ? 36 : 30,
            child: _buildOddsTicket(slot),
          ),
        ],
      ),
    );
  }

  String _formatGuessValue(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
  }

  Widget _buildOddsTicket(_BetSlotSpec slot) {
    final isSweetSpot = slot.isSweetSpot;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.centerRight,
          child: Opacity(
            opacity: isSweetSpot ? 0.50 : 0.42,
            child: RotatedBox(
              quarterTurns: 3,
              child: SizedBox(
                width: constraints.maxHeight * 0.72,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${slot.odds} TO 1',
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: isSweetSpot
                          ? AppColors.mahoganyDark
                          : Colors.white,
                      fontSize: isSweetSpot ? 11 : 10,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: 0,
                      shadows: [
                        Shadow(
                          color: isSweetSpot
                              ? Colors.white.withValues(alpha: 0.45)
                              : Colors.black.withValues(alpha: 0.70),
                          blurRadius: isSweetSpot ? 1 : 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPartySlotTitle(_BetSlotSpec slot, List<int> boundaries) {
    String range = '';
    if (boundaries.length >= 4) {
      range = switch (slot.index) {
        4 => '${boundaries[3]}+',
        3 => '${boundaries[2]} – ${boundaries[3]}',
        2 => '${boundaries[1]} – ${boundaries[2]}',
        1 => '${boundaries[0]} – ${boundaries[1]}',
        _ => 'UNDER ${boundaries[0]}',
      };
    }
    final mainText = slot.title.isNotEmpty ? slot.title : range;
    final detail = slot.title.isNotEmpty && range.isNotEmpty ? range : null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 42, 8),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mainText,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: PartyPalette.cream,
                  fontSize: slot.isSweetSpot ? 24 : 27,
                  fontWeight: FontWeight.w900,
                  height: 0.95,
                  letterSpacing: slot.title.length <= 3 ? 1.3 : 0.2,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: GoogleFonts.outfit(
                    color: PartyPalette.cream.withValues(alpha: 0.68),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCasinoSlotTitle(_BetSlotSpec slot, List<int> boundaries) {
    if (ref.read(currentRoomProvider)?.gameMode == GameMode.party) {
      return _buildPartySlotTitle(slot, boundaries);
    }
    final isSweetSpot = slot.isSweetSpot;
    final textColor = isSweetSpot ? AppColors.mahoganyDark : Colors.white;
    final strokeColor = isSweetSpot ? AppColors.brassLight : AppColors.feltDark;
    final fontSize = isSweetSpot ? 20.5 : 27.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (slot.title.isNotEmpty)
                    Text(
                      slot.title,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.rye(
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = isSweetSpot ? 2.6 : 3.2
                          ..color = strokeColor.withValues(
                            alpha: isSweetSpot ? 0.72 : 0.78,
                          ),
                        fontSize: fontSize,
                        fontWeight: FontWeight.w400,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
                  if (slot.index == 1 && boundaries.length >= 2)
                    Text(
                      'BETWEEN\n${boundaries[0]} & ${boundaries[1]}\n(INCLUSIVE)',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: AppColors.ivory.withValues(alpha: 0.35),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        letterSpacing: 1.8,
                      ),
                    ),
                  if (slot.index == 3 && boundaries.length >= 4)
                    Text(
                      'BETWEEN\n${boundaries[2]} & ${boundaries[3]}\n(INCLUSIVE)',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: AppColors.ivory.withValues(alpha: 0.35),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        letterSpacing: 1.8,
                      ),
                    ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (slot.title.isNotEmpty)
                    Text(
                      slot.title,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.rye(
                        color: textColor,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w400,
                        height: 1,
                        letterSpacing: 0,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(
                              alpha: isSweetSpot ? 0.28 : 0.75,
                            ),
                            blurRadius: isSweetSpot ? 2 : 7,
                            offset: const Offset(0, 2),
                          ),
                          if (isSweetSpot)
                            Shadow(
                              color: AppColors.brassLight.withValues(
                                alpha: 0.34,
                              ),
                              blurRadius: 9,
                            ),
                        ],
                      ),
                    ),
                  if (slot.index == 1 && boundaries.length >= 2)
                    Text(
                      'BETWEEN\n${boundaries[0]} & ${boundaries[1]}\n(INCLUSIVE)',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: AppColors.ivory.withValues(alpha: 0.35),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        letterSpacing: 1.8,
                      ),
                    ),
                  if (slot.index == 3 && boundaries.length >= 4)
                    Text(
                      'BETWEEN\n${boundaries[2]} & ${boundaries[3]}\n(INCLUSIVE)',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: AppColors.ivory.withValues(alpha: 0.35),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        letterSpacing: 1.8,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWinnerOverlayCard(Size boardSize, int winningSlotIndex) {
    final spec = _betSlotSpecFor(winningSlotIndex);
    if (spec == null) return const SizedBox.shrink();

    final winnerIds = _roundWinners;
    final winners = _players.where((p) => winnerIds.contains(p.id)).toList();

    return Positioned(
      left: spec.rect.left * boardSize.width,
      width: spec.rect.width * boardSize.width,
      top: spec.rect.top * boardSize.height,
      height: spec.rect.height * boardSize.height,
      child: Center(
        child:
            Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.ivory.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: AppColors.brassLight.withValues(alpha: 0.9),
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.65),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (winners.isEmpty)
                        Text(
                          'NOBODY WON',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: AppColors.mahoganyDark.withValues(
                              alpha: 0.8,
                            ),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        )
                      else
                        ...winners.map((player) {
                          final payout = _roundPayouts[player.id] ?? 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    player.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      color: AppColors.feltDark,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '+$payout',
                                  style: GoogleFonts.outfit(
                                    color: Colors.green.shade700,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                )
                .animate(delay: 1100.ms)
                .fadeIn(duration: 400.ms)
                .scale(
                  begin: const Offset(0.85, 0.85),
                  curve: Curves.easeOutBack,
                  duration: 500.ms,
                ),
      ),
    );
  }

  Widget _buildAllPlacedChips(
    List<Bet> bets,
    Size boardSize,
    String? currentPlayerId, {
    required bool canEdit,
    required bool isReveal,
    required int? winningSlotIndex,
    required bool emphasizeWinners,
  }) {
    if (bets.isEmpty) return const SizedBox.shrink();

    final myBets = bets
        .where((bet) => bet.playerId == currentPlayerId)
        .toList();
    final otherBets = bets
        .where((bet) => bet.playerId != currentPlayerId)
        .toList();
    // Use fixed physical chip size for all placed bets.
    final chipSize = 42.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (otherBets.isNotEmpty)
          _buildOtherBetMarkersGlobal(
            otherBets,
            boardSize,
            isReveal: isReveal,
            winningSlotIndex: winningSlotIndex,
            emphasizeWinners: emphasizeWinners,
          ),
        for (var i = 0; i < myBets.length; i++)
          _positionedBetChip(
            myBets[i],
            i,
            boardSize,
            chipSize,
            canEdit: canEdit,
            isSelected: _selectedBetId == myBets[i].id,
            onTap: canEdit ? () => _selectBetForMove(myBets[i]) : null,
            isReveal: isReveal,
            isWinningBet:
                emphasizeWinners && myBets[i].slotIndex == winningSlotIndex,
            resultSettled: emphasizeWinners,
          ),
      ],
    );
  }

  Widget _buildOtherBetMarkersGlobal(
    List<Bet> bets,
    Size boardSize, {
    required bool isReveal,
    required int? winningSlotIndex,
    required bool emphasizeWinners,
  }) {
    // For other bets, we just group them per slot and render them globally.
    // To keep things simple, we'll iterate through slots and position markers based on slot rects.
    final slotsWithBets = <int, List<Bet>>{};
    for (final bet in bets) {
      slotsWithBets.putIfAbsent(bet.slotIndex, () => []).add(bet);
    }

    return Stack(
      children: [
        for (final entry in slotsWithBets.entries)
          ..._buildOtherBetMarkersForSlot(
            entry.key,
            entry.value,
            boardSize,
            isReveal: isReveal,
            winningSlotIndex: winningSlotIndex,
            emphasizeWinners: emphasizeWinners,
          ),
      ],
    );
  }

  List<Widget> _buildOtherBetMarkersForSlot(
    int slotIndex,
    List<Bet> bets,
    Size boardSize, {
    required bool isReveal,
    required int? winningSlotIndex,
    required bool emphasizeWinners,
  }) {
    final spec = _betSlotSpecFor(slotIndex);
    if (spec == null) return const [];
    final slotSize = Size(
      spec.rect.width * boardSize.width,
      spec.rect.height * boardSize.height,
    );
    final visibleBets = bets.take(5).toList();
    if (visibleBets.isEmpty) return [];

    final chipSize = 42.0;
    final step = chipSize * 0.66;
    final rowWidth = chipSize + max(0, visibleBets.length - 1) * step;

    final localLeft = ((slotSize.width - rowWidth) / 2)
        .clamp(8.0, max(8.0, slotSize.width - rowWidth - 8))
        .toDouble();
    final localTop = (slotSize.height - chipSize - 8)
        .clamp(8.0, max(8.0, slotSize.height - chipSize - 8))
        .toDouble();

    return [
      for (var i = 0; i < visibleBets.length; i++)
        _buildOtherBetMarker(
          bet: visibleBets[i],
          index: i,
          chipSize: chipSize,
          left: spec.rect.left * boardSize.width + localLeft + i * step,
          top:
              spec.rect.top * boardSize.height +
              localTop +
              (i.isOdd ? chipSize * 0.10 : 0),
          boardWidth: boardSize.width,
          isReveal: isReveal,
          isWinningBet:
              emphasizeWinners && visibleBets[i].slotIndex == winningSlotIndex,
          resultSettled: emphasizeWinners,
        ),
    ];
  }

  Widget _buildOtherBetMarker({
    required Bet bet,
    required int index,
    required double chipSize,
    required double left,
    required double top,
    required double boardWidth,
    required bool isReveal,
    required bool isWinningBet,
    required bool resultSettled,
  }) {
    final shouldSlideIn =
        _incomingOtherBetIds.contains(bet.id) &&
        !_playedOtherBetEntryIds.contains(bet.id) &&
        !isReveal;
    if (shouldSlideIn) {
      _playedOtherBetEntryIds.add(bet.id);
      _incomingOtherBetIds.remove(bet.id);
    }

    final chip = _buildPlacedChipVisual(
      bet,
      chipSize,
      isReveal: isReveal,
      isWinningBet: isWinningBet,
      resultSettled: resultSettled,
    );
    final entryTravel = boardWidth + chipSize + index * 6;

    return Positioned(
      left: left,
      top: top,
      child: TweenAnimationBuilder<double>(
        key: ValueKey('other-bet-entry-${bet.id}'),
        tween: Tween<double>(begin: shouldSlideIn ? 1 : 0, end: 0),
        duration: shouldSlideIn
            ? Duration(milliseconds: 360 + index * 24)
            : Duration.zero,
        curve: Curves.easeOutCubic,
        child: chip,
        builder: (context, progress, child) {
          return Transform.translate(
            offset: Offset(entryTravel * progress, 0),
            child: Transform.scale(scale: 1 - (0.12 * progress), child: child),
          );
        },
      ),
    );
  }

  Widget _positionedBetChip(
    Bet bet,
    int index,
    Size boardSize,
    double chipSize, {
    required bool canEdit,
    required bool isSelected,
    VoidCallback? onTap,
    required bool isReveal,
    required bool isWinningBet,
    required bool resultSettled,
  }) {
    final fallbackX = 0.5 + ((index % 3) - 1) * 0.14;
    final fallbackY = 0.52 + ((index ~/ 3) % 2) * 0.16;
    final slotLocalX = bet.positionX ?? fallbackX;
    final slotLocalY = bet.positionY ?? fallbackY;

    final spec = _betSlotSpecFor(bet.slotIndex);
    if (spec == null) return const SizedBox.shrink();

    final slotWidth = spec.rect.width * boardSize.width;
    final slotHeight = spec.rect.height * boardSize.height;

    // No clamping so the chip stays physically exactly where dropped
    final globalLeft =
        spec.rect.left * boardSize.width +
        (slotLocalX * slotWidth - chipSize / 2);
    final globalTop =
        spec.rect.top * boardSize.height +
        (slotLocalY * slotHeight - chipSize / 2);

    final chip = _buildPlacedChipVisual(
      bet,
      chipSize,
      isReveal: isReveal,
      isWinningBet: isWinningBet,
      resultSettled: resultSettled,
    );

    final visual = AnimatedScale(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      scale: isSelected ? 1.15 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.brassLight.withValues(alpha: 0.95),
                blurRadius: 22,
                spreadRadius: 4,
              ),
          ],
        ),
        child: chip,
      ),
    );

    final child = GestureDetector(onTap: onTap, child: visual);

    return AnimatedPositioned(
      key: ValueKey(bet.id),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      left: globalLeft,
      top: globalTop,
      child: canEdit ? child : visual,
    );
  }

  Widget _buildPlacedChipVisual(
    Bet bet,
    double chipSize, {
    required bool isReveal,
    required bool isWinningBet,
    required bool resultSettled,
  }) {
    final currentPlayer = ref.read(currentPlayerProvider);
    final isMyChip = currentPlayer?.id == bet.playerId;

    Widget chip = PokerChip(
      label: '${bet.chips}',
      color: _getChipColor(bet.chips),
      size: chipSize,
      isScoreChip: false,
    );

    if (isMyChip) {
      chip = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          chip,
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.neonRed,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonRed.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (resultSettled && !isWinningBet) {
      return _buildDissolvingChipVisual(chip, bet.id, chipSize);
    }

    if (!isWinningBet) return chip;

    return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.brassLight.withValues(alpha: 0.62),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: chip,
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scale(
          end: const Offset(1.12, 1.12),
          duration: 420.ms,
          curve: Curves.easeInOut,
        );
  }

  Widget _buildDissolvingChipVisual(Widget chip, String betId, double size) {
    const particleColor = Color(0xFFFFE8A3);
    final particleOffsets = const [
      Offset(-15, -14),
      Offset(13, -18),
      Offset(-18, 4),
      Offset(17, 8),
      Offset(-8, 18),
      Offset(9, 15),
    ];

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          chip
              .animate(key: ValueKey('chip-dust-body-$betId'))
              .fadeOut(delay: 260.ms, duration: 620.ms)
              .scale(
                end: const Offset(0.62, 0.62),
                delay: 180.ms,
                duration: 700.ms,
                curve: Curves.easeInCubic,
              )
              .moveY(
                end: -9,
                delay: 180.ms,
                duration: 700.ms,
                curve: Curves.easeOutCubic,
              ),
          for (var i = 0; i < particleOffsets.length; i++)
            Positioned(
              left: size / 2 - 3,
              top: size / 2 - 3,
              child:
                  Container(
                        width: i.isEven ? 5 : 4,
                        height: i.isEven ? 5 : 4,
                        decoration: BoxDecoration(
                          color: particleColor.withValues(alpha: 0.72),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: particleColor.withValues(alpha: 0.35),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      )
                      .animate(key: ValueKey('chip-dust-$betId-$i'))
                      .fadeIn(delay: (210 + i * 28).ms, duration: 70.ms)
                      .fadeOut(delay: (330 + i * 28).ms, duration: 440.ms)
                      .move(
                        end: particleOffsets[i],
                        delay: (230 + i * 28).ms,
                        duration: 560.ms,
                        curve: Curves.easeOutCubic,
                      )
                      .scale(
                        end: const Offset(0.2, 0.2),
                        delay: (330 + i * 28).ms,
                        duration: 460.ms,
                      ),
            ),
        ],
      ),
    );
  }

  _BetSlotSpec? _betSlotSpecFor(int slotIndex) {
    final challenge = _partySnapshot?.round.challenge;
    final slots = challenge?.isBinary == true
        ? _binaryBetSlots
        : challenge?.isAttempt == true
        ? _attemptBetSlots
        : _betSlots;
    for (final spec in slots) {
      if (spec.index == slotIndex) return spec;
    }
    return null;
  }

  Widget _buildPartyModeMark() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'BETS & GUESSES',
          maxLines: 1,
          style: GoogleFonts.outfit(
            color: PartyPalette.creamMuted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'PARTY MODE',
          maxLines: 1,
          style: TextStyle(
            fontFamily: 'RehnCondensed',
            color: PartyPalette.cream,
            fontSize: 35,
            fontWeight: FontWeight.w900,
            height: 0.88,
          ),
        ),
        Container(
          width: 44,
          height: 3,
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: PartyPalette.orange,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseSurfaceTransition({
    required String surfaceKey,
    required Widget child,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 430),
      reverseDuration: const Duration(milliseconds: 360),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        fit: StackFit.expand,
        children: [...previousChildren, if (currentChild != null) currentChild],
      ),
      transitionBuilder: (transitionChild, animation) {
        final enteringBoard =
            transitionChild.key == const ValueKey<String>('betting-surface');
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final slide = Tween<Offset>(
          begin: Offset(enteringBoard ? 0.11 : -0.11, 0),
          end: Offset.zero,
        ).animate(curved);
        return SlideTransition(
          position: slide,
          child: FadeTransition(opacity: curved, child: transitionChild),
        );
      },
      child: KeyedSubtree(key: ValueKey<String>(surfaceKey), child: child),
    );
  }

  Widget _buildPartySingleSceneSurface(PartySnapshot snapshot) {
    final gameState = ref.watch(gameStateProvider);
    final currentPlayer = ref.watch(currentPlayerProvider);
    final secondsRemaining = ref.watch(gameTimerProvider);
    final round = snapshot.round;
    final performanceVisible =
        round.phase == PartyRoundPhase.ready ||
        round.phase == PartyRoundPhase.action ||
        round.phase == PartyRoundPhase.resultEntry ||
        round.phase == PartyRoundPhase.resultConfirm;
    const motion = Duration(milliseconds: 520);
    const fadeMotion = Duration(milliseconds: 320);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _PartyNightBackground(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;
                    final compact = height < 700;
                    final gap = compact ? 8.0 : 10.0;
                    final logoTop = 6.0;
                    final logoHeight = compact ? 76.0 : 92.0;
                    final timerHeight = compact ? 39.0 : 42.0;
                    final leftColumnWidth = (width - 4) / 2;
                    final left = 6.0;
                    final leftWidth = leftColumnWidth - 12;
                    final boardLeft = leftColumnWidth + 4;
                    final boardWidth = width - boardLeft;
                    final timerBetTop = logoTop + logoHeight + 4;
                    final questionBetTop = timerBetTop + timerHeight + gap;
                    final chipHeight = compact ? 96.0 : 102.0;
                    final rawQuestionHeight =
                        height -
                        questionBetTop -
                        chipHeight -
                        (gap * 2) -
                        (compact ? 100 : 120) -
                        8;
                    final questionBetHeight = min(
                      height * (compact ? 0.28 : 0.29),
                      max(compact ? 112.0 : 132.0, rawQuestionHeight),
                    );
                    final chipTop = questionBetTop + questionBetHeight + gap;
                    final playersTop = chipTop + chipHeight + gap;
                    final playersHeight = max(72.0, height - playersTop - 8);
                    final questionPerformanceTop = logoTop + logoHeight + 6;
                    final questionPerformanceHeight = (height * 0.20)
                        .clamp(compact ? 108.0 : 122.0, compact ? 136.0 : 154.0)
                        .toDouble();
                    final stageTop =
                        (questionPerformanceTop + questionPerformanceHeight + 6)
                            .clamp(0.0, height - 190)
                            .toDouble();

                    Widget fadingElement({required Widget child}) {
                      return IgnorePointer(
                        ignoring: performanceVisible,
                        child: AnimatedScale(
                          scale: performanceVisible ? 0.94 : 1,
                          alignment: Alignment.topCenter,
                          duration: motion,
                          curve: Curves.easeOutCubic,
                          child: AnimatedOpacity(
                            opacity: performanceVisible ? 0 : 1,
                            duration: fadeMotion,
                            curve: Curves.easeOutCubic,
                            child: child,
                          ),
                        ),
                      );
                    }

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: left,
                          top: logoTop,
                          width: leftWidth,
                          height: logoHeight,
                          child: _buildPartyModeMark(),
                        ),
                        AnimatedPositioned(
                          duration: motion,
                          curve: Curves.easeInOutCubic,
                          left: performanceVisible ? boardLeft + 6 : left,
                          top: performanceVisible
                              ? logoTop + ((logoHeight - timerHeight) / 2)
                              : timerBetTop,
                          width: performanceVisible
                              ? max(120.0, boardWidth - 12)
                              : leftWidth,
                          height: timerHeight,
                          child: _buildRoundTimer(gameState),
                        ),
                        AnimatedPositioned(
                          duration: motion,
                          curve: Curves.easeInOutCubic,
                          left: left,
                          top: performanceVisible
                              ? questionPerformanceTop
                              : questionBetTop,
                          width: performanceVisible ? width - 12 : leftWidth,
                          height: performanceVisible
                              ? questionPerformanceHeight
                              : questionBetHeight,
                          child: _buildQuestionCard(context, gameState),
                        ),
                        Positioned(
                          left: left,
                          top: chipTop,
                          width: leftWidth,
                          height: chipHeight,
                          child: fadingElement(
                            child: _buildChipPicker(currentPlayer, gameState),
                          ),
                        ),
                        Positioned(
                          left: left,
                          top: playersTop,
                          width: leftWidth,
                          height: playersHeight,
                          child: fadingElement(
                            child: _buildPlayersStrip(gameState),
                          ),
                        ),
                        AnimatedPositioned(
                          duration: motion,
                          curve: Curves.easeInOutCubic,
                          left: performanceVisible ? width + 24 : boardLeft,
                          top: 0,
                          width: boardWidth,
                          height: height,
                          child: IgnorePointer(
                            ignoring: performanceVisible,
                            child: AnimatedOpacity(
                              opacity: performanceVisible ? 0 : 1,
                              duration: fadeMotion,
                              child: _buildBettingBoardAsset(
                                gameState,
                                currentPlayer?.id,
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: PartySingleSceneLayer(
                            key: const ValueKey('party-single-scene'),
                            snapshot: snapshot,
                            currentPlayer: currentPlayer,
                            secondsRemaining: secondsRemaining,
                            commandInFlight: _isPartyCommandInFlight,
                            stageTop: stageTop,

                            onStartAction: () => _runPartyCommand(
                              () => ref
                                  .read(partyGameServiceProvider)
                                  .startAction(snapshot.room.id),
                            ),
                            onOpenResultEntry: () => _runPartyCommand(
                              () => ref
                                  .read(partyGameServiceProvider)
                                  .openResultEntry(snapshot.room.id),
                            ),
                            onSubmitResult: (result) => _runPartyCommand(
                              () => ref
                                  .read(partyGameServiceProvider)
                                  .submitResult(
                                    roomId: snapshot.room.id,
                                    result: result,
                                  ),
                            ),
                            onConfirmResult: () => _runPartyCommand(
                              () => ref
                                  .read(partyGameServiceProvider)
                                  .confirmResult(snapshot.room.id),
                            ),
                            onDisputeResult: () => _runPartyCommand(
                              () => ref
                                  .read(partyGameServiceProvider)
                                  .disputeResult(snapshot.room.id),
                            ),
                          ),
                        ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    final routeState = ref.watch(
      gameStateProvider.select(
        (state) => (state.phase, state.currentRound, state.maxRounds),
      ),
    );
    final phase = routeState.$1;
    final isPartyMode = ref.watch(
      currentRoomProvider.select((room) => room?.gameMode == GameMode.party),
    );
    final partySnapshot = _partySnapshot;
    final isGameOver =
        !isPartyMode &&
        routeState.$2 >= routeState.$3 &&
        phase == RoundPhase.idle;
    if (isGameOver) {
      return Consumer(
        builder: (context, ref, _) {
          final gameState = ref.watch(gameStateProvider);
          return _buildRoundLeaderboardScreen(gameState);
        },
      );
    }

    if (!isPartyMode &&
        (phase == RoundPhase.idle ||
            phase == RoundPhase.question ||
            phase == RoundPhase.guessing)) {
      return _buildPhaseSurfaceTransition(
        surfaceKey: 'guessing-surface',
        child: Consumer(
          builder: (context, ref, _) {
            final gameState = ref.watch(gameStateProvider);
            return _buildGuessingScreen(gameState);
          },
        ),
      );
    }
    if (isPartyMode && partySnapshot != null) {
      return _buildPartySingleSceneSurface(partySnapshot);
    }

    return _buildPhaseSurfaceTransition(
      surfaceKey: 'betting-surface',
      child: PopScope(
        canPop: false,
        child: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: isPartyMode
                    ? const _PartyNightBackground()
                    : CachedAssetImage(
                        AppAssetPaths.background,
                        fit: BoxFit.cover,
                      ),
              ),
              Positioned.fill(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 50,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isCompact = constraints.maxHeight < 700;
                                final gapTight = isCompact ? 4.0 : 6.0;
                                final gap = isCompact ? 8.0 : 10.0;
                                final chipHeight = isCompact ? 96.0 : 102.0;

                                return Column(
                                  children: [
                                    Expanded(
                                      flex: isCompact ? 18 : 20,
                                      child: isPartyMode
                                          ? _buildPartyModeMark()
                                          : _buildPortraitLogo(),
                                    ),
                                    SizedBox(height: gapTight),
                                    SizedBox(
                                      height: isCompact ? 39 : 42,
                                      child: Consumer(
                                        builder: (context, ref, _) {
                                          ref.watch(
                                            gameStateProvider.select(
                                              (state) => (
                                                state.currentRound,
                                                state.maxRounds,
                                                state.phase,
                                              ),
                                            ),
                                          );
                                          return _buildRoundTimer(
                                            ref.read(gameStateProvider),
                                          );
                                        },
                                      ),
                                    ),
                                    SizedBox(height: gap),
                                    Expanded(
                                      flex: isCompact ? 30 : 29,
                                      child: Consumer(
                                        builder: (context, ref, _) {
                                          ref.watch(
                                            gameStateProvider.select(
                                              (state) => (
                                                state.phase,
                                                state.currentQuestion,
                                                state.correctAnswer,
                                                state.winningGuessId,
                                              ),
                                            ),
                                          );
                                          return _buildQuestionCard(
                                            context,
                                            ref.read(gameStateProvider),
                                          );
                                        },
                                      ),
                                    ),
                                    SizedBox(height: gap),
                                    SizedBox(
                                      height: chipHeight,
                                      child: Consumer(
                                        builder: (context, ref, _) {
                                          ref.watch(
                                            gameStateProvider.select(
                                              (state) => (
                                                state.phase,
                                                state.bets,
                                                state.scores,
                                              ),
                                            ),
                                          );
                                          final currentPlayer = ref.watch(
                                            currentPlayerProvider,
                                          );
                                          return _buildChipPicker(
                                            currentPlayer,
                                            ref.read(gameStateProvider),
                                          );
                                        },
                                      ),
                                    ),
                                    SizedBox(height: gap),

                                    Expanded(
                                      flex: isCompact ? 24 : 26,
                                      child: Consumer(
                                        builder: (context, ref, _) {
                                          ref.watch(
                                            gameStateProvider.select(
                                              (state) => state.scores,
                                            ),
                                          );
                                          return _buildPlayersStrip(
                                            ref.read(gameStateProvider),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          flex: 50,
                          child: Consumer(
                            builder: (context, ref, _) {
                              ref.watch(
                                gameStateProvider.select(
                                  (state) => (
                                    state.phase,
                                    state.sortedGuesses,
                                    state.bets,
                                    state.correctAnswer,
                                    state.winningGuessId,
                                  ),
                                ),
                              );
                              final currentPlayerId = ref.watch(
                                currentPlayerProvider.select(
                                  (player) => player?.id,
                                ),
                              );
                              return _buildBettingBoardAsset(
                                ref.read(gameStateProvider),
                                currentPlayerId,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isPartyMode && partySnapshot != null)
                Positioned.fill(
                  child: PartySingleSceneLayer(
                    key: const ValueKey('party-single-scene'),
                    snapshot: partySnapshot,
                    currentPlayer: ref.watch(currentPlayerProvider),
                    secondsRemaining: ref.watch(gameTimerProvider),
                    commandInFlight: _isPartyCommandInFlight,
                    onStartAction: () => _runPartyCommand(
                      () => ref
                          .read(partyGameServiceProvider)
                          .startAction(partySnapshot.room.id),
                    ),
                    onOpenResultEntry: () => _runPartyCommand(
                      () => ref
                          .read(partyGameServiceProvider)
                          .openResultEntry(partySnapshot.room.id),
                    ),
                    onSubmitResult: (result) => _runPartyCommand(
                      () => ref
                          .read(partyGameServiceProvider)
                          .submitResult(
                            roomId: partySnapshot.room.id,
                            result: result,
                          ),
                    ),
                    onConfirmResult: () => _runPartyCommand(
                      () => ref
                          .read(partyGameServiceProvider)
                          .confirmResult(partySnapshot.room.id),
                    ),
                    onDisputeResult: () => _runPartyCommand(
                      () => ref
                          .read(partyGameServiceProvider)
                          .disputeResult(partySnapshot.room.id),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartyAttentionFrame extends StatefulWidget {
  final Widget child;
  final double borderRadius;

  const _PartyAttentionFrame({
    super.key,
    required this.child,
    required this.borderRadius,
  });

  @override
  State<_PartyAttentionFrame> createState() => _PartyAttentionFrameState();
}

class _PartyAttentionFrameState extends State<_PartyAttentionFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          foregroundPainter: _PartyAttentionPainter(
            progress: _controller.value,
            radius: widget.borderRadius,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _PartyAttentionPainter extends CustomPainter {
  final double progress;
  final double radius;

  const _PartyAttentionPainter({required this.progress, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final fade = progress < 0.72
        ? 1.0
        : ((1 - progress) / 0.28).clamp(0.0, 1.0);
    if (fade <= 0) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(1.5),
      Radius.circular(radius),
    );
    final shader = SweepGradient(
      transform: GradientRotation(progress * pi * 2),
      colors: [
        Colors.transparent,
        Colors.transparent,
        PartyPalette.orangeSoft.withValues(alpha: 0.18 * fade),
        PartyPalette.cream.withValues(alpha: 0.88 * fade),
        PartyPalette.orange.withValues(alpha: 0.42 * fade),
        Colors.transparent,
        Colors.transparent,
      ],
      stops: const [0, 0.38, 0.47, 0.52, 0.59, 0.69, 1],
    ).createShader(rect);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..shader = shader
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = shader;
    canvas.drawRRect(rrect, glow);
    canvas.drawRRect(rrect, edge);
  }

  @override
  bool shouldRepaint(covariant _PartyAttentionPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.radius != radius;
  }
}

class _PartyNightBackground extends StatelessWidget {
  const _PartyNightBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: PartyPalette.backgroundGradient,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: _SoftPartyOrb(
              size: 310,
              color: PartyPalette.orange,
              opacity: 0.11,
            ),
          ),
          Positioned(
            right: -90,
            bottom: -130,
            child: _SoftPartyOrb(
              size: 360,
              color: PartyPalette.sage,
              opacity: 0.12,
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _PartyBackgroundGrainPainter()),
          ),
        ],
      ),
    );
  }
}

class _SoftPartyOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _SoftPartyOrb({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _PartyBackgroundGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.018);
    const spacing = 26.0;
    for (double y = 8; y < size.height; y += spacing) {
      for (double x = 8; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 0.65, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

const List<_BetSlotSpec> _betSlots = [
  _BetSlotSpec(
    4,
    'LARGER',
    4,
    _BetSlotTone.green,
    Rect.fromLTWH(0.055, 0.020, 0.890, 0.182),
  ),
  _BetSlotSpec(
    3,
    '',
    3,
    _BetSlotTone.black,
    Rect.fromLTWH(0.055, 0.217, 0.890, 0.174),
  ),
  _BetSlotSpec(
    2,
    'SWEET SPOT',
    2,
    _BetSlotTone.gold,
    Rect.fromLTWH(-0.010, 0.409, 1.020, 0.180),
  ),
  _BetSlotSpec(
    1,
    '',
    3,
    _BetSlotTone.red,
    Rect.fromLTWH(0.055, 0.609, 0.890, 0.174),
  ),
  _BetSlotSpec(
    0,
    'SMALLER',
    4,
    _BetSlotTone.green,
    Rect.fromLTWH(0.055, 0.798, 0.890, 0.182),
  ),
];

const List<_BetSlotSpec> _attemptBetSlots = [
  _BetSlotSpec(
    4,
    "DOESN'T LAND",
    4,
    _BetSlotTone.red,
    Rect.fromLTWH(0.055, 0.020, 0.890, 0.182),
  ),
  _BetSlotSpec(
    3,
    '4–5 TRIES',
    3,
    _BetSlotTone.black,
    Rect.fromLTWH(0.055, 0.217, 0.890, 0.174),
  ),
  _BetSlotSpec(
    2,
    'THIRD TRY',
    2,
    _BetSlotTone.gold,
    Rect.fromLTWH(-0.010, 0.409, 1.020, 0.180),
  ),
  _BetSlotSpec(
    1,
    'SECOND TRY',
    3,
    _BetSlotTone.black,
    Rect.fromLTWH(0.055, 0.609, 0.890, 0.174),
  ),
  _BetSlotSpec(
    0,
    'FIRST TRY',
    4,
    _BetSlotTone.green,
    Rect.fromLTWH(0.055, 0.798, 0.890, 0.182),
  ),
];

const List<_BetSlotSpec> _binaryBetSlots = [
  _BetSlotSpec(
    1,
    'YES',
    2,
    _BetSlotTone.green,
    Rect.fromLTWH(0.055, 0.035, 0.890, 0.445),
  ),
  _BetSlotSpec(
    0,
    'NO',
    2,
    _BetSlotTone.red,
    Rect.fromLTWH(0.055, 0.520, 0.890, 0.445),
  ),
];

enum _BetSlotTone { green, black, gold, red }

class _PendingBetEvent {
  final bool isRemoval;
  final Map<String, dynamic> payload;
  final bool ignoreCurrentPlayer;

  const _PendingBetEvent({
    required this.isRemoval,
    required this.payload,
    this.ignoreCurrentPlayer = true,
  });
}

class _LeaderboardEntry {
  final String name;
  final int score;

  const _LeaderboardEntry({required this.name, required this.score});
}

class _QuestionLoadingText extends StatelessWidget {
  final Color color;

  const _QuestionLoadingText({required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: color.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'LOADING QUESTION',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: color.withValues(alpha: 0.72),
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdaptiveQuestionText extends StatelessWidget {
  final String text;
  final Color color;
  final double minFontSize;
  final double maxFontSize;

  const _AdaptiveQuestionText({
    required this.text,
    required this.color,
    required this.minFontSize,
    required this.maxFontSize,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (width <= 0 || height <= 0) return const SizedBox.shrink();

        final fontSize = _largestFittingFontSize(
          text: text,
          maxWidth: width,
          maxHeight: height,
          minFontSize: minFontSize,
          maxFontSize: maxFontSize,
        );
        final overflowsAtMinimum = !_fits(
          text: text,
          fontSize: minFontSize,
          maxWidth: width,
          maxHeight: height,
        );

        final textWidget = Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'RehnCondensed',
              color: color,
              fontSize: overflowsAtMinimum ? minFontSize : fontSize,
              fontWeight: FontWeight.w900,
              height: 1.02,
              letterSpacing: 0,
            ),
          ),
        );

        if (!overflowsAtMinimum) return textWidget;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: textWidget,
          ),
        );
      },
    );
  }

  static double _largestFittingFontSize({
    required String text,
    required double maxWidth,
    required double maxHeight,
    required double minFontSize,
    required double maxFontSize,
  }) {
    var low = minFontSize;
    var high = maxFontSize;

    for (var i = 0; i < 10; i++) {
      final mid = (low + high) / 2;
      if (_fits(
        text: text,
        fontSize: mid,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      )) {
        low = mid;
      } else {
        high = mid;
      }
    }

    return low.clamp(minFontSize, maxFontSize).toDouble();
  }

  static bool _fits({
    required String text,
    required double fontSize,
    required double maxWidth,
    required double maxHeight,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'RehnCondensed',
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          height: 1.02,
          letterSpacing: 0,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      maxLines: null,
    )..layout(maxWidth: maxWidth);

    return painter.width <= maxWidth && painter.height <= maxHeight;
  }
}

class _BetSlotSpec {
  final int index;
  final String title;
  final int odds;
  final _BetSlotTone tone;
  final Rect rect;

  const _BetSlotSpec(this.index, this.title, this.odds, this.tone, this.rect);

  bool get isSweetSpot => tone == _BetSlotTone.gold;

  bool get isEndSlot => index == 0 || index == 4;
}

class _BoundaryRibbonBacking extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BoundaryRibbonPainter());
  }
}

class _BoundaryRibbonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final bandHeight = min(22.0, size.height * 0.54);
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, centerY),
      width: size.width,
      height: bandHeight,
    );

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.34)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.translate(0, 1.5),
        Radius.circular(bandHeight / 2),
      ),
      shadowPaint,
    );

    final railPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          AppColors.brass.withValues(alpha: 0.50),
          AppColors.brassLight.withValues(alpha: 0.86),
          Colors.white.withValues(alpha: 0.72),
          AppColors.brassLight.withValues(alpha: 0.86),
          AppColors.brass.withValues(alpha: 0.50),
          Colors.transparent,
        ],
        stops: const [0.0, 0.14, 0.38, 0.50, 0.62, 0.86, 1.0],
      ).createShader(rect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(bandHeight / 2)),
      railPaint,
    );

    final darkInset = Rect.fromCenter(
      center: Offset(size.width / 2, centerY),
      width: size.width * 0.92,
      height: bandHeight * 0.34,
    );
    final insetPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.34),
          Colors.black.withValues(alpha: 0.34),
          Colors.transparent,
        ],
      ).createShader(darkInset);
    canvas.drawRRect(
      RRect.fromRectAndRadius(darkInset, Radius.circular(darkInset.height / 2)),
      insetPaint,
    );

    final hairlinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.34)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width * 0.08, centerY - bandHeight * 0.33),
      Offset(size.width * 0.92, centerY - bandHeight * 0.33),
      hairlinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BetSlotSurface extends StatelessWidget {
  final _BetSlotSpec spec;
  final bool isHovering;
  final bool isWinningReveal;
  final bool isPartyMode;

  const _BetSlotSurface({
    required this.spec,
    required this.isHovering,
    required this.isWinningReveal,
    required this.isPartyMode,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(spec.isSweetSpot ? 18 : 10);
    if (isPartyMode) return _buildPartySurface(radius);

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: isWinningReveal ? 22 : 9,
            offset: Offset(0, isWinningReveal ? 8 : 5),
          ),
          if (isHovering || isWinningReveal)
            BoxShadow(
              color: AppColors.brassLight.withValues(
                alpha: isWinningReveal ? 0.96 : 0.36,
              ),
              blurRadius: isWinningReveal ? 36 : 16,
              spreadRadius: isWinningReveal ? 6 : 1,
            ),
          if (isWinningReveal)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.58),
              blurRadius: 20,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.all(spec.isSweetSpot ? 3 : 2.5),
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: _outerRailGradient,
        ),
        child: Container(
          padding: EdgeInsets.all(spec.isSweetSpot ? 3 : 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(spec.isSweetSpot ? 15 : 8),
            color: spec.isSweetSpot
                ? AppColors.chipGold.withValues(alpha: 0.35)
                : AppColors.ivory,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(spec.isSweetSpot ? 12 : 6),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedAssetImage(
                  _textureAsset(spec.tone),
                  fit: spec.isSweetSpot ? BoxFit.fill : BoxFit.cover,
                  alignment: Alignment.center,
                ),
                if (isWinningReveal)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.54),
                          AppColors.chipGold.withValues(alpha: 0.38),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isWinningReveal
                          ? Colors.white.withValues(alpha: 0.82)
                          : Colors.white.withValues(
                              alpha: spec.isSweetSpot ? 0.34 : 0.16,
                            ),
                      width: isWinningReveal ? 2 : (spec.isSweetSpot ? 1.2 : 1),
                    ),
                    borderRadius: BorderRadius.circular(
                      spec.isSweetSpot ? 12 : 6,
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!isWinningReveal) return surface;

    return surface
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .shimmer(
          color: Colors.white.withValues(alpha: 0.38),
          duration: 1800.ms,
        );
  }

  Widget _buildPartySurface(BorderRadius radius) {
    final colors = switch (spec.tone) {
      _BetSlotTone.green => const [Color(0xFF6F9991), Color(0xFF4F7775)],
      _BetSlotTone.black => const [Color(0xFF4A6680), Color(0xFF344F69)],
      _BetSlotTone.gold => const [Color(0xFFF0A15F), Color(0xFFD77C58)],
      _BetSlotTone.red => const [Color(0xFF9A6B7F), Color(0xFF745569)],
    };
    final borderColor = spec.isSweetSpot
        ? PartyPalette.cream.withValues(alpha: 0.62)
        : PartyPalette.cream.withValues(alpha: 0.17);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 210),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: radius,
        border: Border.all(
          color: isWinningReveal ? PartyPalette.orangeSoft : borderColor,
          width: isWinningReveal ? 2.2 : 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 7),
          ),
          if (isWinningReveal)
            BoxShadow(
              color: PartyPalette.orange.withValues(alpha: 0.24),
              blurRadius: 24,
              spreadRadius: 2,
            ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.055),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.08),
            ],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  static const LinearGradient _outerRailGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF8F4E9),
      Color(0xFF4B3D32),
      Color(0xFFFFFDF5),
      Color(0xFF6B5647),
    ],
  );

  static String _textureAsset(_BetSlotTone tone) {
    switch (tone) {
      case _BetSlotTone.red:
        return AppAssetPaths.boardRed;
      case _BetSlotTone.black:
        return AppAssetPaths.boardBlack;
      case _BetSlotTone.green:
        return AppAssetPaths.boardGreen;
      case _BetSlotTone.gold:
        return AppAssetPaths.boardGold;
    }
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isParty;

  const _InfoPill({
    required this.icon,
    required this.label,
    this.isParty = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        gradient: isParty
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.feltDark.withValues(alpha: 0.96),
                  AppColors.felt.withValues(alpha: 0.88),
                ],
              ),
        color: isParty ? PartyPalette.surface.withValues(alpha: 0.88) : null,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isParty
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.brassLight.withValues(alpha: 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isParty ? 0.18 : 0.28),
            blurRadius: isParty ? 10 : 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 21,
            color: isParty ? PartyPalette.orangeSoft : Colors.white,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WebPromoLogo extends StatefulWidget {
  const _WebPromoLogo();

  @override
  State<_WebPromoLogo> createState() => _WebPromoLogoState();
}

class _WebPromoLogoState extends State<_WebPromoLogo> {
  bool _showPromo = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        setState(() => _showPromo = !_showPromo);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _launchStore() async {
    final uri = Uri.parse(
      'https://apps.apple.com/tr/app/bets-guesses-party-game/id6759844771?l=tr',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: _showPromo
          ? _buildPromoCard(key: const ValueKey('promo'))
          : _buildLogo(key: const ValueKey('logo')),
    );
  }

  Widget _buildLogo({required Key key}) {
    return Container(
      key: key,
      alignment: Alignment.center,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _launchStore,
          child: const CachedAssetImage(
            AppAssetPaths.logo,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildPromoCard({required Key key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1E1E), Color(0xFF0A0A0A)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.brassLight.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _launchStore,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.apple,
                      color: AppColors.brassLight,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'DOWNLOAD ON APP STORE',
                          style: GoogleFonts.outfit(
                            color: AppColors.ivory,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 1.2,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: Text(
                    'Tap to download for a better party experience!',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppColors.ivory.withValues(alpha: 0.8),
                      fontSize: 11,
                      height: 1.2,
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
}
