import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/game_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/realtime_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../player/models/player_model.dart';
import '../../room/models/room_model.dart';
import '../../room/providers/room_providers.dart';
import '../models/party_moment.dart';
import '../models/party_snapshot.dart';
import '../providers/party_local_media_provider.dart';
import '../providers/party_session_provider.dart';
import '../services/party_game_service.dart';

const _partyNight = Color(0xFF050C16);
const _partyNightBlue = Color(0xFF0A1C2C);
const _partyBlueRaised = Color(0xFF102A3E);
const _partyOrange = Color(0xFFE47A32);
const _partyOrangeSoft = Color(0xFFF0A060);
const _partyMutedBlue = Color(0xFF7892A7);

class PartyPerformanceScreen extends ConsumerStatefulWidget {
  final String roomCode;

  const PartyPerformanceScreen({super.key, required this.roomCode});

  @override
  ConsumerState<PartyPerformanceScreen> createState() =>
      _PartyPerformanceScreenState();
}

class _PartyPerformanceScreenState extends ConsumerState<PartyPerformanceScreen>
    with WidgetsBindingObserver {
  final TextEditingController _resultController = TextEditingController();
  Timer? _timer;
  CameraController? _cameraController;
  int _secondsRemaining = 60;
  int? _timerStateVersion;
  bool _isBootstrapping = true;
  bool _isOpeningCamera = false;
  bool _isCapturing = false;
  bool _showCamera = false;
  bool _captureFlash = false;
  bool _routeScheduled = false;
  bool _snapshotSyncScheduled = false;
  bool _isRefreshingSnapshot = false;
  bool _refreshRequested = false;
  bool _isActive = true;
  bool _isDisposed = false;
  String? _cameraError;
  List<CameraDescription> _availableCameras = const [];
  int _cameraIndex = 0;
  List<Player> _players = const [];
  PartySnapshot? _pendingSnapshot;
  late final PartySessionNotifier _partySession;
  late final RealtimeService _realtimeService;

  bool get _canUseRef => mounted && _isActive && !_isDisposed;

  @override
  void initState() {
    super.initState();
    _partySession = ref.read(partySessionProvider.notifier);
    _realtimeService = ref.read(realtimeServiceProvider);
    final cachedSnapshot = ref.read(partySessionProvider).snapshot;
    if (cachedSnapshot?.room.code == widget.roomCode) {
      _isBootstrapping = false;
      _pendingSnapshot = cachedSnapshot;
    }
    WidgetsBinding.instance.addObserver(this);
    unawaited(_bootstrap());
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
    super.deactivate();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _isActive = false;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _resultController.dispose();
    unawaited(_cameraController?.dispose());
    unawaited(_realtimeService.leaveRoom(widget.roomCode));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_disposeCamera());
      return;
    }
    if (state == AppLifecycleState.resumed) {
      if (!_canUseRef) return;
      final room = ref.read(currentRoomProvider);
      if (room != null) {
        unawaited(_refreshSnapshot(room.id));
      }
      if (_showCamera && _cameraController == null) {
        unawaited(_openCamera());
      }
    }
  }

  Future<void> _bootstrap() async {
    try {
      if (!_canUseRef) return;
      final roomService = ref.read(roomServiceProvider);
      final playerService = ref.read(playerServiceProvider);
      var room = ref.read(currentRoomProvider);
      if (room == null || room.code != widget.roomCode) {
        room = await roomService.findRoomByCode(widget.roomCode);
        if (!_canUseRef) return;
        if (room == null) throw StateError('Party room not found.');
        ref.read(currentRoomProvider.notifier).set(room);
      }
      if (room.gameMode != GameMode.party) {
        _goToGame();
        return;
      }

      unawaited(() async {
        try {
          await roomService.synchronizeServerClock();
        } catch (_) {}
      }());
      final playerFuture = playerService.getPlayers(room.id);
      final snapshotFuture = _partySession.load(room.id);
      _players = await playerFuture;
      if (!_canUseRef) return;
      _restoreCurrentPlayer(room.id);
      final snapshot = await snapshotFuture;
      if (!_canUseRef) return;
      if (snapshot != null) _queueSnapshotSync(snapshot);
      if (_isBootstrapping) setState(() => _isBootstrapping = false);
      unawaited(_setupRealtime(room.id));
    } catch (error, stackTrace) {
      debugPrint('Party performance bootstrap failed: $error\n$stackTrace');
    } finally {
      if (_canUseRef) setState(() => _isBootstrapping = false);
    }
  }

  Player? _restoreCurrentPlayer(String roomId) {
    if (!_canUseRef) return null;
    final current = ref.read(currentPlayerProvider);
    if (current != null && current.roomId == roomId) return current;
    final deviceId = ref.read(deviceIdProvider);
    for (final player in _players) {
      if (player.roomId == roomId && player.deviceId == deviceId) {
        ref.read(currentPlayerProvider.notifier).set(player);
        return player;
      }
    }
    return null;
  }

  Future<void> _setupRealtime(String roomId) async {
    if (!_canUseRef) return;
    try {
      await _realtimeService.joinRoom(
        widget.roomCode,
        roomId: roomId,
        onPhaseChange: (_) => unawaited(_refreshSnapshot(roomId)),
        onGuessSubmitted: (_) {},
        onGuessesRevealed: (_) {},
        onBetPlaced: (_) {},
        onBetRemoved: (_) {},
        onScoreUpdate: (_) {},
        onAnswerRevealed: (_) {},
        onGameStarted: (_) => unawaited(_refreshSnapshot(roomId)),
        onGameEnded: (_) {
          if (_canUseRef) _scheduleRoute('results');
        },
        onRoomRowChanged: (_) => unawaited(_refreshSnapshot(roomId)),
      );
    } catch (error, stackTrace) {
      debugPrint('Party performance realtime failed: $error\n$stackTrace');
    }
  }

  Future<void> _refreshSnapshot(String roomId) async {
    if (!_canUseRef) return;
    if (_isRefreshingSnapshot) {
      _refreshRequested = true;
      return;
    }
    _isRefreshingSnapshot = true;
    _refreshRequested = false;
    try {
      final snapshot = await _partySession.load(roomId);
      if (_canUseRef && snapshot != null) _queueSnapshotSync(snapshot);
    } finally {
      _isRefreshingSnapshot = false;
      if (_refreshRequested && _canUseRef) {
        _refreshRequested = false;
        unawaited(_refreshSnapshot(roomId));
      }
    }
  }

  void _queueSnapshotSync(PartySnapshot snapshot) {
    if (!_canUseRef) return;
    _pendingSnapshot = snapshot;
    if (_snapshotSyncScheduled) return;
    _snapshotSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _snapshotSyncScheduled = false;
      final pending = _pendingSnapshot;
      _pendingSnapshot = null;
      if (!_canUseRef || pending == null) return;
      _syncSnapshot(pending);
    });
  }

  void _syncSnapshot(PartySnapshot snapshot) {
    if (!_canUseRef) return;
    ref.read(currentRoomProvider.notifier).set(snapshot.room);
    if (snapshot.room.status == RoomStatus.finished) {
      _scheduleRoute('results');
      return;
    }
    switch (snapshot.round.phase) {
      case PartyRoundPhase.guessing:
      case PartyRoundPhase.betting:
      case PartyRoundPhase.reveal:
        _scheduleRoute('game');
        break;
      case PartyRoundPhase.action:
        _startActionTimer(snapshot);
        break;
      case PartyRoundPhase.ready:
      case PartyRoundPhase.resultEntry:
      case PartyRoundPhase.resultConfirm:
        _stopTimer();
        break;
    }
  }

  void _scheduleRoute(String routeName) {
    if (_routeScheduled || !_canUseRef) return;
    _routeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeScheduled = false;
      if (!_canUseRef) return;
      context.goNamed(routeName, pathParameters: {'roomCode': widget.roomCode});
    });
  }

  void _goToGame() => _scheduleRoute('game');

  void _startActionTimer(PartySnapshot snapshot) {
    if (_timerStateVersion == snapshot.stateVersion && _timer != null) return;
    _timerStateVersion = snapshot.stateVersion;
    _timer?.cancel();
    final deadline = snapshot.round.phaseEndsAt;
    _secondsRemaining = deadline == null
        ? snapshot.round.challenge.durationSeconds
        : _remainingSeconds(deadline);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_canUseRef) {
        timer.cancel();
        return;
      }
      final latest = ref.read(partySessionProvider).snapshot;
      final latestDeadline = latest?.round.phaseEndsAt;
      final remaining = latestDeadline == null
          ? (_secondsRemaining - 1).clamp(
              0,
              snapshot.round.challenge.durationSeconds,
            )
          : _remainingSeconds(latestDeadline);
      setState(() => _secondsRemaining = remaining);
      if (remaining > 0) return;
      timer.cancel();
      _timer = null;
      if (ref.read(isHostProvider) && latest != null) {
        unawaited(
          _runCommand((service) => service.openResultEntry(latest.room.id)),
        );
      }
    });
    if (_canUseRef) setState(() {});
  }

  int _remainingSeconds(DateTime deadline) {
    final difference = deadline
        .difference(ref.read(roomServiceProvider).serverNow)
        .inMilliseconds;
    if (difference <= 0) return 0;
    return (difference / 1000).ceil();
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _timerStateVersion = null;
  }

  Future<void> _runCommand(
    Future<PartySnapshot> Function(PartyGameService service) command,
  ) async {
    if (!_canUseRef) return;
    final snapshot = await _partySession.runCommand(command);
    if (!_canUseRef) return;
    if (snapshot == null) {
      final error = ref.read(partySessionProvider).errorMessage;
      _showMessage(error ?? 'Could not continue. Try again.');
      return;
    }
    _queueSnapshotSync(snapshot);
    unawaited(
      _realtimeService.broadcast(widget.roomCode, 'phase_change', {
        'phase': snapshot.round.phase.gamePhase.name,
        'round': snapshot.round.number,
        'state_version': snapshot.stateVersion,
        'phase_ends_at': snapshot.round.phaseEndsAt?.toIso8601String(),
      }),
    );
  }

  Future<void> _enterCamera() async {
    if (!_canUseRef) return;
    setState(() {
      _showCamera = true;
      _cameraError = null;
    });
    await _openCamera();
  }

  Future<void> _closeCamera() async {
    if (!_canUseRef) return;
    setState(() => _showCamera = false);
    await _disposeCamera();
  }

  Future<void> _openCamera({int? cameraIndex}) async {
    if (!_canUseRef || _isOpeningCamera || _cameraController != null) return;
    CameraController? openingController;
    setState(() {
      _isOpeningCamera = true;
      _cameraError = null;
    });
    try {
      final cameras = _availableCameras.isEmpty
          ? await availableCameras()
          : _availableCameras;
      if (cameras.isEmpty) throw StateError('No camera is available.');
      _availableCameras = cameras;
      if (cameraIndex != null) {
        _cameraIndex = cameraIndex.clamp(0, cameras.length - 1);
      } else {
        final backIndex = cameras.indexWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
        );
        _cameraIndex = backIndex < 0 ? 0 : backIndex;
      }
      final selected = cameras[_cameraIndex];
      openingController = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await openingController.initialize().timeout(const Duration(seconds: 12));
      if (!_canUseRef || !_showCamera) {
        await openingController.dispose();
        openingController = null;
        return;
      }
      _cameraController = openingController;
      openingController = null;
    } on CameraException catch (error) {
      _cameraError =
          error.code == 'CameraAccessDenied' ||
              error.code == 'CameraAccessDeniedWithoutPrompt'
          ? 'Camera access is off. Allow it in your browser or phone settings, then try again.'
          : 'Camera could not start (${error.code}).';
    } on TimeoutException {
      _cameraError = 'Camera took too long to start. Close it and try again.';
    } catch (error) {
      _cameraError = 'Camera could not start. $error';
    } finally {
      if (openingController != null) {
        await openingController.dispose();
      }
      if (_canUseRef) setState(() => _isOpeningCamera = false);
    }
  }

  Future<void> _switchCamera() async {
    if (_availableCameras.length < 2 || _isOpeningCamera) return;
    final nextIndex = (_cameraIndex + 1) % _availableCameras.length;
    await _disposeCamera();
    if (!_canUseRef || !_showCamera) return;
    await _openCamera(cameraIndex: nextIndex);
  }

  Future<void> _disposeCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) await controller.dispose();
    if (_canUseRef) setState(() {});
  }

  Future<void> _captureMoment(PartySnapshot snapshot) async {
    if (!_canUseRef) return;
    final controller = _cameraController;
    final player = ref.read(currentPlayerProvider);
    final currentMoments = _momentsForRound(snapshot.round.number);
    if (controller == null ||
        !controller.value.isInitialized ||
        player == null ||
        _isCapturing ||
        currentMoments.length >= 3) {
      return;
    }
    setState(() => _isCapturing = true);
    try {
      HapticFeedback.mediumImpact();
      final photo = await controller.takePicture();
      if (_canUseRef) {
        setState(() => _captureFlash = true);
        Timer(const Duration(milliseconds: 110), () {
          if (_canUseRef) setState(() => _captureFlash = false);
        });
      }
      final Uint8List bytes = await photo.readAsBytes();
      ref
          .read(partyLocalMediaProvider.notifier)
          .add(
            roomId: snapshot.room.id,
            roundNumber: snapshot.round.number,
            playerId: player.id,
            playerName: player.name,
            playerColor: player.avatarColor,
            bytes: bytes,
          );
      if (!_canUseRef) return;
      HapticFeedback.heavyImpact();
    } finally {
      if (_canUseRef) setState(() => _isCapturing = false);
    }
  }

  List<PartyMoment> _momentsForRound(int round) {
    return ref
        .read(partyLocalMediaProvider)
        .where((moment) {
          final playerId = ref.read(currentPlayerProvider)?.id;
          return moment.roundNumber == round &&
              moment.uploaderPlayerId == playerId;
        })
        .toList(growable: false);
  }

  void _showMessage(String message) {
    if (!_canUseRef) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isRequiredConfirmer(PartyRoundSnapshot round, Player? currentPlayer) {
    final hostId = _players.where((player) => player.isHost).firstOrNull?.id;
    final requiredId = round.performer.id == hostId
        ? round.witness?.id
        : round.performer.id;
    return currentPlayer?.id == requiredId;
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(currentRoomProvider);
    if (room != null) {
      ref.listen(roomStreamProvider(room.id), (_, next) {
        if (!_canUseRef) return;
        final rows = next.asData?.value;
        if (rows == null || rows.isEmpty) return;
        final updatedRoom = Room.fromJson(rows.first);
        unawaited(_refreshSnapshot(updatedRoom.id));
      });
    }

    ref.listen(partySessionProvider.select((state) => state.snapshot), (
      _,
      snapshot,
    ) {
      if (snapshot != null) _queueSnapshotSync(snapshot);
    });

    final session = ref.watch(partySessionProvider);
    final snapshot = session.snapshot;
    if (_isBootstrapping || snapshot == null) {
      return _buildLoading(session.errorMessage);
    }

    final round = snapshot.round;
    final currentPlayer = ref.watch(currentPlayerProvider);
    final isHost = currentPlayer?.isHost == true;
    final isPerformer = currentPlayer?.id == round.performer.id;
    final moments = ref
        .watch(partyLocalMediaProvider)
        .where(
          (moment) =>
              moment.roomId == snapshot.room.id &&
              moment.roundNumber == round.number &&
              moment.uploaderPlayerId == currentPlayer?.id,
        )
        .toList(growable: false);

    if (_showCamera) {
      return _buildFullScreenCamera(snapshot: snapshot, moments: moments);
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _partyNight,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_partyNightBlue, _partyNight, Color(0xFF03070D)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
                  child: _buildMinimalRoleStage(
                    snapshot: snapshot,
                    currentPlayer: currentPlayer,
                    isHost: isHost,
                    isPerformer: isPerformer,
                    moments: moments,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalRoleStage({
    required PartySnapshot snapshot,
    required Player? currentPlayer,
    required bool isHost,
    required bool isPerformer,
    required List<PartyMoment> moments,
  }) {
    final round = snapshot.round;
    final roleLabel = isPerformer
        ? 'YOU ARE UP'
        : isHost
        ? 'HOST CONTROL'
        : 'WATCH & CAPTURE';
    final phaseLabel = switch (round.phase) {
      PartyRoundPhase.ready => 'GET READY',
      PartyRoundPhase.action => 'LIVE',
      PartyRoundPhase.resultEntry => 'TIME IS UP',
      PartyRoundPhase.resultConfirm => 'FINAL CHECK',
      _ => 'PARTY MODE',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              roleLabel,
              style: GoogleFonts.outfit(
                color: _partyOrangeSoft,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.7,
              ),
            ),
            const Spacer(),
            Text(
              '${round.number} / ${snapshot.turnCount}',
              style: GoogleFonts.outfit(
                color: AppColors.ivory.withValues(alpha: 0.46),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const Spacer(flex: 2),
        Text(
          phaseLabel,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: round.phase == PartyRoundPhase.action
                ? _partyOrangeSoft
                : AppColors.ivory.withValues(alpha: 0.48),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.4,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          round.challenge.text,
          textAlign: TextAlign.center,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'RehnCondensed',
            color: AppColors.ivory,
            fontSize: 46,
            fontWeight: FontWeight.w900,
            height: 0.94,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          round.challenge.rules,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            color: AppColors.ivory.withValues(alpha: 0.58),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
        const Spacer(),
        if (round.phase == PartyRoundPhase.action) ...[
          _buildMinimalTimer(),
          const SizedBox(height: 22),
        ],
        _buildMinimalRoleControls(
          snapshot: snapshot,
          currentPlayer: currentPlayer,
          isHost: isHost,
          isPerformer: isPerformer,
          moments: moments,
        ),
      ],
    );
  }

  Widget _buildMinimalTimer({bool compact = false}) {
    final urgent = _secondsRemaining <= 10;
    final duration =
        ref
            .read(partySessionProvider)
            .snapshot
            ?.round
            .challenge
            .durationSeconds ??
        60;
    final progress = (_secondsRemaining / duration).clamp(0.0, 1.0);
    final size = compact ? 84.0 : 142.0;
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: compact ? 4 : 5,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              color: urgent ? const Color(0xFFE94B35) : _partyOrange,
              strokeCap: StrokeCap.round,
            ),
            Center(
              child: Text(
                '00:${_secondsRemaining.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontFamily: 'RehnCondensed',
                  color: AppColors.ivory,
                  fontSize: compact ? 28 : 46,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalRoleControls({
    required PartySnapshot snapshot,
    required Player? currentPlayer,
    required bool isHost,
    required bool isPerformer,
    required List<PartyMoment> moments,
  }) {
    final round = snapshot.round;
    final canConfirm = _isRequiredConfirmer(round, currentPlayer);
    final canOpenCamera = !isPerformer && moments.length < 3;
    final cameraButton = canOpenCamera
        ? _secondaryButton(
            label: moments.isEmpty
                ? 'SAVE A MOMENT'
                : 'SAVE ANOTHER  ${moments.length}/3',
            icon: Icons.photo_camera_outlined,
            onPressed: _enterCamera,
          )
        : null;

    switch (round.phase) {
      case PartyRoundPhase.ready:
        if (isPerformer && !round.performerReady) {
          return _primaryButton(
            label: 'I AM READY',
            icon: Icons.check_rounded,
            onPressed: () => _runCommand(
              (service) => service.markPerformerReady(snapshot.room.id),
            ),
          );
        }
        if (isHost && round.performerReady) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _primaryButton(
                label: 'START ${round.challenge.durationSeconds} SECONDS',
                icon: Icons.play_arrow_rounded,
                onPressed: () => _runCommand(
                  (service) => service.startAction(snapshot.room.id),
                ),
              ),
              if (cameraButton != null) ...[
                const SizedBox(height: 10),
                cameraButton,
              ],
            ],
          );
        }
        return Column(
          children: [
            _minimalStatus(
              round.performerReady
                  ? 'Waiting for the host'
                  : 'Waiting for ${round.performer.name}',
            ),
            if (cameraButton != null) ...[
              const SizedBox(height: 18),
              cameraButton,
            ],
          ],
        );
      case PartyRoundPhase.action:
        return Column(
          children: [
            _minimalStatus(
              isPerformer
                  ? 'Go. Give it your best shot.'
                  : isHost
                  ? (round.challenge.isBinary
                        ? 'Watch the success condition.'
                        : 'Keep the count clean.')
                  : 'Catch the moment, not the pose.',
            ),
            if (cameraButton != null) ...[
              const SizedBox(height: 18),
              cameraButton,
            ],
          ],
        );
      case PartyRoundPhase.resultEntry:
        if (isHost) return _buildMinimalResultEntry(snapshot);
        return Column(
          children: [
            _minimalStatus('The host is entering the result'),
            if (cameraButton != null) ...[
              const SizedBox(height: 18),
              cameraButton,
            ],
          ],
        );
      case PartyRoundPhase.resultConfirm:
        if (canConfirm) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                round.challenge.isBinary
                    ? (round.proposedResult == 1 ? 'SUCCESS' : 'FAILED')
                    : '${round.proposedResult ?? '—'} ${round.challenge.answerUnit}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'RehnCondensed',
                  color: _partyOrangeSoft,
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _primaryButton(
                      label: 'CONFIRM',
                      icon: Icons.check_rounded,
                      onPressed: () => _runCommand(
                        (service) => service.confirmResult(snapshot.room.id),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _secondaryButton(
                      label: 'CORRECT',
                      icon: Icons.edit_outlined,
                      onPressed: () => _runCommand(
                        (service) => service.disputeResult(snapshot.room.id),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        }
        return Column(
          children: [
            _minimalStatus('Waiting for score confirmation'),
            if (cameraButton != null) ...[
              const SizedBox(height: 18),
              cameraButton,
            ],
          ],
        );
      case PartyRoundPhase.guessing:
      case PartyRoundPhase.betting:
      case PartyRoundPhase.reveal:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMinimalResultEntry(PartySnapshot snapshot) {
    final round = snapshot.round;
    if (round.challenge.isBinary) {
      return Row(
        children: [
          Expanded(
            child: _secondaryButton(
              label: 'FAILED',
              icon: Icons.close_rounded,
              onPressed: () => _runCommand(
                (service) =>
                    service.submitResult(roomId: snapshot.room.id, result: 0),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _primaryButton(
              label: 'SUCCESS',
              icon: Icons.check_rounded,
              onPressed: () => _runCommand(
                (service) =>
                    service.submitResult(roomId: snapshot.room.id, result: 1),
              ),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _resultController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'RehnCondensed',
              color: AppColors.ivory,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
            decoration: InputDecoration(
              hintText: '0–${round.challenge.maxResult}',
              hintStyle: TextStyle(
                color: AppColors.ivory.withValues(alpha: 0.28),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: AppColors.ivory.withValues(alpha: 0.28),
                ),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: _partyOrange, width: 2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        IconButton.filled(
          onPressed: () {
            final value = int.tryParse(_resultController.text);
            if (value == null ||
                value < 0 ||
                value > round.challenge.maxResult) {
              return;
            }
            _runCommand(
              (service) =>
                  service.submitResult(roomId: snapshot.room.id, result: value),
            );
          },
          icon: const Icon(Icons.arrow_forward_rounded),
          style: IconButton.styleFrom(
            backgroundColor: _partyOrange,
            foregroundColor: _partyNight,
            minimumSize: const Size(58, 58),
          ),
        ),
      ],
    );
  }

  Widget _minimalStatus(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.outfit(
        color: AppColors.ivory.withValues(alpha: 0.58),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildFullScreenCamera({
    required PartySnapshot snapshot,
    required List<PartyMoment> moments,
  }) {
    final controller = _cameraController;
    final round = snapshot.round;
    final captureIsOpen =
        round.phase == PartyRoundPhase.action ||
        round.phase == PartyRoundPhase.resultEntry ||
        round.phase == PartyRoundPhase.resultConfirm;
    final canCapture =
        captureIsOpen &&
        moments.length < 3 &&
        !_isCapturing &&
        controller != null &&
        controller.value.isInitialized;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_closeCamera());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (controller != null && controller.value.isInitialized)
              CameraPreview(controller)
            else
              _buildCameraLoading(),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.28, 0.66, 1],
                  colors: [
                    Color(0xB8000000),
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xD9000000),
                  ],
                ),
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _CameraFramePainter()),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          onPressed: _closeCamera,
                          icon: const Icon(Icons.close_rounded),
                          color: Colors.white,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black38,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${round.performer.name.toUpperCase()}’S CHALLENGE',
                                style: GoogleFonts.outfit(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                round.challenge.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (round.phase == PartyRoundPhase.action)
                          _buildMinimalTimer(compact: true),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      captureIsOpen
                          ? moments.isEmpty
                                ? 'Save the moment'
                                : '${moments.length} of 3 saved'
                          : 'The shutter unlocks when the timer starts',
                      style: GoogleFonts.outfit(
                        color: captureIsOpen
                            ? _partyOrangeSoft
                            : Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        SizedBox(
                          width: 62,
                          height: 62,
                          child: moments.isEmpty
                              ? const SizedBox.shrink()
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    moments.last.bytes,
                                    fit: BoxFit.cover,
                                    cacheWidth: 240,
                                  ),
                                ),
                        ),
                        Expanded(
                          child: Center(
                            child: GestureDetector(
                              onTap: canCapture
                                  ? () => _captureMoment(snapshot)
                                  : null,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 82,
                                height: 82,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: canCapture
                                      ? _partyOrange
                                      : Colors.white24,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 5,
                                  ),
                                  boxShadow: canCapture
                                      ? const [
                                          BoxShadow(
                                            color: Colors.black54,
                                            blurRadius: 16,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: _isCapturing
                                    ? const Padding(
                                        padding: EdgeInsets.all(25),
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Icon(
                                        moments.length >= 3
                                            ? Icons.check_rounded
                                            : Icons.camera_alt_rounded,
                                        color: canCapture
                                            ? _partyNight
                                            : Colors.white54,
                                        size: 32,
                                      ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 62,
                          child: IconButton(
                            onPressed: _availableCameras.length > 1
                                ? _switchCamera
                                : null,
                            icon: const Icon(Icons.cameraswitch_rounded),
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _captureFlash ? 1 : 0,
                  duration: const Duration(milliseconds: 90),
                  child: const ColoredBox(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isOpeningCamera)
              const CircularProgressIndicator(color: _partyOrange)
            else
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white54,
                size: 38,
              ),
            const SizedBox(height: 18),
            Text(
              _cameraError ?? 'Starting camera…',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            if (_cameraError != null) ...[
              const SizedBox(height: 18),
              TextButton(
                onPressed: _isOpeningCamera ? null : _openCamera,
                child: const Text('TRY AGAIN'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Kept as a rollback-safe reference until the minimal Party screen is
  // validated on physical devices.
  // ignore: unused_element
  (Widget, Widget) _buildContent({
    required PartySnapshot snapshot,
    required Player? currentPlayer,
    required bool isHost,
    required bool isPerformer,
    required List<PartyMoment> moments,
  }) {
    final round = snapshot.round;
    final phaseLabel = switch (round.phase) {
      PartyRoundPhase.ready => 'GET IN POSITION',
      PartyRoundPhase.action => 'LIVE CHALLENGE',
      PartyRoundPhase.resultEntry => 'TIME’S UP',
      PartyRoundPhase.resultConfirm => 'CONFIRM THE SCORE',
      _ => 'PARTY CHALLENGE',
    };

    final missionPanel = _PerformancePanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: _partyOrangeSoft, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  phaseLabel,
                  style: GoogleFonts.outfit(
                    color: _partyOrangeSoft,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              Text(
                'ROUND ${round.number}/${snapshot.turnCount}',
                style: GoogleFonts.outfit(
                  color: AppColors.ivory.withValues(alpha: 0.62),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            round.challenge.text,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'RehnCondensed',
              color: AppColors.ivory,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 0.94,
              shadows: const [Shadow(color: Colors.black87, blurRadius: 10)],
            ),
          ),
          const SizedBox(height: 7),
          Text(
            round.challenge.rules,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: AppColors.ivory.withValues(alpha: 0.76),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.18,
            ),
          ),
          const Spacer(),
          if (round.phase == PartyRoundPhase.action)
            _buildLiveTimer()
          else
            _buildPhaseControls(
              snapshot: snapshot,
              currentPlayer: currentPlayer,
              isHost: isHost,
            ),
        ],
      ),
    );

    final sidePanel =
        !isPerformer &&
            (round.phase == PartyRoundPhase.ready ||
                round.phase == PartyRoundPhase.action ||
                round.phase == PartyRoundPhase.resultEntry ||
                round.phase == PartyRoundPhase.resultConfirm)
        ? _buildCameraPanel(snapshot, moments)
        : _buildAudiencePanel(
            snapshot: snapshot,
            currentPlayer: currentPlayer,
            isPerformer: isPerformer,
            moments: moments,
          );

    return (missionPanel, sidePanel);
  }

  Widget _buildLiveTimer() {
    final urgent = _secondsRemaining <= 10;
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: urgent
              ? const [Color(0xFF5B2415), Color(0xFF1B1010)]
              : const [_partyBlueRaised, _partyNightBlue],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: urgent ? _partyOrange : _partyMutedBlue,
          width: 1.4,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '$_secondsRemaining',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'RehnCondensed',
              color: urgent ? Colors.white : _partyOrangeSoft,
              fontSize: 58,
              fontWeight: FontWeight.w900,
              height: 0.82,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'SECONDS\nLEFT',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: AppColors.ivory.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseControls({
    required PartySnapshot snapshot,
    required Player? currentPlayer,
    required bool isHost,
  }) {
    final round = snapshot.round;
    switch (round.phase) {
      case PartyRoundPhase.ready:
        return Column(
          children: [
            Text(
              isHost
                  ? 'Make sure ${round.performer.name} is ready.'
                  : 'Waiting for the host to start the timer.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: AppColors.ivory.withValues(alpha: 0.78),
                fontWeight: FontWeight.w700,
              ),
            ),
            if (isHost) ...[
              const SizedBox(height: 14),
              _primaryButton(
                label: 'START ${round.challenge.durationSeconds} SECONDS',
                icon: Icons.play_arrow_rounded,
                onPressed: () => _runCommand(
                  (service) => service.startAction(snapshot.room.id),
                ),
              ),
            ],
          ],
        );
      case PartyRoundPhase.resultEntry:
        if (!isHost) {
          return _waitingPill('HOST IS ENTERING THE RESULT');
        }
        return _buildMinimalResultEntry(snapshot);
      case PartyRoundPhase.resultConfirm:
        final canConfirm = _isRequiredConfirmer(round, currentPlayer);
        if (!canConfirm) return _waitingPill('WAITING FOR SCORE CONFIRMATION');
        return Column(
          children: [
            Text(
              round.challenge.isBinary
                  ? (round.proposedResult == 1 ? 'SUCCESS' : 'FAILED')
                  : '${round.proposedResult ?? '—'} ${round.challenge.answerUnit}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'RehnCondensed',
                color: _partyOrangeSoft,
                fontSize: 46,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _primaryButton(
                    label: 'CONFIRM',
                    icon: Icons.verified_rounded,
                    onPressed: () => _runCommand(
                      (service) => service.confirmResult(snapshot.room.id),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _secondaryButton(
                    label: 'CORRECT',
                    icon: Icons.edit_rounded,
                    onPressed: () => _runCommand(
                      (service) => service.disputeResult(snapshot.room.id),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      case PartyRoundPhase.guessing:
      case PartyRoundPhase.betting:
      case PartyRoundPhase.action:
      case PartyRoundPhase.reveal:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAudiencePanel({
    required PartySnapshot snapshot,
    required Player? currentPlayer,
    required bool isPerformer,
    required List<PartyMoment> moments,
  }) {
    final round = snapshot.round;
    final title = isPerformer ? 'YOU’RE UP' : 'GET THE ROOM READY';
    final body = switch (round.phase) {
      PartyRoundPhase.ready =>
        isPerformer
            ? 'Take your position. The host starts the clock when the room is ready.'
            : 'Clear some space, get the camera ready, and cheer them on.',
      PartyRoundPhase.resultEntry =>
        'Keep the best moments. The host is entering what happened.',
      PartyRoundPhase.resultConfirm =>
        'One final check, then the bets and scores are revealed.',
      _ => 'The next moment could become the party recap.',
    };
    return _PerformancePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            isPerformer
                ? Icons.sports_gymnastics_rounded
                : Icons.groups_rounded,
            color: _partyMutedBlue,
            size: 48,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'RehnCondensed',
              color: AppColors.ivory,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: AppColors.ivory.withValues(alpha: 0.74),
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const Spacer(),
          if (moments.isNotEmpty) _buildMomentStrip(moments),
          if (moments.isEmpty) _waitingPill('UP TO 3 PARTY MOMENTS THIS ROUND'),
        ],
      ),
    );
  }

  Widget _buildCameraPanel(PartySnapshot snapshot, List<PartyMoment> moments) {
    final controller = _cameraController;
    final full = moments.length >= 3;
    final captureIsOpen =
        snapshot.round.phase == PartyRoundPhase.action ||
        snapshot.round.phase == PartyRoundPhase.resultEntry ||
        snapshot.round.phase == PartyRoundPhase.resultConfirm;
    final canCapture =
        captureIsOpen &&
        !full &&
        !_isCapturing &&
        controller != null &&
        controller.value.isInitialized;

    return _PerformancePanel(
      padding: const EdgeInsets.all(7),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            if (controller != null && controller.value.isInitialized)
              _buildCameraPreview(controller)
            else
              _buildCameraPlaceholder(full),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, 0.45, 1],
                    colors: [
                      Color(0x66000000),
                      Colors.transparent,
                      Color(0xD9000000),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: Row(
                children: [
                  _cameraBadge(
                    captureIsOpen ? 'CAMERA LIVE' : 'READY CAMERA',
                    icon: captureIsOpen
                        ? Icons.fiber_manual_record_rounded
                        : Icons.videocam_outlined,
                    accent: captureIsOpen ? _partyOrange : _partyMutedBlue,
                  ),
                  const Spacer(),
                  _cameraBadge('${moments.length}/3 MOMENTS'),
                ],
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          captureIsOpen
                              ? 'SAVE THE MOMENT'
                              : 'OPEN NOW, SHOOT WHEN THE TIMER STARTS',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: AppColors.ivory,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                        const SizedBox(height: 7),
                        _buildMomentStrip(moments),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: IconButton.filled(
                      onPressed: canCapture
                          ? () => _captureMoment(snapshot)
                          : null,
                      icon: _isCapturing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : Icon(
                              full
                                  ? Icons.check_rounded
                                  : captureIsOpen
                                  ? Icons.camera_rounded
                                  : Icons.timer_outlined,
                              size: 32,
                            ),
                      style: IconButton.styleFrom(
                        backgroundColor: _partyOrange,
                        disabledBackgroundColor: full
                            ? _partyBlueRaised.withValues(alpha: 0.92)
                            : Colors.white.withValues(alpha: 0.18),
                        foregroundColor: AppColors.ink,
                        disabledForegroundColor: AppColors.ivory.withValues(
                          alpha: 0.68,
                        ),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.72),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview(CameraController controller) {
    return CameraPreview(controller);
  }

  Widget _buildCameraPlaceholder(bool full) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 110),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _partyMutedBlue.withValues(alpha: 0.12),
                border: Border.all(
                  color: _partyMutedBlue.withValues(alpha: 0.64),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.photo_camera_rounded,
                color: _partyMutedBlue,
                size: 36,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _cameraError ?? 'Frame the challenge and keep the best moment.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: AppColors.ivory,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            if (_cameraError == null && !full) ...[
              const SizedBox(height: 16),
              _primaryButton(
                label: _isOpeningCamera ? 'OPENING...' : 'OPEN CAMERA',
                icon: Icons.camera_alt_rounded,
                onPressed: _isOpeningCamera ? null : _openCamera,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMomentStrip(List<PartyMoment> moments) {
    if (moments.isEmpty) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: const Center(
          child: Icon(
            Icons.add_photo_alternate_outlined,
            color: Colors.white38,
          ),
        ),
      );
    }
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          for (final moment in moments.take(3))
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    moment.bytes,
                    fit: BoxFit.cover,
                    cacheWidth: 240,
                  ),
                ),
              ),
            ),
          for (var index = moments.length; index < 3; index++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cameraBadge(
    String text, {
    IconData? icon,
    Color accent = _partyOrangeSoft,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: accent, size: 12),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: GoogleFonts.outfit(
              color: AppColors.ivory,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _waitingPill(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _partyOrange.withValues(alpha: 0.42)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(
          color: _partyOrangeSoft,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.7,
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final busy = ref.watch(
      partySessionProvider.select((state) => state.isCommandRunning),
    );
    return FilledButton.icon(
      onPressed: busy ? null : onPressed,
      icon: Icon(icon),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: _partyOrange,
        foregroundColor: _partyNight,
        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w900),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _secondaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final busy = ref.watch(
      partySessionProvider.select((state) => state.isCommandRunning),
    );
    return OutlinedButton.icon(
      onPressed: busy ? null : onPressed,
      icon: Icon(icon),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        foregroundColor: AppColors.ivory,
        side: BorderSide(color: AppColors.ivory.withValues(alpha: 0.24)),
        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w900),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildLoading(String? error) {
    return Scaffold(
      backgroundColor: _partyNight,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: error == null
              ? const CircularProgressIndicator(color: _partyOrange)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      color: _partyOrangeSoft,
                      size: 42,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Could not load the live challenge.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: AppColors.ivory,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _bootstrap,
                      child: const Text('TRY AGAIN'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PerformancePanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _PerformancePanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _partyNightBlue.withValues(alpha: 0.98),
            _partyBlueRaised.withValues(alpha: 0.96),
            _partyNight.withValues(alpha: 0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: _partyOrange.withValues(alpha: 0.58),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CameraFramePainter extends CustomPainter {
  const _CameraFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    const inset = 18.0;
    const length = 38.0;
    final left = inset;
    final right = size.width - inset;
    final top = inset;
    final bottom = size.height - inset;

    final path = Path()
      ..moveTo(left, top + length)
      ..lineTo(left, top)
      ..lineTo(left + length, top)
      ..moveTo(right - length, top)
      ..lineTo(right, top)
      ..lineTo(right, top + length)
      ..moveTo(right, bottom - length)
      ..lineTo(right, bottom)
      ..lineTo(right - length, bottom)
      ..moveTo(left + length, bottom)
      ..lineTo(left, bottom)
      ..lineTo(left, bottom - length);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CameraFramePainter oldDelegate) => false;
}
