import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/game_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_asset_image.dart';
import '../../player/models/player_model.dart';
import '../../room/models/room_model.dart';
import '../../room/providers/room_providers.dart';
import '../models/party_moment.dart';
import '../models/party_snapshot.dart';
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
  bool _routeScheduled = false;
  String? _cameraError;
  List<Player> _players = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _resultController.dispose();
    unawaited(_cameraController?.dispose());
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
      final room = ref.read(currentRoomProvider);
      if (room != null) {
        unawaited(
          ref
              .read(partySessionProvider.notifier)
              .load(room.id, loadMoments: true),
        );
      }
    }
  }

  Future<void> _bootstrap() async {
    try {
      var room = ref.read(currentRoomProvider);
      if (room == null || room.code != widget.roomCode) {
        room = await ref
            .read(roomServiceProvider)
            .findRoomByCode(widget.roomCode);
        if (room == null) throw StateError('Party room not found.');
        ref.read(currentRoomProvider.notifier).set(room);
      }
      if (room.gameMode != GameMode.party) {
        _goToGame();
        return;
      }

      try {
        await ref.read(roomServiceProvider).synchronizeServerClock();
      } catch (_) {}
      _players = await ref.read(playerServiceProvider).getPlayers(room.id);
      _restoreCurrentPlayer(room.id);
      final snapshot = await ref
          .read(partySessionProvider.notifier)
          .load(room.id, loadMoments: true);
      if (snapshot != null) _syncSnapshot(snapshot);
    } catch (error, stackTrace) {
      debugPrint('Party performance bootstrap failed: $error\n$stackTrace');
    } finally {
      if (mounted) setState(() => _isBootstrapping = false);
    }
  }

  Player? _restoreCurrentPlayer(String roomId) {
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

  void _syncSnapshot(PartySnapshot snapshot) {
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
    if (_routeScheduled || !mounted) return;
    _routeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeScheduled = false;
      if (!mounted) return;
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
      if (!mounted) return;
      final latest = ref.read(partySessionProvider).snapshot;
      final latestDeadline = latest?.round.phaseEndsAt;
      final remaining = latestDeadline == null
          ? (_secondsRemaining - 1).clamp(0, 60)
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
    if (mounted) setState(() {});
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
    final snapshot = await ref
        .read(partySessionProvider.notifier)
        .runCommand(command);
    if (!mounted) return;
    if (snapshot == null) {
      final error = ref.read(partySessionProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Could not continue. Try again.')),
      );
      return;
    }
    _syncSnapshot(snapshot);
  }

  Future<void> _openCamera() async {
    if (_isOpeningCamera || _cameraController != null) return;
    setState(() {
      _isOpeningCamera = true;
      _cameraError = null;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('No camera is available.');
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _cameraController = controller;
    } on CameraException catch (error) {
      _cameraError = error.code == 'CameraAccessDenied'
          ? 'Camera permission was denied. You can keep playing without it.'
          : 'Camera is unavailable on this device.';
    } catch (_) {
      _cameraError = 'Camera is unavailable on this device.';
    } finally {
      if (mounted) setState(() => _isOpeningCamera = false);
    }
  }

  Future<void> _disposeCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) await controller.dispose();
    if (mounted) setState(() {});
  }

  Future<void> _captureMoment(PartySnapshot snapshot) async {
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
      final Uint8List bytes = await photo.readAsBytes();
      final moment = await ref
          .read(partySessionProvider.notifier)
          .uploadMoment(
            roomId: snapshot.room.id,
            roundNumber: snapshot.round.number,
            playerId: player.id,
            bytes: bytes,
          );
      if (!mounted) return;
      if (moment == null) {
        final error = ref.read(partySessionProvider).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error ?? 'Photo could not be saved.')),
        );
      } else {
        HapticFeedback.heavyImpact();
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  List<PartyMoment> _momentsForRound(int round) {
    return ref
        .read(partySessionProvider)
        .moments
        .where((moment) => moment.roundNumber == round)
        .toList(growable: false);
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
        final rows = next.asData?.value;
        if (rows == null || rows.isEmpty) return;
        final updatedRoom = Room.fromJson(rows.first);
        ref.read(currentRoomProvider.notifier).set(updatedRoom);
        unawaited(
          ref
              .read(partySessionProvider.notifier)
              .load(updatedRoom.id, loadMoments: true)
              .then((snapshot) {
                if (snapshot != null && mounted) _syncSnapshot(snapshot);
              }),
        );
      });
    }

    ref.listen(partySessionProvider.select((state) => state.snapshot), (
      _,
      snapshot,
    ) {
      if (snapshot != null) _syncSnapshot(snapshot);
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
    final moments = session.moments
        .where((moment) => moment.roundNumber == round.number)
        .toList(growable: false);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: Stack(
          children: [
            const Positioned.fill(
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
                      _partyNight.withValues(alpha: 0.72),
                      _partyNightBlue.withValues(alpha: 0.92),
                      Colors.black.withValues(alpha: 0.82),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final content = _buildContent(
                      snapshot: snapshot,
                      currentPlayer: currentPlayer,
                      isHost: isHost,
                      isPerformer: isPerformer,
                      moments: moments,
                    );
                    final cameraFirst =
                        !isPerformer &&
                        (round.phase == PartyRoundPhase.ready ||
                            round.phase == PartyRoundPhase.action ||
                            round.phase == PartyRoundPhase.resultEntry ||
                            round.phase == PartyRoundPhase.resultConfirm);
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                          child: Column(
                            children: [
                              Expanded(
                                flex: cameraFirst ? 64 : 54,
                                child: cameraFirst ? content.$2 : content.$1,
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                flex: cameraFirst ? 36 : 46,
                                child: cameraFirst ? content.$1 : content.$2,
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
          ],
        ),
      ),
    );
  }

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
                label: 'START 60 SECONDS',
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
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _resultController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: AppColors.ivory,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
                decoration: InputDecoration(
                  hintText: '0–${round.challenge.maxResult}',
                  hintStyle: TextStyle(
                    color: AppColors.ivory.withValues(alpha: 0.34),
                  ),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.26),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              onPressed: () {
                final value = int.tryParse(_resultController.text);
                if (value == null ||
                    value < 0 ||
                    value > round.challenge.maxResult) {
                  return;
                }
                _runCommand(
                  (service) => service.submitResult(
                    roomId: snapshot.room.id,
                    result: value,
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward_rounded),
              style: IconButton.styleFrom(
                backgroundColor: _partyOrange,
                foregroundColor: AppColors.ink,
                minimumSize: const Size(58, 58),
              ),
            ),
          ],
        );
      case PartyRoundPhase.resultConfirm:
        final canConfirm = _isRequiredConfirmer(round, currentPlayer);
        if (!canConfirm) return _waitingPill('WAITING FOR SCORE CONFIRMATION');
        return Column(
          children: [
            Text(
              '${round.proposedResult ?? '—'} ${round.challenge.answerUnit}',
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
                  child: moment.signedUrl == null
                      ? const ColoredBox(color: Colors.white12)
                      : Image.network(
                          moment.signedUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const ColoredBox(color: Colors.white12),
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
        minimumSize: const Size(160, 54),
        backgroundColor: _partyOrange,
        foregroundColor: AppColors.ink,
        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w900),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        minimumSize: const Size(140, 54),
        foregroundColor: AppColors.ivory,
        side: BorderSide(color: AppColors.ivory.withValues(alpha: 0.38)),
        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w900),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
