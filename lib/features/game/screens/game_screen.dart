import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/constants/game_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_asset_image.dart';
import '../../../features/game/models/bet_model.dart';
import '../../../features/game/models/guess_model.dart';
import '../../../features/game/models/question_model.dart';
import '../../../features/game/providers/game_providers.dart';
import '../../../features/player/models/player_model.dart';
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
  int _timerSeconds = 0;
  final List<String> _usedQuestionIds = [];
  bool _hasLoadedUsedQuestionIds = false;
  String _guessInput = '';
  int? _selectedChipValue;
  String? _selectedBetId;
  bool _isBetOperationInFlight = false;
  bool _isSubmittingGuess = false;
  bool _isRevealingGuesses = false;
  bool _isRevealingAnswer = false;
  bool _isAdvancingRound = false;
  Set<String> _roundWinners = {};
  Map<String, int> _roundPayouts = {};
  Timer? _slotScanTimer;
  final List<Timer> _revealEffectTimers = [];
  final ValueNotifier<int?> _scanSlotIndexNotifier = ValueNotifier(null);
  bool _showWinnerBadge = false;
  final Set<String> _incomingOtherBetIds = {};
  final Set<String> _playedOtherBetEntryIds = {};
  int _revealSequenceId = 0;
  bool _isResyncing = false;
  bool _resyncAgainAfterCurrent = false;
  Duration _serverClockOffset = Duration.zero;
  DateTime? _lastServerClockSync;
  DateTime? _phaseEndsAt;
  int _timerGeneration = 0;
  Timer? _nextRoundTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeGame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppAssetPaths.warmUpBoardImages(context).catchError((_) {});
    });
  }

  @override
  void dispose() {
    _scanSlotIndexNotifier.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _nextRoundTimer?.cancel();
    _cancelRevealEffects();
    ref.read(realtimeServiceProvider).leaveRoom(widget.roomCode);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resyncFromServer(refreshRealtime: true);
    }
  }

  void _syncAudioForPhase(RoundPhase phase) {
    final audio = ref.read(audioServiceProvider);
    switch (phase) {
      case RoundPhase.idle:
      case RoundPhase.betting:
        audio.startLobbyMusic();
        break;
      case RoundPhase.question:
      case RoundPhase.guessing:
        audio.startQuestionMusic();
        break;
      case RoundPhase.revealGuesses:
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
    await _syncServerClock();
    ref.read(currentRoomProvider.notifier).set(room);

    final playerService = ref.read(playerServiceProvider);
    _players = await playerService.getPlayers(room.id);

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
          .getQuestionById(currentQuestionId);
    }

    gameNotifier.initialize(
      room.id,
      room.code,
      room.maxRounds,
      currentRound: room.currentRound,
      phase: room.roundPhase,
      currentQuestion: currentQuestion,
      scores: scores,
      stateVersion: room.stateVersion,
      phaseEndsAt: room.phaseEndsAt,
    );

    _setupRealtime();

    final isHost = ref.read(isHostProvider);
    if (isHost && room.roundPhase == RoundPhase.question) {
      await _startRound(max(1, room.currentRound));
      return;
    }

    await _resyncFromServer(roomOverride: room);
  }

  void _setupRealtime() {
    final realtimeService = ref.read(realtimeServiceProvider);
    realtimeService.joinRoom(
      widget.roomCode,
      onPhaseChange: (payload) {
        try {
          if (_isStalePhasePayload(payload)) return;

          final phase = RoundPhase.fromString(
            payload['phase'] as String? ?? 'idle',
          );
          final round = _intFromPayload(payload['round']);
          final stateVersion = _intFromPayload(payload['state_version']);
          final phaseEndsAt = _dateTimeFromPayload(payload['phase_ends_at']);
          final questionData = payload['question'] as Map<String, dynamic>?;
          final question = questionData == null
              ? null
              : Question.fromJson(questionData);
          final gameNotifier = ref.read(gameStateProvider.notifier);
          final currentState = ref.read(gameStateProvider);
          final isNewRound = round != null && round > currentState.currentRound;
          final resetRoundData =
              isNewRound ||
              (phase == RoundPhase.guessing &&
                  currentState.phase != RoundPhase.guessing);

          final applied = gameNotifier.applyServerPhase(
            phase: phase,
            round: round,
            question: question,
            stateVersion: stateVersion,
            phaseEndsAt: phaseEndsAt,
            resetRoundData: resetRoundData,
          );
          if (!applied) return;
          _syncAudioForPhase(phase);

          if (question != null && !_usedQuestionIds.contains(question.id)) {
            _usedQuestionIds.add(question.id);
          }

          if (resetRoundData) {
            _roundWinners.clear();
            _roundPayouts.clear();
            _incomingOtherBetIds.clear();
            _playedOtherBetEntryIds.clear();
            _selectedBetId = null;
            _selectedChipValue = null;
            _guessInput = '';
            _isSubmittingGuess = false;
            _cancelRevealEffects();
          }

          if (phase == RoundPhase.guessing) {
            _nextRoundTimer?.cancel();
            _startTimer(GameConstants.guessTimerSeconds, endsAt: phaseEndsAt);
          } else if (phase == RoundPhase.betting) {
            _startTimer(GameConstants.betTimerSeconds, endsAt: phaseEndsAt);
          } else if (phase == RoundPhase.revealAnswer ||
              phase == RoundPhase.scoring) {
            _timer?.cancel();
            ref.read(audioServiceProvider).stopTicking();
            _scheduleNextRound(phaseEndsAt);
          }

          if (mounted) setState(() {});
        } catch (e, st) {
          debugPrint('Error in onPhaseChange: $e\n$st');
        }
      },
      onGuessSubmitted: (_) {
        _maybeAutoRevealGuesses();
      },
      onGuessesRevealed: (payload) {
        if (_isStalePhasePayload(payload)) return;
        final guessesData = payload['guesses'] as List<dynamic>?;
        if (guessesData != null) {
          final guesses = guessesData
              .map((g) => Guess.fromJson(g as Map<String, dynamic>))
              .toList();
          ref.read(gameStateProvider.notifier).setGuesses(guesses);
        }
      },
      onBetPlaced: (payload) {
        try {
          final betData = payload['bet'] as Map<String, dynamic>?;
          if (betData != null) {
            final currentPlayer = ref.read(currentPlayerProvider);
            final currentRound = ref.read(gameStateProvider).currentRound;
            final bet = Bet.fromJson(betData);
            if (bet.roundNumber != currentRound) return;
            if (bet.playerId != currentPlayer?.id) {
              _incomingOtherBetIds.add(bet.id);
              _playedOtherBetEntryIds.remove(bet.id);
              ref.read(gameStateProvider.notifier).addBet(bet);
            }
          }
        } catch (e, st) {
          debugPrint('Error in onBetPlaced: $e\n$st');
        }
      },
      onBetRemoved: (payload) {
        try {
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
      },
      onScoreUpdate: (payload) {
        if (_isStalePhasePayload(payload)) return;
        final scores = _scoresFromPayload(payload['scores']);
        if (scores != null) {
          ref.read(gameStateProvider.notifier).setScores(scores);
        }
      },
      onAnswerRevealed: (payload) {
        try {
          if (_isStalePhasePayload(payload)) return;
          final answer = (payload['answer'] as num?)?.toInt();
          final winningGuessId = payload['winning_guess_id'] as String?;
          if (answer != null) {
            ref
                .read(gameStateProvider.notifier)
                .revealAnswer(answer: answer, winningGuessId: winningGuessId);
            _syncAudioForPhase(RoundPhase.revealAnswer);
            _startRevealSequence(ref.read(gameStateProvider));
          }
        } catch (e, st) {
          debugPrint('Error in onAnswerRevealed: $e\n$st');
        }
      },
      onGameStarted: (payload) {
        final questionData = payload['question'] as Map<String, dynamic>?;
        if (questionData == null) return;

        final round = payload['round'] as int? ?? 1;
        final phase = RoundPhase.fromString(
          payload['phase'] as String? ?? RoundPhase.guessing.name,
        );
        final question = Question.fromJson(questionData);
        final scores = _scoresFromPayload(payload['scores']);
        final stateVersion = _intFromPayload(payload['state_version']);
        final phaseEndsAt = _dateTimeFromPayload(payload['phase_ends_at']);
        final gameNotifier = ref.read(gameStateProvider.notifier);
        gameNotifier.initialize(
          ref.read(gameStateProvider).roomId,
          widget.roomCode,
          ref.read(gameStateProvider).maxRounds,
          currentRound: round,
          phase: phase,
          currentQuestion: question,
          scores: scores,
          stateVersion: stateVersion,
          phaseEndsAt: phaseEndsAt,
        );
        if (!_usedQuestionIds.contains(question.id)) {
          _usedQuestionIds.add(question.id);
        }
        if (phase == RoundPhase.guessing) {
          _guessInput = '';
          _isSubmittingGuess = false;
          _startTimer(GameConstants.guessTimerSeconds, endsAt: phaseEndsAt);
        }
        _syncAudioForPhase(phase);
      },
      onGameEnded: (_) {
        if (mounted) {
          context.goNamed(
            'results',
            pathParameters: {'roomCode': widget.roomCode},
          );
        }
      },
      onStatusChanged: (status) {
        if (status.name == 'subscribed') {
          _resyncFromServer();
        }
      },
    );
  }

  Map<String, int>? _scoresFromPayload(Object? rawScores) {
    if (rawScores is! Map) return null;
    return rawScores.map((key, value) {
      final score = value is int ? value : int.tryParse('$value') ?? 0;
      return MapEntry('$key', score);
    });
  }

  DateTime? _dateTimeFromPayload(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toUtc();
    }
    return null;
  }

  int? _intFromPayload(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  void _attemptExpiredPhaseAdvance() {
    if (!mounted || !ref.read(isHostProvider)) return;
    final state = ref.read(gameStateProvider);
    final deadline = state.phaseEndsAt ?? _phaseEndsAt;
    if (deadline != null && _remainingSeconds(deadline) > 0) return;

    if (state.phase == RoundPhase.guessing) {
      unawaited(_revealGuesses());
    } else if (state.phase == RoundPhase.betting) {
      unawaited(_revealAnswer());
    } else if (state.phase == RoundPhase.revealAnswer ||
        state.phase == RoundPhase.scoring) {
      unawaited(_nextRound());
    }
  }

  void _scheduleNextRound(DateTime? endsAt) {
    _nextRoundTimer?.cancel();
    final deadline =
        endsAt?.toUtc() ?? _serverNow.add(const Duration(seconds: 6));
    final remaining = deadline.difference(_serverNow);
    _nextRoundTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      _attemptExpiredPhaseAdvance,
    );
  }

  bool _phaseAcceptsInput(RoundPhase requiredPhase) {
    final state = ref.read(gameStateProvider);
    if (state.phase != requiredPhase) return false;
    final deadline = state.phaseEndsAt ?? _phaseEndsAt;
    return deadline == null || deadline.isAfter(_serverNow);
  }

  DateTime get _serverNow => DateTime.now().toUtc().add(_serverClockOffset);

  Future<void> _syncServerClock() async {
    final localNow = DateTime.now().toUtc();
    final lastSync = _lastServerClockSync;
    if (lastSync != null &&
        localNow.difference(lastSync) < const Duration(minutes: 2)) {
      return;
    }

    final roomService = ref.read(roomServiceProvider);
    final before = localNow;
    final serverTime = await roomService.getServerTime();
    final after = DateTime.now().toUtc();
    final midpoint = before.add(
      Duration(microseconds: after.difference(before).inMicroseconds ~/ 2),
    );
    _serverClockOffset = serverTime.difference(midpoint);
    _lastServerClockSync = after;
  }

  int _remainingSeconds(DateTime deadline) {
    final remainingMs = deadline.difference(_serverNow).inMilliseconds;
    if (remainingMs <= 0) return 0;
    return (remainingMs / 1000).ceil();
  }

  bool _isStalePhasePayload(Map<String, dynamic> payload) {
    final gameState = ref.read(gameStateProvider);
    final round = _intFromPayload(payload['round']);
    if (round != null && round < gameState.currentRound) return true;

    final version = _intFromPayload(payload['state_version']);
    if (version != null && version < gameState.stateVersion) return true;

    return false;
  }

  Future<void> _resyncFromServer({
    bool refreshRealtime = false,
    Room? roomOverride,
  }) async {
    if (_isResyncing) {
      _resyncAgainAfterCurrent = true;
      return;
    }
    final currentRoom = roomOverride ?? ref.read(currentRoomProvider);
    if (currentRoom == null) return;

    _isResyncing = true;
    try {
      if (refreshRealtime) _setupRealtime();

      final roomService = ref.read(roomServiceProvider);
      final playerService = ref.read(playerServiceProvider);
      final gameService = ref.read(gameServiceProvider);
      final gameNotifier = ref.read(gameStateProvider.notifier);
      final currentPlayer = ref.read(currentPlayerProvider);
      final oldState = ref.read(gameStateProvider);

      final room = roomOverride ?? await roomService.getRoom(currentRoom.id);
      await _syncServerClock();
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

      final phase = room.roundPhase;
      final round = room.currentRound;
      final playersFuture = playerService.getPlayers(room.id);
      final usedQuestionIdsFuture = round > 0 && !_hasLoadedUsedQuestionIds
          ? gameService.getUsedQuestionIds(room.id)
          : null;
      final guessesFuture = round > 0
          ? gameService.getGuesses(room.id, round)
          : null;
      final betsFuture = round > 0 ? gameService.getBets(room.id, round) : null;
      final questionFuture = round > 0 && room.currentQuestionId != null
          ? gameService.getQuestionById(room.currentQuestionId!)
          : null;

      _players = await playersFuture;
      final scores = <String, int>{
        for (final player in _players) player.id: player.score,
      };
      var guesses = <Guess>[];
      var bets = <Bet>[];
      Question? question;

      if (round > 0) {
        if (usedQuestionIdsFuture != null) {
          final usedQuestionIds = await usedQuestionIdsFuture;
          _usedQuestionIds
            ..clear()
            ..addAll(usedQuestionIds);
          _hasLoadedUsedQuestionIds = true;
        }

        final roundGuesses = await guessesFuture!;
        guesses = roundGuesses.map((guess) {
          final player = _playerById(guess.playerId);
          return guess.copyWith(
            playerName: player?.name,
            playerColor: player?.avatarColor,
          );
        }).toList();
        bets = await betsFuture!;
        final questionId =
            room.currentQuestionId ??
            guesses
                .map((guess) => guess.questionId)
                .whereType<String>()
                .firstOrNull;
        question = questionFuture == null
            ? questionId == null
                  ? (oldState.currentRound == round
                        ? oldState.currentQuestion
                        : null)
                  : await gameService.getQuestionById(questionId)
            : await questionFuture;

        if (question != null) {
          if (!_usedQuestionIds.contains(question.id)) {
            _usedQuestionIds.add(question.id);
          }
        }
      }

      final pendingLocalBets = oldState.bets.where((bet) {
        if (!bet.id.startsWith('local-')) return false;
        if (bet.roundNumber != round) return false;
        final actionId = bet.clientActionId;
        if (actionId == null) return true;
        return !bets.any((serverBet) => serverBet.clientActionId == actionId);
      }).toList();
      if (pendingLocalBets.isNotEmpty) {
        bets = [...bets, ...pendingLocalBets];
      }

      _incomingOtherBetIds.clear();
      _playedOtherBetEntryIds.clear();

      final winningGuessId =
          (phase == RoundPhase.revealAnswer || phase == RoundPhase.scoring)
          ? guesses
                .where((guess) => guess.isWinner)
                .map((guess) => guess.id)
                .firstOrNull
          : null;

      gameNotifier.initialize(
        room.id,
        room.code,
        room.maxRounds,
        currentRound: round,
        phase: phase,
        currentQuestion: question,
        scores: scores,
        guesses: guesses,
        bets: bets,
        hasSubmittedGuess:
            currentPlayer != null &&
            guesses.any((guess) => guess.playerId == currentPlayer.id),
        stateVersion: room.stateVersion,
        phaseEndsAt: room.phaseEndsAt,
      );
      if (winningGuessId != null && question != null) {
        gameNotifier.setCorrectAnswer(question.answer, winningGuessId);
        _startRevealSequence(ref.read(gameStateProvider));
      } else {
        _cancelRevealEffects();
      }
      _syncAudioForPhase(phase);

      if (phase == RoundPhase.revealAnswer || phase == RoundPhase.scoring) {
        _timer?.cancel();
        ref.read(audioServiceProvider).stopTicking();
        _scheduleNextRound(room.phaseEndsAt);
      } else if (phase == RoundPhase.guessing) {
        _nextRoundTimer?.cancel();
        _startTimer(GameConstants.guessTimerSeconds, endsAt: room.phaseEndsAt);
      } else if (phase == RoundPhase.betting) {
        _startTimer(GameConstants.betTimerSeconds, endsAt: room.phaseEndsAt);
      }
      if (mounted) setState(() {});
    } catch (error, stackTrace) {
      debugPrint('Error while resyncing game state: $error\n$stackTrace');
    } finally {
      _isResyncing = false;
      if (_resyncAgainAfterCurrent) {
        _resyncAgainAfterCurrent = false;
        unawaited(_resyncFromServer(refreshRealtime: refreshRealtime));
      }
    }
  }

  void _startTimer(int seconds, {DateTime? endsAt}) {
    _timer?.cancel();
    _nextRoundTimer?.cancel();
    final generation = ++_timerGeneration;
    final deadline =
        endsAt?.toUtc() ?? _serverNow.add(Duration(seconds: seconds));
    _phaseEndsAt = deadline;

    void publishRemaining() {
      if (!mounted || generation != _timerGeneration) return;
      final remaining = _remainingSeconds(deadline);
      if (_timerSeconds != remaining) {
        _timerSeconds = remaining;
        ref.read(gameTimerProvider.notifier).setTimer(remaining);
        if (remaining == 10) {
          ref.read(audioServiceProvider).startTicking();
        }
      }
    }

    publishRemaining();

    _timer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!mounted || generation != _timerGeneration) {
        timer.cancel();
        return;
      }

      publishRemaining();
      if (_timerSeconds <= 0) {
        timer.cancel();
        ref.read(audioServiceProvider).stopTicking();
        ref.read(audioServiceProvider).playTimeUp();
        _handleTimerFinished();
      }
    });
  }

  void _handleTimerFinished() {
    _attemptExpiredPhaseAdvance();
  }

  Future<void> _startRound(int round) async {
    final room = ref.read(currentRoomProvider);
    if (room == null) return;

    final gameService = ref.read(gameServiceProvider);
    final roomService = ref.read(roomServiceProvider);
    final realtimeService = ref.read(realtimeServiceProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);
    final isHost = ref.read(isHostProvider);
    final gameState = ref.read(gameStateProvider);

    if (isHost) {
      final currentScores = Map<String, int>.from(gameState.scores);
      bool scoresChanged = false;

      for (final player in _players) {
        final score = currentScores[player.id] ?? player.score;
        if (score <= 0) {
          currentScores[player.id] = GameConstants.startingScore;
          scoresChanged = true;
        }
      }

      if (scoresChanged) {
        final playerService = ref.read(playerServiceProvider);
        await playerService.updateScores(currentScores);
        gameNotifier.setScores(currentScores);
        await realtimeService.broadcast(widget.roomCode, 'score_update', {
          'scores': currentScores,
        });
      }
    }

    final question = await gameService.getRandomQuestion(
      room.id,
      _usedQuestionIds,
      category: room.category,
    );
    if (question == null) return;

    final updatedRoom = await roomService.updatePhase(
      room.id,
      RoundPhase.guessing.name,
      round: round,
      currentQuestionId: question.id,
      durationSeconds: GameConstants.guessTimerSeconds,
      expectedVersion: gameState.stateVersion,
    );

    _usedQuestionIds.add(question.id);
    gameNotifier.setRound(round);
    gameNotifier.setQuestion(question);
    gameNotifier.updatePhase(RoundPhase.guessing);
    _syncAudioForPhase(RoundPhase.guessing);
    _cancelRevealEffects();
    _roundWinners.clear();
    _roundPayouts.clear();
    gameNotifier.resetForNewRound();
    _guessInput = '';
    _selectedChipValue = null;
    _isSubmittingGuess = false;
    ref.read(currentRoomProvider.notifier).set(updatedRoom);
    gameNotifier.setPhaseMetadata(
      stateVersion: updatedRoom.stateVersion,
      phaseEndsAt: updatedRoom.phaseEndsAt,
    );

    await realtimeService.broadcast(widget.roomCode, 'phase_change', {
      'phase': RoundPhase.guessing.name,
      'round': round,
      'question': question.toJson(),
      'state_version': updatedRoom.stateVersion,
      'phase_ends_at': updatedRoom.phaseEndsAt?.toUtc().toIso8601String(),
    });

    _startTimer(
      GameConstants.guessTimerSeconds,
      endsAt: updatedRoom.phaseEndsAt,
    );
    if (mounted) setState(() {});
    ref.read(audioServiceProvider).playQuestionReveal();
  }

  Future<void> _revealGuesses() async {
    final room = ref.read(currentRoomProvider);
    if (room == null) return;
    final gameState = ref.read(gameStateProvider);
    if (_isRevealingGuesses || gameState.phase != RoundPhase.guessing) return;
    _isRevealingGuesses = true;

    try {
      final gameService = ref.read(gameServiceProvider);
      final roomService = ref.read(roomServiceProvider);
      final realtimeService = ref.read(realtimeServiceProvider);
      final gameNotifier = ref.read(gameStateProvider.notifier);

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

      final updatedRoom = await roomService.updatePhase(
        room.id,
        RoundPhase.betting.name,
        round: gameState.currentRound,
        durationSeconds: GameConstants.betTimerSeconds,
        expectedVersion: gameState.stateVersion,
      );
      ref.read(currentRoomProvider.notifier).set(updatedRoom);

      gameNotifier.setGuesses(enrichedGuesses);
      gameNotifier.updatePhase(RoundPhase.betting);
      gameNotifier.setPhaseMetadata(
        stateVersion: updatedRoom.stateVersion,
        phaseEndsAt: updatedRoom.phaseEndsAt,
      );
      _syncAudioForPhase(RoundPhase.betting);
      _timer?.cancel();

      await realtimeService.broadcast(widget.roomCode, 'guesses_revealed', {
        'round': gameState.currentRound,
        'state_version': updatedRoom.stateVersion,
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
        'state_version': updatedRoom.stateVersion,
        'phase_ends_at': updatedRoom.phaseEndsAt?.toUtc().toIso8601String(),
      });

      _startTimer(
        GameConstants.betTimerSeconds,
        endsAt: updatedRoom.phaseEndsAt,
      );
    } catch (e, st) {
      debugPrint('Error while revealing guesses: $e\n$st');
      await _resyncFromServer();
    } finally {
      _isRevealingGuesses = false;
    }
  }

  Future<void> _revealAnswer() async {
    final room = ref.read(currentRoomProvider);
    final gameState = ref.read(gameStateProvider);
    if (room == null ||
        _isRevealingAnswer ||
        gameState.phase != RoundPhase.betting ||
        gameState.currentQuestion == null) {
      return;
    }
    _isRevealingAnswer = true;
    _timer?.cancel();

    try {
      final gameService = ref.read(gameServiceProvider);
      final roomService = ref.read(roomServiceProvider);
      final realtimeService = ref.read(realtimeServiceProvider);
      final gameNotifier = ref.read(gameStateProvider.notifier);
      final correctAnswer = gameState.currentQuestion!.answer;
      final winningGuess = gameService.determineWinner(
        gameState.sortedGuesses,
        correctAnswer,
      );

      final bets = await gameService.getBets(room.id, gameState.currentRound);
      final payouts = gameService.calculatePayouts(
        guesses: gameState.sortedGuesses,
        bets: bets,
        correctAnswer: correctAnswer,
      );

      final newScores = Map<String, int>.from(gameState.scores);
      final totalBets = <String, int>{};
      for (final bet in bets) {
        totalBets[bet.playerId] = (totalBets[bet.playerId] ?? 0) + bet.chips;
      }

      for (final playerId in totalBets.keys) {
        final startingScore =
            newScores[playerId] ?? _playerById(playerId)?.score ?? 0;
        newScores[playerId] = startingScore - totalBets[playerId]!;
      }

      for (final entry in payouts.entries) {
        newScores[entry.key] = (newScores[entry.key] ?? 0) + entry.value;
      }

      for (final entry in newScores.entries) {
        if (entry.value <= 0) newScores[entry.key] = 15;
      }

      final updatedRoom = await roomService.settleRound(
        roomId: room.id,
        expectedVersion: gameState.stateVersion,
        round: gameState.currentRound,
        winningGuessId: winningGuess?.id,
        scores: newScores,
      );
      ref.read(currentRoomProvider.notifier).set(updatedRoom);

      gameNotifier.revealAnswer(
        answer: correctAnswer,
        winningGuessId: winningGuess?.id,
        bets: bets,
        scores: newScores,
      );
      gameNotifier.setPhaseMetadata(
        stateVersion: updatedRoom.stateVersion,
        phaseEndsAt: updatedRoom.phaseEndsAt,
      );
      _syncAudioForPhase(RoundPhase.revealAnswer);
      _startRevealSequence(ref.read(gameStateProvider), payouts: payouts);

      await realtimeService.broadcast(widget.roomCode, 'answer_revealed', {
        'answer': correctAnswer,
        'winning_guess_id': winningGuess?.id,
        'round': gameState.currentRound,
        'state_version': updatedRoom.stateVersion,
      });
      await realtimeService.broadcast(widget.roomCode, 'score_update', {
        'scores': newScores,
        'round': gameState.currentRound,
        'state_version': updatedRoom.stateVersion,
      });
      await realtimeService.broadcast(widget.roomCode, 'phase_change', {
        'phase': RoundPhase.revealAnswer.name,
        'round': gameState.currentRound,
        'state_version': updatedRoom.stateVersion,
        'phase_ends_at': updatedRoom.phaseEndsAt?.toUtc().toIso8601String(),
      });

      _scheduleNextRound(updatedRoom.phaseEndsAt);
    } catch (error, stackTrace) {
      debugPrint('Error while revealing answer: $error\n$stackTrace');
      await _resyncFromServer();
    } finally {
      _isRevealingAnswer = false;
    }
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

  void _startRevealSequence(GameState gameState, {Map<String, int>? payouts}) {
    final correctAnswer = gameState.correctAnswer;
    if (correctAnswer == null) return;

    ref.read(audioServiceProvider).playResultReveal();

    final resolvedPayouts =
        payouts ??
        ref
            .read(gameServiceProvider)
            .calculatePayouts(
              guesses: gameState.sortedGuesses,
              bets: gameState.bets,
              correctAnswer: correctAnswer,
            );
    final winners = resolvedPayouts.entries
        .where((entry) => entry.value > 0)
        .map((entry) => entry.key)
        .toSet();
    final winningSlotIndex = _winningBetSlotIndex(gameState);
    final scanOrder = [
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

    _cancelRevealEffects();

    var step = 0;
    setState(() {
      _revealSequenceId++;
      _roundPayouts = resolvedPayouts;
      _roundWinners = winners;
      _showWinnerBadge = false;
      _scanSlotIndexNotifier.value = scanOrder.isEmpty ? null : scanOrder.first;
    });

    _slotScanTimer = Timer.periodic(const Duration(milliseconds: 240), (timer) {
      if (!mounted) {
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
            if (mounted) ref.read(audioServiceProvider).playClink();
          }),
        );
        return;
      }
      ref.read(audioServiceProvider).playClick();
      _scanSlotIndexNotifier.value = scanOrder[step];
    });
  }

  void _cancelRevealEffects() {
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
    return ref
        .read(gameServiceProvider)
        .determineWinningBetSlotIndex(gameState.sortedGuesses, correctAnswer);
  }

  int _currentPlayerRoundPayout(GameState gameState) {
    final currentPlayer = ref.read(currentPlayerProvider);
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

  int _currentPlayerTotalBets(GameState gameState) {
    final currentPlayer = ref.read(currentPlayerProvider);
    if (currentPlayer == null) return 0;
    return gameState.bets
        .where((b) => b.playerId == currentPlayer.id)
        .fold(0, (sum, bet) => sum + bet.chips);
  }

  Future<void> _nextRound() async {
    if (_isAdvancingRound) return;
    _isAdvancingRound = true;
    final gameState = ref.read(gameStateProvider);

    try {
      if (gameState.currentRound >= gameState.maxRounds) {
        final room = ref.read(currentRoomProvider);
        if (room != null) {
          final roomService = ref.read(roomServiceProvider);
          final finishedRoom = await roomService.endGame(
            room.id,
            expectedVersion: gameState.stateVersion,
          );
          ref.read(currentRoomProvider.notifier).set(finishedRoom);

          final realtimeService = ref.read(realtimeServiceProvider);
          await realtimeService.broadcast(widget.roomCode, 'game_ended', {
            'state_version': finishedRoom.stateVersion,
          });
        }

        if (mounted) {
          context.goNamed(
            'results',
            pathParameters: {'roomCode': widget.roomCode},
          );
        }
      } else {
        await _startRound(gameState.currentRound + 1);
      }
    } catch (error, stackTrace) {
      debugPrint('Error while advancing round: $error\n$stackTrace');
      await _resyncFromServer();
    } finally {
      _isAdvancingRound = false;
    }
  }

  Future<void> _submitGuess(int value) async {
    final room = ref.read(currentRoomProvider);
    final player = ref.read(currentPlayerProvider);
    final gameState = ref.read(gameStateProvider);
    if (room == null ||
        player == null ||
        gameState.hasSubmittedGuess ||
        !_phaseAcceptsInput(RoundPhase.guessing)) {
      return;
    }

    final gameService = ref.read(gameServiceProvider);
    final realtimeService = ref.read(realtimeServiceProvider);

    setState(() => _isSubmittingGuess = true);

    try {
      await gameService.submitGuess(
        roomId: room.id,
        roundNumber: gameState.currentRound,
        playerId: player.id,
        questionId: gameState.currentQuestion?.id ?? '',
        value: value,
      );

      ref.read(gameStateProvider.notifier).setGuessSubmitted(true);
      await realtimeService.broadcast(widget.roomCode, 'guess_submitted', {
        'player_id': player.id,
      });
      await _maybeAutoRevealGuesses();
    } finally {
      if (mounted) setState(() => _isSubmittingGuess = false);
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
    setState(
      () => _guessInput = _guessInput.substring(0, _guessInput.length - 1),
    );
  }

  void _clearGuessInput() {
    final gameState = ref.read(gameStateProvider);
    if (gameState.hasSubmittedGuess || _isSubmittingGuess) return;
    setState(() => _guessInput = '');
  }

  Future<void> _submitNumpadGuess() async {
    final value = int.tryParse(_guessInput);
    if (value == null) return;
    await _submitGuess(value);
  }

  Future<void> _placeBet(int slotIndex, int chips, {Offset? position}) async {
    final room = ref.read(currentRoomProvider);
    final player = ref.read(currentPlayerProvider);
    final gameState = ref.read(gameStateProvider);
    if (room == null ||
        player == null ||
        _isBetOperationInFlight ||
        !_phaseAcceptsInput(RoundPhase.betting)) {
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

    final clientActionId =
        '${player.id}-${DateTime.now().microsecondsSinceEpoch}';
    final optimisticId = 'local-$clientActionId';
    final optimisticBet = Bet(
      id: optimisticId,
      roomId: room.id,
      roundNumber: gameState.currentRound,
      playerId: player.id,
      targetGuessId: targetGuessId,
      slotIndex: slotIndex,
      chips: chips,
      payoutMultiplier: GameConstants.boardOdds[slotIndex],
      playerName: player.name,
      playerColor: player.avatarColor,
      positionX: safeDx,
      positionY: safeDy,
      clientActionId: clientActionId,
    );

    final gameNotifier = ref.read(gameStateProvider.notifier);
    gameNotifier.addBet(optimisticBet);
    if (mounted) setState(() {});

    try {
      final bet = await gameService.placeBet(
        roomId: room.id,
        roundNumber: gameState.currentRound,
        playerId: player.id,
        targetGuessId: targetGuessId,
        slotIndex: slotIndex,
        chips: chips,
        positionX: safeDx,
        positionY: safeDy,
        clientActionId: clientActionId,
      );

      final placedBet = bet.copyWith(
        playerName: player.name,
        playerColor: player.avatarColor,
        positionX: safeDx,
        positionY: safeDy,
        clientActionId: clientActionId,
      );

      gameNotifier.replaceBet(optimisticId, placedBet);

      await realtimeService.broadcast(widget.roomCode, 'bet_placed', {
        'bet': {
          ...placedBet.toJson(),
          'id': bet.id,
          'player_name': player.name,
          'player_color': player.avatarColor,
        },
      });
    } catch (_) {
      gameNotifier.removeBetById(optimisticId);
    } finally {
      _isBetOperationInFlight = false;
    }

    _selectedBetId = null;
    if (mounted) setState(() {});
  }

  Future<void> _moveBet(
    Bet sourceBet,
    int targetSlotIndex, {
    Offset? position,
  }) async {
    final room = ref.read(currentRoomProvider);
    final gameState = ref.read(gameStateProvider);
    if (room == null ||
        sourceBet.id.startsWith('local-') ||
        _isBetOperationInFlight ||
        !_phaseAcceptsInput(RoundPhase.betting)) {
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
      payoutMultiplier: GameConstants.boardOdds[targetSlotIndex],
      positionX: safeDx,
      positionY: safeDy,
    );

    _isBetOperationInFlight = true;
    ref.read(audioServiceProvider).playDrop();
    gameNotifier.addBet(optimisticBet);
    if (mounted) setState(() {});

    try {
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

      await realtimeService.broadcast(widget.roomCode, 'bet_placed', {
        'bet': {
          ...placedBet.toJson(),
          'id': placedBet.id,
          'player_name': placedBet.playerName,
          'player_color': placedBet.playerColor,
        },
      });
    } catch (_) {
      gameNotifier.addBet(oldBet);
    } finally {
      _isBetOperationInFlight = false;
    }

    _selectedBetId = sourceBet.id;
    _selectedChipValue = null;
    if (mounted) setState(() {});
  }

  String? _targetGuessIdForSlot(int slotIndex, GameState gameState) {
    return null;
  }

  Future<void> _removeBetById(Bet bet) async {
    if (_isBetOperationInFlight || !_phaseAcceptsInput(RoundPhase.betting)) {
      return;
    }

    final gameService = ref.read(gameServiceProvider);
    final realtimeService = ref.read(realtimeServiceProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);

    _isBetOperationInFlight = true;
    ref.read(audioServiceProvider).playClick();
    if (_selectedBetId == bet.id) _selectedBetId = null;
    gameNotifier.removeBetById(bet.id);
    if (mounted) setState(() {});

    try {
      if (!bet.id.startsWith('local-')) {
        await gameService.removeBet(bet.id);
        await realtimeService.broadcast(widget.roomCode, 'bet_removed', {
          'bet_id': bet.id,
          'player_id': bet.playerId,
          'slot_index': bet.slotIndex,
        });
      }
    } catch (_) {
      gameNotifier.addBet(bet);
    } finally {
      _isBetOperationInFlight = false;
    }

    if (mounted) setState(() {});
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
    return Row(
      children: [
        Expanded(
          child: _InfoPill(
            icon: Icons.groups_rounded,
            label: 'Round ${gameState.currentRound}/${gameState.maxRounds}',
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
              Text(
                'QUESTION',
                style: GoogleFonts.outfit(
                  color: AppColors.felt,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  height: 1,
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

  Widget _buildAnswerRevealCard(GameState gameState) {
    final payout = _currentPlayerRoundPayout(gameState);
    final totalBets = _currentPlayerTotalBets(gameState);
    final netProfit = payout - totalBets;
    final didWin = netProfit > 0;
    final answer = gameState.correctAnswer ?? gameState.currentQuestion?.answer;
    final resultSettled = _showWinnerBadge;
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
                'ANSWER',
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
                              answer == null ? '--' : _formatGuessValue(answer),
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: 'RehnCondensed',
                                color: headlineColor,
                                fontSize: 76,
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

        final canEdit = gameState.phase == RoundPhase.betting;
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
            color: selectedBet != null
                ? AppColors.feltDark.withValues(alpha: 0.24)
                : Colors.transparent,
            border: Border.all(
              color: selectedBet != null
                  ? AppColors.brassLight
                  : Colors.transparent,
              width: 1.2,
            ),
            boxShadow: [
              if (selectedBet != null)
                BoxShadow(
                  color: AppColors.brassLight.withValues(alpha: 0.22),
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
          ],
        ),
      ),
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
                : _AdaptiveQuestionText(
                    text: gameState.currentQuestion!.getText(locale: 'en'),
                    color: AppColors.feltDark,
                    minFontSize: 22,
                    maxFontSize: 46,
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
            onTap: isHost ? _nextRound : null,
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

  Widget _buildBettingBoardAsset() {
    final gameState = ref.watch(gameStateProvider);
    final currentPlayer = ref.watch(currentPlayerProvider);
    final canEdit = gameState.phase == RoundPhase.betting;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final boundaryValues = _boardBoundaryValues(gameState);
        final isReveal = _isRevealPhase(gameState);
        final winningSlotIndex = isReveal
            ? _winningBetSlotIndex(gameState)
            : null;
        final orderedSlots = [
          ..._betSlots.where((slot) => !slot.isSweetSpot),
          ..._betSlots.where((slot) => slot.isSweetSpot),
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
                          boundaries: boundaryValues,
                        ),
                      ),
                    ),
                  if (_showWinnerBadge && winningSlotIndex != null)
                    ..._buildWinParticles(size, winningSlotIndex),
                  ..._buildBoundaryLabels(boundaryValues, size),
                  if (!(_showWinnerBadge && winningSlotIndex != null))
                    _buildAllPlacedChips(
                      gameState.bets,
                      size,
                      currentPlayer?.id,
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

    final odds = GameConstants.boardOdds[winningSlotIndex];
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

  Widget _buildCasinoSlotTitle(_BetSlotSpec slot, List<int> boundaries) {
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _playedOtherBetEntryIds.add(bet.id);
        _incomingOtherBetIds.remove(bet.id);
      });
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
    for (final spec in _betSlots) {
      if (spec.index == slotIndex) return spec;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final currentPlayer = ref.watch(currentPlayerProvider);

    if (gameState.isGameOver) {
      return _buildRoundLeaderboardScreen(gameState);
    }

    if (gameState.phase == RoundPhase.idle ||
        gameState.phase == RoundPhase.question ||
        gameState.phase == RoundPhase.guessing) {
      return _buildGuessingScreen(gameState);
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
                                    child: _buildPortraitLogo(),
                                  ),
                                  SizedBox(height: gapTight),
                                  SizedBox(
                                    height: isCompact ? 39 : 42,
                                    child: _buildRoundTimer(gameState),
                                  ),
                                  SizedBox(height: gap),
                                  Expanded(
                                    flex: isCompact ? 30 : 29,
                                    child: _buildQuestionCard(
                                      context,
                                      gameState,
                                    ),
                                  ),
                                  SizedBox(height: gap),
                                  SizedBox(
                                    height: chipHeight,
                                    child: _buildChipPicker(
                                      currentPlayer,
                                      gameState,
                                    ),
                                  ),
                                  SizedBox(height: gap),

                                  Expanded(
                                    flex: isCompact ? 24 : 26,
                                    child: _buildPlayersStrip(gameState),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(flex: 50, child: _buildBettingBoardAsset()),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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

enum _BetSlotTone { green, black, gold, red }

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

  const _BetSlotSurface({
    required this.spec,
    required this.isHovering,
    required this.isWinningReveal,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(spec.isSweetSpot ? 18 : 10);

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

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.feltDark.withValues(alpha: 0.96),
            AppColors.felt.withValues(alpha: 0.88),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.brassLight.withValues(alpha: 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 21, color: Colors.white),
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
    // Placeholder URL for now
    final uri = Uri.parse('https://example.com/download-app');
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
      child: const CachedAssetImage(AppAssetPaths.logo, fit: BoxFit.contain),
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
