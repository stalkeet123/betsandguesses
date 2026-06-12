import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/game_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/widgets/cached_asset_image.dart';
import '../../../features/game/models/bet_model.dart';
import '../../../features/game/models/guess_model.dart';
import '../../../features/game/models/question_model.dart';
import '../../../features/game/providers/game_providers.dart';
import '../../../features/player/models/player_model.dart';
import '../../../features/room/providers/room_providers.dart';
import '../models/game_state.dart';
import '../widgets/poker_chip.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String roomCode;

  const GameScreen({super.key, required this.roomCode});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  List<Player> _players = [];
  Timer? _timer;
  int _timerSeconds = 0;
  final List<String> _usedQuestionIds = [];
  String _guessInput = '';
  bool _isSubmittingGuess = false;
  bool _isRevealingGuesses = false;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initializeGame() async {
    final room = ref.read(currentRoomProvider);
    if (room == null) return;

    final playerService = ref.read(playerServiceProvider);
    _players = await playerService.getPlayers(room.id);

    final gameNotifier = ref.read(gameStateProvider.notifier);
    gameNotifier.initialize(room.id, room.code, room.maxRounds);

    final scores = <String, int>{};
    for (final player in _players) {
      scores[player.id] = player.score;
    }
    gameNotifier.setScores(scores);

    _setupRealtime();

    final isHost = ref.read(isHostProvider);
    if (isHost) {
      await _startRound(1);
    }
  }

  void _setupRealtime() {
    final realtimeService = ref.read(realtimeServiceProvider);
    realtimeService.joinRoom(
      widget.roomCode,
      onPhaseChange: (payload) {
        final phase = RoundPhase.fromString(payload['phase'] as String? ?? 'idle');
        final round = payload['round'] as int?;
        final gameNotifier = ref.read(gameStateProvider.notifier);

        gameNotifier.updatePhase(phase);
        if (round != null) gameNotifier.setRound(round);

        if (phase == RoundPhase.question || phase == RoundPhase.guessing) {
          final questionData = payload['question'] as Map<String, dynamic>?;
          if (questionData != null) {
            gameNotifier.setQuestion(Question.fromJson(questionData));
          }
          gameNotifier.setGuessSubmitted(false);
          gameNotifier.setBetsPlaced(false);

          if (phase == RoundPhase.guessing) {
            _guessInput = '';
            _isSubmittingGuess = false;
            _startTimer(GameConstants.guessTimerSeconds);
          }
        }

        if (phase == RoundPhase.betting) {
          _startTimer(GameConstants.betTimerSeconds);
        }

        if (phase == RoundPhase.revealAnswer || phase == RoundPhase.scoring) {
          _timer?.cancel();
        }

        setState(() {});
      },
      onGuessSubmitted: (_) {
        _maybeAutoRevealGuesses();
        setState(() {});
      },
      onGuessesRevealed: (payload) {
        final guessesData = payload['guesses'] as List<dynamic>?;
        if (guessesData != null) {
          final guesses = guessesData.map((g) => Guess.fromJson(g as Map<String, dynamic>)).toList();
          ref.read(gameStateProvider.notifier).setGuesses(guesses);
          setState(() {});
        }
      },
      onBetPlaced: (payload) {
        final betData = payload['bet'] as Map<String, dynamic>?;
        if (betData != null) {
          final currentPlayer = ref.read(currentPlayerProvider);
          final bet = Bet.fromJson(betData);
          if (bet.playerId != currentPlayer?.id) {
            ref.read(gameStateProvider.notifier).addBet(bet);
          }
          setState(() {});
        }
      },
      onBetRemoved: (payload) {
        final betId = payload['bet_id'] as String?;
        final playerId = payload['player_id'] as String?;
        final slotIndex = payload['slot_index'] as int?;
        if (betId != null) {
          ref.read(gameStateProvider.notifier).removeBetById(betId);
          setState(() {});
          return;
        }
        if (playerId != null && slotIndex != null) {
          ref.read(gameStateProvider.notifier).removeBetForSlot(playerId, slotIndex);
          setState(() {});
        }
      },
      onScoreUpdate: (payload) {
        final scoresData = payload['scores'] as Map<String, dynamic>?;
        if (scoresData != null) {
          final scores = scoresData.map((k, v) => MapEntry(k, v as int));
          ref.read(gameStateProvider.notifier).setScores(scores);
          setState(() {});
        }
      },
      onAnswerRevealed: (payload) {
        final answer = payload['answer'] as int?;
        final winningGuessId = payload['winning_guess_id'] as String?;
        if (answer != null) {
          ref.read(gameStateProvider.notifier).setCorrectAnswer(answer, winningGuessId);
          setState(() {});
        }
      },
      onGameStarted: (_) {},
      onGameEnded: (_) {
        if (mounted) {
          context.goNamed('results', pathParameters: {'roomCode': widget.roomCode});
        }
      },
    );
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    _timerSeconds = seconds;
    ref.read(gameStateProvider.notifier).setTimer(seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        _timerSeconds--;
        ref.read(gameStateProvider.notifier).setTimer(_timerSeconds);
        setState(() {});
      } else {
        timer.cancel();
        _handleTimerFinished();
      }
    });
  }

  void _handleTimerFinished() {
    final gameState = ref.read(gameStateProvider);
    final isHost = ref.read(isHostProvider);
    if (isHost && gameState.phase == RoundPhase.guessing) {
      _revealGuesses();
    } else if (isHost && gameState.phase == RoundPhase.betting) {
      _revealAnswer();
    }
  }

  Future<void> _startRound(int round) async {
    final room = ref.read(currentRoomProvider);
    if (room == null) return;

    final gameService = ref.read(gameServiceProvider);
    final realtimeService = ref.read(realtimeServiceProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);

    final question = await gameService.getRandomQuestion(room.id, _usedQuestionIds);
    if (question == null) return;
    _usedQuestionIds.add(question.id);

    gameNotifier.setRound(round);
    gameNotifier.setQuestion(question);
    gameNotifier.updatePhase(RoundPhase.guessing);
    gameNotifier.setGuesses([]);
    gameNotifier.setBets([]);
    gameNotifier.setGuessSubmitted(false);
    gameNotifier.setBetsPlaced(false);
    _guessInput = '';
    _isSubmittingGuess = false;

    await realtimeService.broadcast(widget.roomCode, 'phase_change', {
      'phase': RoundPhase.guessing.name,
      'round': round,
      'question': question.toJson(),
    });

    _startTimer(GameConstants.guessTimerSeconds);
    if (mounted) setState(() {});
  }

  Future<void> _revealGuesses() async {
    final room = ref.read(currentRoomProvider);
    if (room == null) return;
    final gameState = ref.read(gameStateProvider);
    if (_isRevealingGuesses || gameState.phase != RoundPhase.guessing) return;
    _isRevealingGuesses = true;

    try {
      final gameService = ref.read(gameServiceProvider);
      final realtimeService = ref.read(realtimeServiceProvider);
      final gameNotifier = ref.read(gameStateProvider.notifier);

      final guesses = await gameService.getGuesses(room.id, gameState.currentRound);
      final enrichedGuesses = guesses.map((guess) {
        final player = _playerById(guess.playerId);
        return guess.copyWith(
          playerName: player?.name,
          playerColor: player?.avatarColor,
        );
      }).toList();

      gameNotifier.setGuesses(enrichedGuesses);
      gameNotifier.updatePhase(RoundPhase.betting);
      _timer?.cancel();

      await realtimeService.broadcast(widget.roomCode, 'guesses_revealed', {
        'guesses': enrichedGuesses.map((g) => {
          ...g.toJson(),
          'id': g.id,
          'player_name': g.playerName,
          'player_color': g.playerColor,
        }).toList(),
      });

      await realtimeService.broadcast(widget.roomCode, 'phase_change', {
        'phase': RoundPhase.betting.name,
        'round': gameState.currentRound,
      });

      _startTimer(GameConstants.betTimerSeconds);
      if (mounted) setState(() {});
    } finally {
      _isRevealingGuesses = false;
    }
  }

  Future<void> _revealAnswer() async {
    final room = ref.read(currentRoomProvider);
    if (room == null) return;

    final gameService = ref.read(gameServiceProvider);
    final realtimeService = ref.read(realtimeServiceProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);
    final gameState = ref.read(gameStateProvider);
    _timer?.cancel();

    final correctAnswer = gameState.currentQuestion!.answer;
    final winningGuess = gameService.determineWinner(gameState.sortedGuesses, correctAnswer);
    if (winningGuess != null) {
      await gameService.markWinner(winningGuess.id);
    }

    final bets = await gameService.getBets(room.id, gameState.currentRound);
    final payouts = gameService.calculatePayouts(
      guesses: gameState.sortedGuesses,
      bets: bets,
      correctAnswer: correctAnswer,
      winningGuess: winningGuess,
    );

    final newScores = Map<String, int>.from(gameState.scores);
    for (final entry in payouts.entries) {
      newScores[entry.key] = (newScores[entry.key] ?? 0) + entry.value;
    }

    gameNotifier.setCorrectAnswer(correctAnswer, winningGuess?.id);
    gameNotifier.updatePhase(RoundPhase.revealAnswer);
    gameNotifier.setScores(newScores);

    final playerService = ref.read(playerServiceProvider);
    await playerService.updateScores(newScores);

    await realtimeService.broadcast(widget.roomCode, 'answer_revealed', {
      'answer': correctAnswer,
      'winning_guess_id': winningGuess?.id,
    });
    await realtimeService.broadcast(widget.roomCode, 'score_update', {'scores': newScores});
    await realtimeService.broadcast(widget.roomCode, 'phase_change', {
      'phase': RoundPhase.revealAnswer.name,
      'round': gameState.currentRound,
    });

    if (mounted) setState(() {});
  }

  Future<void> _nextRound() async {
    final gameState = ref.read(gameStateProvider);

    if (gameState.currentRound >= gameState.maxRounds) {
      final room = ref.read(currentRoomProvider);
      if (room != null) {
        final roomService = ref.read(roomServiceProvider);
        await roomService.endGame(room.id);

        final realtimeService = ref.read(realtimeServiceProvider);
        await realtimeService.broadcast(widget.roomCode, 'game_ended', {});
      }

      if (mounted) {
        context.goNamed('results', pathParameters: {'roomCode': widget.roomCode});
      }
    } else {
      await _startRound(gameState.currentRound + 1);
    }
  }

  Future<void> _submitGuess(int value) async {
    final room = ref.read(currentRoomProvider);
    final player = ref.read(currentPlayerProvider);
    final gameState = ref.read(gameStateProvider);
    if (room == null || player == null || gameState.hasSubmittedGuess) return;

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
      await realtimeService.broadcast(widget.roomCode, 'guess_submitted', {'player_id': player.id});
      await _maybeAutoRevealGuesses();
    } finally {
      if (mounted) setState(() => _isSubmittingGuess = false);
    }
  }

  Future<void> _maybeAutoRevealGuesses() async {
    final isHost = ref.read(isHostProvider);
    final room = ref.read(currentRoomProvider);
    final gameState = ref.read(gameStateProvider);
    if (!isHost || room == null || gameState.phase != RoundPhase.guessing || _isRevealingGuesses) return;

    final gameService = ref.read(gameServiceProvider);
    final guesses = await gameService.getGuesses(room.id, gameState.currentRound);
    final expectedPlayers = max(1, _players.where((player) => player.isConnected).length);
    if (guesses.length >= expectedPlayers) {
      await _revealGuesses();
    }
  }

  void _appendGuessDigit(String digit) {
    final gameState = ref.read(gameStateProvider);
    if (gameState.hasSubmittedGuess || _isSubmittingGuess || _guessInput.length >= 10) return;
    if (_guessInput == '0') {
      setState(() => _guessInput = digit);
    } else {
      setState(() => _guessInput += digit);
    }
  }

  void _backspaceGuessDigit() {
    final gameState = ref.read(gameStateProvider);
    if (gameState.hasSubmittedGuess || _isSubmittingGuess || _guessInput.isEmpty) return;
    setState(() => _guessInput = _guessInput.substring(0, _guessInput.length - 1));
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
    if (room == null || player == null) return;

    final gameService = ref.read(gameServiceProvider);
    final realtimeService = ref.read(realtimeServiceProvider);

    ref.read(audioServiceProvider).playDrop();

    String? targetGuessId;
    if (slotIndex > 0 && slotIndex <= gameState.sortedGuesses.length) {
      targetGuessId = gameState.sortedGuesses[slotIndex - 1].id;
    }

    final optimisticId = 'local-${DateTime.now().microsecondsSinceEpoch}';
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
      positionX: position?.dx,
      positionY: position?.dy,
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
      );

      final placedBet = bet.copyWith(
        playerName: player.name,
        playerColor: player.avatarColor,
        positionX: position?.dx,
        positionY: position?.dy,
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
    }

    if (mounted) setState(() {});
  }

  Future<void> _moveBet(Bet sourceBet, int targetSlotIndex, {Offset? position}) async {
    final room = ref.read(currentRoomProvider);
    if (room == null) return;

    final gameService = ref.read(gameServiceProvider);
    final realtimeService = ref.read(realtimeServiceProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);

    gameNotifier.removeBetById(sourceBet.id);
    if (mounted) setState(() {});

    if (!sourceBet.id.startsWith('local-')) {
      await gameService.removeBet(sourceBet.id);
      await realtimeService.broadcast(widget.roomCode, 'bet_removed', {
        'bet_id': sourceBet.id,
        'player_id': sourceBet.playerId,
        'slot_index': sourceBet.slotIndex,
      });
    }

    await _placeBet(targetSlotIndex, sourceBet.chips, position: position);
  }

  Future<void> _removeBetById(Bet bet) async {
    final gameService = ref.read(gameServiceProvider);
    final realtimeService = ref.read(realtimeServiceProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);

    ref.read(audioServiceProvider).playClick();
    gameNotifier.removeBetById(bet.id);
    if (mounted) setState(() {});

    if (!bet.id.startsWith('local-')) {
      await gameService.removeBet(bet.id);
      await realtimeService.broadcast(widget.roomCode, 'bet_removed', {
        'bet_id': bet.id,
        'player_id': bet.playerId,
        'slot_index': bet.slotIndex,
      });
    }
  }

  Future<void> _lockBets() async {
    ref.read(audioServiceProvider).playClink();
    ref.read(gameStateProvider.notifier).setBetsPlaced(true);
    if (mounted) setState(() {});
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
        color: player?.color ?? AppColors.brass,
        score: gameState.scores[playerId] ?? player?.score ?? 0,
      );
    }).toList();

    entries.sort((a, b) => b.score.compareTo(a.score));
    return entries;
  }



  Widget _buildDraggableChip({
    required String label,
    required Color color,
    required bool isAvailable,
    required int value,
    bool isScoreChip = false,
    double size = 34,
  }) {
    final chip = PokerChip(label: label, color: color, size: size, isScoreChip: isScoreChip);

    if (!isAvailable) {
      return Opacity(opacity: 0.2, child: chip);
    }

    return Draggable<_ChipDragData>(
      data: _ChipDragData(value: value, size: size),
      feedback: Transform.scale(
        scale: 1.08,
        child: Material(
          color: Colors.transparent,
          child: IgnorePointer(child: chip),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.42, child: chip),
      onDragStarted: () => ref.read(audioServiceProvider).playClick(),
      child: chip,
    );
  }

  Widget _buildPortraitLogo() {
    return const CachedAssetImage(
      AppAssetPaths.logo,
      fit: BoxFit.contain,
    );
  }

  Widget _buildRoundTimer(GameState gameState) {
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
          child: _InfoPill(
            icon: Icons.timer_rounded,
            label: gameState.timerSeconds > 0
                ? '0:${gameState.timerSeconds.toString().padLeft(2, '0')}'
                : '--:--',
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(BuildContext context, GameState gameState) {
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
        border: Border.all(color: AppColors.ivory.withValues(alpha: 0.92), width: 1.4),
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
              Expanded(child: Container(height: 1, color: AppColors.brass.withValues(alpha: 0.52))),
              const SizedBox(width: 8),
              const Icon(Icons.auto_awesome_rounded, size: 12, color: AppColors.felt),
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
              const Icon(Icons.auto_awesome_rounded, size: 12, color: AppColors.felt),
              const SizedBox(width: 8),
              Expanded(child: Container(height: 1, color: AppColors.brass.withValues(alpha: 0.52))),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _AdaptiveQuestionText(
              text: gameState.currentQuestion?.textTr ?? 'Question will appear here.',
              color: const Color(0xFF0A2C59),
              minFontSize: 20,
              maxFontSize: 34,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipPicker(Player? currentPlayer, GameState gameState) {
    final myBets = currentPlayer == null
        ? const <Bet>[]
        : gameState.bets.where((bet) => bet.playerId == currentPlayer.id).toList();
    final totalOnTable = myBets.fold<int>(0, (sum, bet) => sum + bet.chips);
    final totalChips = currentPlayer == null ? 0 : gameState.scores[currentPlayer.id] ?? currentPlayer.score;
    final availableChips = totalChips <= 0 ? 999 : max(0, totalChips - totalOnTable);
    final bankLabel = totalChips <= 0 ? '--' : '$availableChips';

    return LayoutBuilder(
      builder: (context, constraints) {
        final chipSize = min(50.0, max(38.0, constraints.maxWidth * 0.22));

        final canReturnBet = gameState.phase == RoundPhase.betting && !gameState.hasPlacedBets;

        return DragTarget<_ChipDragData>(
          onWillAcceptWithDetails: (details) => canReturnBet && details.data.sourceBet != null,
          onAcceptWithDetails: (details) {
            final sourceBet = details.data.sourceBet;
            if (sourceBet != null) _removeBetById(sourceBet);
          },
          builder: (context, candidateData, rejectedData) {
            final isReturning = candidateData.isNotEmpty;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: isReturning ? AppColors.feltDark.withValues(alpha: 0.38) : Colors.transparent,
                border: Border.all(
                  color: isReturning ? AppColors.brassLight : Colors.transparent,
                  width: 1.2,
                ),
                boxShadow: [
                  if (isReturning)
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
                      Expanded(child: Container(height: 1, color: AppColors.brassLight.withValues(alpha: 0.52))),
                      const SizedBox(width: 8),
                      Text(
                        isReturning ? 'RETURN CHIP' : 'CHOOSE YOUR CHIP',
                        style: GoogleFonts.outfit(
                          color: AppColors.ivory.withValues(alpha: 0.78),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Container(height: 1, color: AppColors.brassLight.withValues(alpha: 0.52))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDraggableChip(
                        label: '5',
                        color: AppColors.feltLight,
                        isAvailable: canReturnBet && availableChips >= 5,
                        value: 5,
                        size: chipSize,
                      ),
                      _buildDraggableChip(
                        label: '10',
                        color: AppColors.neonBlue,
                        isAvailable: canReturnBet && availableChips >= 10,
                        value: 10,
                        size: chipSize,
                      ),
                      _buildDraggableChip(
                        label: '50',
                        color: AppColors.burgundy,
                        isAvailable: canReturnBet && availableChips >= 50,
                        value: 50,
                        size: chipSize,
                      ),
                      _buildDraggableChip(
                        label: '100',
                        color: AppColors.neonPurple,
                        isAvailable: canReturnBet && availableChips >= 100,
                        value: 100,
                        size: chipSize,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'BANK $bankLabel  |  ON TABLE $totalOnTable',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: AppColors.ivory.withValues(alpha: 0.82),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlaceBetButton(GameState gameState) {
    final canPlace = gameState.phase == RoundPhase.betting && !gameState.hasPlacedBets;

    return SizedBox(
      width: double.infinity,
      height: 62,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: canPlace
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFE58A), Color(0xFFFFB91F), Color(0xFFD88700)],
                )
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.chipGold.withValues(alpha: 0.54),
                    AppColors.brass.withValues(alpha: 0.48),
                  ],
                ),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: AppColors.ivory.withValues(alpha: 0.86), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
            BoxShadow(
              color: AppColors.chipGold.withValues(alpha: canPlace ? 0.34 : 0.1),
              blurRadius: 10,
              spreadRadius: -1,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(19),
            onTap: canPlace ? _lockBets : null,
            child: Center(
              child: Text(
                gameState.hasPlacedBets ? 'BETS LOCKED' : 'PLACE BET',
                style: GoogleFonts.outfit(
                  color: AppColors.ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0,
                  shadows: [
                    Shadow(
                      color: Colors.white.withValues(alpha: 0.42),
                      blurRadius: 1,
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
  }

  Widget _buildGuessingScreen(GameState gameState) {
    final hasSubmitted = gameState.hasSubmittedGuess;
    final canInput = gameState.phase == RoundPhase.guessing && gameState.currentQuestion != null;
    final canSubmit = canInput && _guessInput.isNotEmpty && !hasSubmitted && !_isSubmittingGuess;

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
                    final contentWidth = constraints.maxWidth.clamp(0.0, 560.0).toDouble();
                    final designHeight = constraints.maxHeight.clamp(650.0, 810.0).toDouble();
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
                                child: _buildPortraitLogo(),
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
                                child: _buildSubmitGuessButton(canSubmit: canSubmit, hasSubmitted: hasSubmitted),
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
        border: Border.all(color: AppColors.brassLight.withValues(alpha: 0.78), width: 2),
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
              Expanded(child: Container(height: 1, color: AppColors.brass.withValues(alpha: 0.52))),
              const SizedBox(width: 9),
              const Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.brass),
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
              const Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.brass),
              const SizedBox(width: 9),
              Expanded(child: Container(height: 1, color: AppColors.brass.withValues(alpha: 0.52))),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _AdaptiveQuestionText(
              text: gameState.currentQuestion?.textTr ?? 'Question will appear here.',
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
        Expanded(child: Container(height: 1, color: AppColors.brassLight.withValues(alpha: 0.45))),
        const SizedBox(width: 10),
        const Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.brassLight),
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
        const Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.brassLight),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: AppColors.brassLight.withValues(alpha: 0.45))),
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
                    final isPortrait = constraints.maxHeight > constraints.maxWidth;
                    final header = _buildRoundResultHero(gameState, winningGuess);
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
                              Expanded(flex: 34, child: _buildRoundResultHeader(gameState)),
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
    final winnerPlayer = winningGuess == null ? null : _playerById(winningGuess.playerId);
    final winnerColor = winnerPlayer?.color ?? AppColors.brass;

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
        border: Border.all(color: AppColors.brassLight.withValues(alpha: 0.72), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.36),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
          BoxShadow(color: AppColors.brass.withValues(alpha: 0.12), blurRadius: 18),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFE58A), Color(0xFFFFB91F), Color(0xFFD88700)]),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.ivory.withValues(alpha: 0.72), width: 1.2),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, color: AppColors.ink, size: 17),
                SizedBox(width: 7),
                Text(
                  'ROUND WINNER',
                  style: TextStyle(color: AppColors.ink, fontSize: 16, fontWeight: FontWeight.w900, height: 1),
                ),
                SizedBox(width: 7),
                Icon(Icons.star_rounded, color: AppColors.ink, size: 17),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 74,
                height: 74,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [winnerColor.withValues(alpha: 0.94), winnerColor.withValues(alpha: 0.46)]),
                  border: Border.all(color: AppColors.brassLight, width: 3),
                  boxShadow: [BoxShadow(color: AppColors.brass.withValues(alpha: 0.36), blurRadius: 18)],
                ),
                child: Text(
                  winnerName.isNotEmpty ? winnerName[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.ivory, fontSize: 34, fontWeight: FontWeight.w900, height: 1),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      winningGuess == null ? 'No winning guess' : winnerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: AppColors.ivory,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        letterSpacing: 0,
                        shadows: const [Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 3))],
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      winningGuess == null ? 'Waiting for scores' : 'Guess ${_formatGuessInput('${winningGuess.value}')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: AppColors.brassLight,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 10),
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
                        Expanded(child: Container(height: 1, color: AppColors.brassLight.withValues(alpha: 0.46))),
                      ],
                    ),
                    const SizedBox(height: 5),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
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
                          shadows: [Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 3))],
                        ),
                      ),
                    ),
                  ],
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
            Expanded(child: Container(height: 1.5, color: AppColors.brassLight.withValues(alpha: 0.44))),
            const SizedBox(width: 8),
            const Icon(Icons.auto_awesome_rounded, color: AppColors.brassLight, size: 22),
            const SizedBox(width: 8),
            Text(
              gameState.currentRound >= gameState.maxRounds ? 'GAME OVER!' : 'ROUND OVER!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'RehnCondensed',
                color: AppColors.brassLight,
                fontSize: 34,
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
            const Icon(Icons.auto_awesome_rounded, color: AppColors.brassLight, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 1.5, color: AppColors.brassLight.withValues(alpha: 0.44))),
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
            shadows: const [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
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
        border: Border.all(color: AppColors.brassLight.withValues(alpha: 0.28), width: 1.4),
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
              const Icon(Icons.workspace_premium_rounded, color: AppColors.brassLight, size: 22),
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
                      style: GoogleFonts.outfit(color: AppColors.ivory.withValues(alpha: 0.74)),
                    ),
                  )
                : ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _buildRoundLeaderboardRow(entries[index], index),
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
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isPodium ? AppColors.ivory.withValues(alpha: 0.94) : Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPodium ? rankColor.withValues(alpha: 0.72) : Colors.white.withValues(alpha: 0.08),
          width: isPodium ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
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
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: entry.color,
              border: Border.all(color: Colors.white.withValues(alpha: 0.82), width: 2),
            ),
            child: Text(
              entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: isPodium ? AppColors.ink : AppColors.ivory,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: 0,
              ),
            ),
          ),
          Text(
            '${entry.score}',
            style: GoogleFonts.outfit(
              color: isPodium ? AppColors.mahogany : AppColors.brassLight,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: 0,
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
                  colors: [Color(0xFFFFE58A), Color(0xFFFFB91F), Color(0xFFD88700)],
                )
              : LinearGradient(
                  colors: [
                    AppColors.feltDark.withValues(alpha: 0.86),
                    AppColors.felt.withValues(alpha: 0.72),
                  ],
                ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.ivory.withValues(alpha: isHost ? 0.88 : 0.28), width: 1.6),
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
                isHost ? (isLastRound ? 'FINAL RESULTS' : 'NEXT ROUND') : 'WAITING FOR HOST',
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
    final display = switch ((hasSubmitted, gameState.currentQuestion == null, _guessInput.isEmpty)) {
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
        border: Border.all(color: AppColors.brassLight.withValues(alpha: 0.86), width: 1.8),
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
              if (!hasSubmitted && gameState.currentQuestion != null && _guessInput.isNotEmpty)
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
      [',', '0', 'BACK'],
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
                        disabled: !canInput || hasSubmitted || _isSubmittingGuess,
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
    final isComma = key == ',';
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
                        ? const [Color(0xFF0C6D41), Color(0xFF073D27), Color(0xFF021B11)]
                        : const [Color(0xFFFFFFF6), Color(0xFFF8E5B8), Color(0xFFE9BF69), Color(0xFFFFF9E6)],
                    stops: isBack ? const [0.0, 0.62, 1.0] : const [0.0, 0.46, 0.82, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: isBack ? 0.06 : 0.54),
                      blurRadius: 5,
                      offset: const Offset(-1, -1),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isBack ? 0.24 : 0.12),
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
                            } else if (!isComma) {
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
                              color: Colors.white.withValues(alpha: isBack ? 0.16 : 0.64),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        Center(
                          child: isBack
                              ? const Icon(Icons.backspace_outlined, color: AppColors.brassLight, size: 25)
                              : Text(
                                  key,
                                  style: TextStyle(
                                    fontFamily: 'RehnCondensed',
                                    color: AppColors.feltDark,
                                    fontSize: isComma ? 37 : 40,
                                    fontWeight: FontWeight.w900,
                                    height: 0.86,
                                    letterSpacing: 0,
                                    shadows: [
                                      Shadow(
                                        color: Colors.white.withValues(alpha: 0.78),
                                        blurRadius: 1.5,
                                        offset: const Offset(0, 1),
                                      ),
                                      Shadow(
                                        color: Colors.black.withValues(alpha: 0.14),
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

  Widget _buildSubmitGuessButton({required bool canSubmit, required bool hasSubmitted}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF6C6), Color(0xFFC47A12), Color(0xFFFFE48B), Color(0xFF8D520B)],
          stops: [0.0, 0.34, 0.72, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: AppColors.brassLight.withValues(alpha: canSubmit ? 0.32 : 0.12),
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
                ? const LinearGradient(colors: [Color(0xFF72E66F), Color(0xFF1F8D44)])
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFF0A8), Color(0xFFFFC42E), Color(0xFFD88700), Color(0xFFFFD867)],
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
                        const Icon(Icons.auto_awesome_rounded, color: AppColors.mahoganyDark, size: 21),
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
                        const Icon(Icons.auto_awesome_rounded, color: AppColors.mahoganyDark, size: 21),
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
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.feltDark.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.brass.withValues(alpha: 0.42), width: 1.6),
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
              Expanded(child: Container(height: 1, color: AppColors.brassLight.withValues(alpha: 0.34))),
              const SizedBox(width: 8),
              Text(
                'PLAYERS',
                style: GoogleFonts.outfit(
                  color: AppColors.ivory.withValues(alpha: 0.78),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Container(height: 1, color: AppColors.brassLight.withValues(alpha: 0.34))),
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

                final tileWidth = ((constraints.maxWidth - 18) / 4).clamp(58.0, 82.0).toDouble();
                final sortedPlayers = [..._players]
                  ..sort((a, b) {
                    final scoreA = gameState.scores[a.id] ?? a.score;
                    final scoreB = gameState.scores[b.id] ?? b.score;
                    return scoreB.compareTo(scoreA);
                  });

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      for (var i = 0; i < sortedPlayers.length; i++) ...[
                        SizedBox(
                          width: tileWidth,
                          child: _buildPlayerProfileTile(
                            sortedPlayers[i],
                            i,
                            gameState.scores[sortedPlayers[i].id] ?? sortedPlayers[i].score,
                          ),
                        ),
                        if (i != sortedPlayers.length - 1) const SizedBox(width: 6),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerProfileTile(Player player, int index, int score) {
    final color = _profileColor(player, index);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        color.withValues(alpha: 0.95),
                        color,
                        AppColors.mahoganyDark.withValues(alpha: 0.64),
                      ],
                    ),
                    border: Border.all(color: AppColors.ivory.withValues(alpha: 0.86), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.36),
                        blurRadius: 9,
                        spreadRadius: -1,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.36),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        height: 1,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.55),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -5,
                  top: -4,
                  child: Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: Border.all(color: AppColors.brassLight, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.34),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          player.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: AppColors.ivory,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$score',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            color: color,
            fontSize: 12,
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
    );
  }

  Color _profileColor(Player player, int index) {
    const fallbackColors = [
      Color(0xFF44D65F),
      Color(0xFF1F9DFF),
      Color(0xFFFF3B30),
      Color(0xFFB45CFF),
      Color(0xFFFFB020),
      Color(0xFF00D4C8),
      Color(0xFFFF5FA2),
      Color(0xFF7CFF4D),
      Color(0xFFFF7A1A),
      Color(0xFF6D7CFF),
    ];

    return player.avatarColor.isEmpty ? fallbackColors[index % fallbackColors.length] : player.color;
  }

  Widget _buildBettingBoardAsset() {
    final gameState = ref.watch(gameStateProvider);
    final currentPlayer = ref.watch(currentPlayerProvider);
    final canBet = gameState.phase == RoundPhase.betting && !gameState.hasPlacedBets;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final orderedSlots = [
          ..._betSlots.where((slot) => !slot.isSweetSpot),
          ..._betSlots.where((slot) => slot.isSweetSpot),
        ];
        final boardKey = GlobalKey();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: DragTarget<_ChipDragData>(
            onWillAcceptWithDetails: (_) => canBet,
            onAcceptWithDetails: (details) {
              final box = boardKey.currentContext?.findRenderObject() as RenderBox?;
              if (box == null) return;

              final boardSize = box.size;
              final chipCenter = details.offset + Offset(details.data.size / 2, details.data.size / 2);
              final local = box.globalToLocal(chipCenter);
              final targetSlot = _slotAtBoardPosition(local, boardSize);
              if (targetSlot == null) return;

              final position = _slotLocalPosition(targetSlot, local, boardSize);
              final sourceBet = details.data.sourceBet;
              if (sourceBet != null) {
                _moveBet(sourceBet, targetSlot.index, position: position);
              } else {
                _placeBet(targetSlot.index, details.data.value, position: position);
              }
            },
            builder: (context, candidateData, rejectedData) {
              final isHovering = candidateData.isNotEmpty;

              return Stack(
                key: boardKey,
                clipBehavior: Clip.none,
                children: [
                  for (final spec in orderedSlots)
                    Positioned(
                      left: spec.rect.left * size.width,
                      top: spec.rect.top * size.height,
                      width: spec.rect.width * size.width,
                      height: spec.rect.height * size.height,
                      child: _buildCodedBetSlot(
                        spec: spec,
                        bets: gameState.bets.where((bet) => bet.slotIndex == spec.index).toList(),
                        currentPlayerId: currentPlayer?.id,
                        canDrag: canBet,
                        isBoardHovering: isHovering,
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCodedBetSlot({
    required _BetSlotSpec spec,
    required List<Bet> bets,
    required String? currentPlayerId,
    required bool canDrag,
    required bool isBoardHovering,
  }) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 140),
      scale: isBoardHovering ? 1.006 : 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: _BetSlotSurface(spec: spec, isHovering: isBoardHovering)),
          _buildBetSlotLabel(spec),
          LayoutBuilder(
            builder: (context, constraints) {
              return _buildPlacedChips(
                bets,
                Size(constraints.maxWidth, constraints.maxHeight),
                currentPlayerId,
                canDrag: canDrag,
              );
            },
          ),
        ],
      ),
    );
  }

  _BetSlotSpec? _slotAtBoardPosition(Offset local, Size boardSize) {
    if (boardSize.isEmpty) return null;

    final percent = Offset(local.dx / boardSize.width, local.dy / boardSize.height);
    final hitTestSlots = [
      ..._betSlots.where((slot) => slot.isSweetSpot),
      ..._betSlots.where((slot) => !slot.isSweetSpot).toList().reversed,
    ];
    for (final slot in hitTestSlots) {
      if (slot.rect.contains(percent)) return slot;
    }

    return null;
  }

  Offset _slotLocalPosition(_BetSlotSpec slot, Offset boardLocal, Size boardSize) {
    if (boardSize.isEmpty) return const Offset(0.5, 0.5);

    final percent = Offset(boardLocal.dx / boardSize.width, boardLocal.dy / boardSize.height);
    return Offset(
      ((percent.dx - slot.rect.left) / slot.rect.width).clamp(0.02, 0.98).toDouble(),
      ((percent.dy - slot.rect.top) / slot.rect.height).clamp(0.04, 0.96).toDouble(),
    );
  }

  Widget _buildBetSlotLabel(_BetSlotSpec slot) {
    final showTitle = slot.isEndSlot || slot.isSweetSpot;

    return IgnorePointer(
      child: Stack(
        children: [
          if (showTitle) Positioned.fill(child: _buildCasinoSlotTitle(slot)),
          Positioned(
            top: slot.isSweetSpot ? 7 : 6,
            right: slot.isSweetSpot ? 12 : 8,
            child: _buildOddsTicket(slot),
          ),
        ],
      ),
    );
  }

  Widget _buildOddsTicket(_BetSlotSpec slot) {
    final isSweetSpot = slot.isSweetSpot;

    return ClipPath(
      clipper: const _OddsTicketClipper(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSweetSpot
                ? const [Color(0xFFFFF3B6), Color(0xFFFFC84D), Color(0xFF8C5C18)]
                : const [Color(0xFF2B1710), Color(0xFF0A0706), Color(0xFF3A2115)],
          ),
          border: Border.all(color: AppColors.brassLight.withValues(alpha: 0.72), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isSweetSpot ? 0.22 : 0.45),
              blurRadius: 5,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Container(
          width: isSweetSpot ? 46 : 42,
          height: isSweetSpot ? 25 : 23,
          alignment: Alignment.center,
          padding: const EdgeInsets.only(top: 1),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'PAYS',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: isSweetSpot
                      ? AppColors.mahoganyDark.withValues(alpha: 0.62)
                      : AppColors.brassLight.withValues(alpha: 0.72),
                  fontSize: 5.5,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '${slot.odds}:1',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: isSweetSpot ? AppColors.mahoganyDark : AppColors.brassLight,
                  fontSize: isSweetSpot ? 11.5 : 11,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0,
                  shadows: [
                    Shadow(
                      color: isSweetSpot ? Colors.white.withValues(alpha: 0.55) : Colors.black,
                      blurRadius: isSweetSpot ? 1 : 2,
                      offset: const Offset(0, 0.6),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCasinoSlotTitle(_BetSlotSpec slot) {
    final isSweetSpot = slot.isSweetSpot;
    final textColor = isSweetSpot ? AppColors.mahoganyDark : Colors.white;
    final strokeColor = isSweetSpot ? AppColors.brassLight : AppColors.feltDark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                slot.title,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: GoogleFonts.rye(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = isSweetSpot ? 2.6 : 3.2
                    ..color = strokeColor.withValues(alpha: isSweetSpot ? 0.72 : 0.78),
                  fontSize: isSweetSpot ? 24 : 31,
                  fontWeight: FontWeight.w400,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
              Text(
                slot.title,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: GoogleFonts.rye(
                  color: textColor,
                  fontSize: isSweetSpot ? 24 : 31,
                  fontWeight: FontWeight.w400,
                  height: 1,
                  letterSpacing: 0,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: isSweetSpot ? 0.28 : 0.75),
                      blurRadius: isSweetSpot ? 2 : 7,
                      offset: const Offset(0, 1.4),
                    ),
                    if (!isSweetSpot)
                      Shadow(
                        color: AppColors.brassLight.withValues(alpha: 0.34),
                        blurRadius: 9,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlacedChips(
    List<Bet> bets,
    Size slotSize,
    String? currentPlayerId, {
    required bool canDrag,
  }) {
    if (bets.isEmpty) return const SizedBox.shrink();

    final myBets = bets.where((bet) => bet.playerId == currentPlayerId).toList();
    final otherBets = bets.where((bet) => bet.playerId != currentPlayerId).toList();
    final chipSize = min(40.0, max(26.0, min(slotSize.width, slotSize.height) * 0.36));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (otherBets.isNotEmpty) _buildOtherBetMarkers(otherBets, slotSize),
        for (var i = 0; i < myBets.length; i++)
          _positionedBetChip(
            myBets[i],
            i,
            slotSize,
            chipSize,
            canDrag: canDrag,
            onTap: canDrag ? () => _removeBetById(myBets[i]) : null,
          ),
      ],
    );
  }

  Widget _buildOtherBetMarkers(List<Bet> bets, Size slotSize) {
    final groupedBets = _groupBetsByPlayer(bets).take(4).toList();
    if (groupedBets.isEmpty) return const SizedBox.shrink();

    final markerHeight = min(24.0, max(18.0, slotSize.height * 0.2));
    final markerWidth = min(54.0, max(38.0, slotSize.width * 0.24));
    final rowWidth = groupedBets.length * markerWidth + max(0, groupedBets.length - 1) * 4;
    final startLeft = ((slotSize.width - rowWidth) / 2).clamp(4.0, max(4.0, slotSize.width - rowWidth)).toDouble();
    final top = (slotSize.height - markerHeight - 6).clamp(4.0, max(4.0, slotSize.height - markerHeight)).toDouble();

    return Stack(
      children: [
        for (var i = 0; i < groupedBets.length; i++)
          Positioned(
            left: startLeft + i * (markerWidth + 4),
            top: top,
            child: _OtherBetMarker(bet: groupedBets[i], width: markerWidth, height: markerHeight),
          ),
      ],
    );
  }

  List<_GroupedPlayerBet> _groupBetsByPlayer(List<Bet> bets) {
    final totals = <String, int>{};
    final colors = <String, String?>{};

    for (final bet in bets) {
      totals[bet.playerId] = (totals[bet.playerId] ?? 0) + bet.chips;
      colors[bet.playerId] ??= bet.playerColor;
    }

    final grouped =
        totals.entries.map((entry) => _GroupedPlayerBet(playerColor: colors[entry.key], total: entry.value)).toList();
    grouped.sort((a, b) => b.total.compareTo(a.total));
    return grouped;
  }

  Widget _positionedBetChip(
    Bet bet,
    int index,
    Size slotSize,
    double chipSize, {
    bool canDrag = false,
    VoidCallback? onTap,
  }) {
    final fallbackX = 0.5 + ((index % 3) - 1) * 0.14;
    final fallbackY = 0.52 + ((index ~/ 3) % 2) * 0.16;
    final x = (bet.positionX ?? fallbackX).clamp(0.0, 1.0).toDouble();
    final y = (bet.positionY ?? fallbackY).clamp(0.0, 1.0).toDouble();
    final left = (x * slotSize.width - chipSize / 2).clamp(2.0, slotSize.width - chipSize - 2).toDouble();
    final top = (y * slotSize.height - chipSize / 2).clamp(2.0, slotSize.height - chipSize - 2).toDouble();

    final chip = PokerChip(
      label: '${bet.chips}',
      color: bet.playerColor != null ? Color(Helpers.colorFromHex(bet.playerColor!)) : AppColors.chipGold,
      size: chipSize,
      isScoreChip: bet.playerColor == null,
    );

    final child = GestureDetector(onTap: onTap, child: chip);

    return Positioned(
      left: left,
      top: top,
      child: canDrag
          ? Draggable<_ChipDragData>(
              data: _ChipDragData(value: bet.chips, size: chipSize, sourceBet: bet),
              feedback: Material(
                color: Colors.transparent,
                child: IgnorePointer(child: chip),
              ),
              childWhenDragging: Opacity(opacity: 0.18, child: child),
              onDragStarted: () => ref.read(audioServiceProvider).playClick(),
              child: child,
            )
          : child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final currentPlayer = ref.watch(currentPlayerProvider);

    if (gameState.phase == RoundPhase.idle ||
        gameState.phase == RoundPhase.question ||
        gameState.phase == RoundPhase.guessing) {
      return _buildGuessingScreen(gameState);
    }

    if (gameState.phase == RoundPhase.revealAnswer || gameState.phase == RoundPhase.scoring) {
      return _buildRoundLeaderboardScreen(gameState);
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
                        child: Column(
                          children: [
                            Expanded(
                              flex: 24,
                              child: _buildPortraitLogo(),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(height: 42, child: _buildRoundTimer(gameState)),
                            const SizedBox(height: 10),
                            Expanded(
                              flex: 28,
                              child: _buildQuestionCard(context, gameState),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(height: 108, child: _buildChipPicker(currentPlayer, gameState)),
                            const SizedBox(height: 12),
                            _buildPlaceBetButton(gameState),
                            const SizedBox(height: 12),
                            Expanded(
                              flex: 22,
                              child: _buildPlayersStrip(gameState),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: 50,
                      child: _buildBettingBoardAsset(),
                    ),
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
  _BetSlotSpec(6, 'LARGER', 6, _BetSlotTone.green, Rect.fromLTWH(0.055, 0.018, 0.890, 0.130)),
  _BetSlotSpec(5, 'OVER', 4, _BetSlotTone.black, Rect.fromLTWH(0.055, 0.153, 0.890, 0.142)),
  _BetSlotSpec(4, 'JUST OVER', 3, _BetSlotTone.black, Rect.fromLTWH(0.055, 0.300, 0.890, 0.142)),
  _BetSlotSpec(3, 'SWEET SPOT', 2, _BetSlotTone.gold, Rect.fromLTWH(-0.010, 0.430, 1.020, 0.136)),
  _BetSlotSpec(2, 'JUST UNDER', 3, _BetSlotTone.red, Rect.fromLTWH(0.055, 0.560, 0.890, 0.142)),
  _BetSlotSpec(1, 'UNDER', 4, _BetSlotTone.red, Rect.fromLTWH(0.055, 0.705, 0.890, 0.142)),
  _BetSlotSpec(0, 'SMALLER', 6, _BetSlotTone.green, Rect.fromLTWH(0.055, 0.852, 0.890, 0.130)),
];

enum _BetSlotTone { green, black, gold, red }

class _ChipDragData {
  final int value;
  final double size;
  final Bet? sourceBet;

  const _ChipDragData({required this.value, required this.size, this.sourceBet});
}

class _GroupedPlayerBet {
  final String? playerColor;
  final int total;

  const _GroupedPlayerBet({
    required this.playerColor,
    required this.total,
  });
}

class _LeaderboardEntry {
  final String name;
  final Color color;
  final int score;

  const _LeaderboardEntry({
    required this.name,
    required this.color,
    required this.score,
  });
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
      if (_fits(text: text, fontSize: mid, maxWidth: maxWidth, maxHeight: maxHeight)) {
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

  bool get isEndSlot => index == 0 || index == 6;
}

class _OddsTicketClipper extends CustomClipper<Path> {
  const _OddsTicketClipper();

  @override
  Path getClip(Size size) {
    final notch = size.height * 0.28;

    return Path()
      ..moveTo(notch, 0)
      ..lineTo(size.width - notch, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width - notch, size.height)
      ..lineTo(notch, size.height)
      ..lineTo(0, size.height / 2)
      ..close();
  }

  @override
  bool shouldReclip(covariant _OddsTicketClipper oldClipper) => false;
}

class _OtherBetMarker extends StatelessWidget {
  final _GroupedPlayerBet bet;
  final double width;
  final double height;

  const _OtherBetMarker({required this.bet, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    final color = bet.playerColor != null ? Color(Helpers.colorFromHex(bet.playerColor!)) : AppColors.brass;

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.black.withValues(alpha: 0.46),
        border: Border.all(color: color.withValues(alpha: 0.88), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: height * 0.46,
            height: height * 0.46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: AppColors.ivory.withValues(alpha: 0.72), width: 0.8),
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${bet.total}',
                maxLines: 1,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: height * 0.58,
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
}

class _BetSlotSurface extends StatelessWidget {
  final _BetSlotSpec spec;
  final bool isHovering;

  const _BetSlotSurface({
    required this.spec,
    required this.isHovering,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(spec.isSweetSpot ? 18 : 10);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: 9,
            offset: const Offset(0, 5),
          ),
          if (isHovering)
            BoxShadow(
              color: AppColors.brassLight.withValues(alpha: 0.36),
              blurRadius: 16,
              spreadRadius: 1,
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
            color: spec.isSweetSpot ? AppColors.chipGold.withValues(alpha: 0.35) : AppColors.ivory,
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
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withValues(alpha: spec.isSweetSpot ? 0.34 : 0.16),
                      width: spec.isSweetSpot ? 1.2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(spec.isSweetSpot ? 12 : 6),
                  ),
                  child: const SizedBox.expand(),
                ),
              ],
            ),
          ),
        ),
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
        border: Border.all(color: AppColors.brassLight.withValues(alpha: 0.22), width: 1.2),
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
