import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/core_providers.dart';
import '../../player/models/player_model.dart';
import '../models/party_moment.dart';
import '../models/party_snapshot.dart';
import '../providers/party_local_media_provider.dart';
import '../theme/party_palette.dart';

typedef PartySceneAction = Future<void> Function();
typedef PartySceneResultAction = Future<void> Function(int result);

/// Keeps the Party round inside the betting screen.
///
/// The left side of the game screen (brand, round, question and players) is
/// deliberately never rebuilt by this layer. Only the existing right-hand
/// betting area changes emphasis for ready, action and result phases. Camera
/// is the sole full-screen overlay and does not create a route.
class PartySingleSceneLayer extends ConsumerStatefulWidget {
  final PartySnapshot snapshot;
  final Player? currentPlayer;
  final List<Player> players;
  final int secondsRemaining;
  final bool commandInFlight;
  final double stageTop;
  final PartySceneAction onStartAction;
  final PartySceneAction onOpenResultEntry;
  final PartySceneResultAction onSubmitResult;
  final PartySceneResultAction onSubmitChoice;
  final PartySceneAction onConfirmResult;
  final PartySceneAction onDisputeResult;

  const PartySingleSceneLayer({
    super.key,
    required this.snapshot,
    required this.currentPlayer,
    this.players = const [],
    required this.secondsRemaining,
    required this.commandInFlight,
    this.stageTop = 0,
    required this.onStartAction,
    required this.onOpenResultEntry,
    required this.onSubmitResult,
    required this.onSubmitChoice,
    required this.onConfirmResult,
    required this.onDisputeResult,
  });

  @override
  ConsumerState<PartySingleSceneLayer> createState() =>
      _PartySingleSceneLayerState();
}

class _PartySingleSceneLayerState extends ConsumerState<PartySingleSceneLayer>
    with WidgetsBindingObserver {
  String _resultDigits = '';
  CameraController? _cameraController;
  Future<List<CameraDescription>>? _cameraDiscoveryFuture;
  List<CameraDescription> _availableCameras = const [];
  Timer? _consensusTimer;
  int? _consensusStateVersion;
  int _consensusSeconds = 5;
  int _cameraIndex = 0;
  bool _showCamera = false;
  bool _isOpeningCamera = false;
  bool _isCapturing = false;
  bool _captureFlash = false;
  bool _autoConfirmInFlight = false;
  String? _cameraError;
  int? _myReviewVote;

  bool get _isPerformancePhase {
    // In this release, Party Mode is strictly Poll Mode. No performer/camera stage under any circumstances.
    return false;
  }

  bool get _isPerformer =>
      widget.currentPlayer?.id == widget.snapshot.round.performer.id;

  bool get _isHost => widget.currentPlayer?.isHost == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          _prewarmCameraDiscovery().catchError(
            (_) => const <CameraDescription>[],
          ),
        );
      }
    });
    _syncConsensusTimer();
  }

  @override
  void didUpdateWidget(covariant PartySingleSceneLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.round.number != widget.snapshot.round.number) {
      _resultDigits = '';
      _autoConfirmInFlight = false;
      _showCamera = false;
      unawaited(_disposeCamera());
    }
    if (oldWidget.snapshot.round.number != widget.snapshot.round.number ||
        oldWidget.snapshot.round.phase != widget.snapshot.round.phase) {
      _myReviewVote = null;
    }
    if (oldWidget.snapshot.round.phase != widget.snapshot.round.phase ||
        oldWidget.snapshot.stateVersion != widget.snapshot.stateVersion) {
      _syncConsensusTimer();
    }
    if (!_isPerformancePhase && _showCamera) {
      _showCamera = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_disposeCamera());
      return;
    }
    if (state == AppLifecycleState.resumed &&
        _showCamera &&
        _cameraController == null) {
      unawaited(_openCamera());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _consensusTimer?.cancel();
    unawaited(_cameraController?.dispose());
    super.dispose();
  }

  void _syncConsensusTimer() {
    final snapshot = widget.snapshot;
    if (snapshot.round.phase != PartyRoundPhase.resultConfirm) {
      _consensusTimer?.cancel();
      _consensusTimer = null;
      _consensusStateVersion = null;
      _consensusSeconds = 5;
      _autoConfirmInFlight = false;
      return;
    }
    if (_consensusStateVersion == snapshot.stateVersion &&
        _consensusTimer != null) {
      return;
    }

    _consensusTimer?.cancel();
    _consensusStateVersion = snapshot.stateVersion;
    _autoConfirmInFlight = false;
    final serverNow = ref.read(roomServiceProvider).serverNow;
    final deadline =
        snapshot.round.phaseEndsAt ?? serverNow.add(const Duration(seconds: 5));

    void tick() {
      if (!mounted) return;
      final milliseconds = deadline
          .difference(ref.read(roomServiceProvider).serverNow)
          .inMilliseconds;
      final remaining = milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
      if (_consensusSeconds != remaining) {
        setState(() => _consensusSeconds = remaining);
      }
      if (remaining > 0 || _autoConfirmInFlight) return;
      _consensusTimer?.cancel();
      _consensusTimer = null;
      _autoConfirmInFlight = true;
      unawaited(widget.onConfirmResult());
    }

    _consensusSeconds = 5;
    _consensusTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => tick(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => tick());
  }

  Future<List<CameraDescription>> _prewarmCameraDiscovery() {
    if (_availableCameras.isNotEmpty) {
      return Future.value(_availableCameras);
    }
    final pending = _cameraDiscoveryFuture;
    if (pending != null) return pending;
    final future = availableCameras().then((cameras) {
      _availableCameras = cameras;
      return cameras;
    });
    _cameraDiscoveryFuture = future;
    return future.whenComplete(() => _cameraDiscoveryFuture = null);
  }

  Future<void> _enterCamera() async {
    if (!mounted) return;
    setState(() {
      _showCamera = true;
      _cameraError = null;
    });
    await _openCamera();
  }

  void _closeCamera() {
    if (!mounted) return;
    setState(() => _showCamera = false);
  }

  Future<void> _openCamera({int? cameraIndex}) async {
    if (!mounted || _isOpeningCamera || _cameraController != null) return;
    CameraController? openingController;
    setState(() {
      _isOpeningCamera = true;
      _cameraError = null;
    });
    try {
      final cameras = _availableCameras.isEmpty
          ? await _prewarmCameraDiscovery()
          : _availableCameras;
      if (cameras.isEmpty) throw StateError('No camera is available.');
      if (cameraIndex != null) {
        _cameraIndex = cameraIndex.clamp(0, cameras.length - 1);
      } else {
        final backIndex = cameras.indexWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
        );
        _cameraIndex = backIndex < 0 ? 0 : backIndex;
      }
      openingController = CameraController(
        cameras[_cameraIndex],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await openingController.initialize().timeout(const Duration(seconds: 12));
      if (!mounted || !_showCamera) {
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
          ? 'Camera access is off. Allow it in settings and try again.'
          : 'Camera could not start (${error.code}).';
    } on TimeoutException {
      _cameraError = 'Camera took too long to start. Try again.';
    } catch (_) {
      _cameraError = 'Camera could not start on this device.';
    } finally {
      if (openingController != null) await openingController.dispose();
      if (mounted) setState(() => _isOpeningCamera = false);
    }
  }

  Future<void> _switchCamera() async {
    if (_availableCameras.length < 2 || _isOpeningCamera) return;
    final nextIndex = (_cameraIndex + 1) % _availableCameras.length;
    await _disposeCamera();
    if (mounted && _showCamera) await _openCamera(cameraIndex: nextIndex);
  }

  Future<void> _disposeCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) await controller.dispose();
    if (mounted) setState(() {});
  }

  List<PartyMoment> _momentsForCurrentRound() {
    final playerId = widget.currentPlayer?.id;
    final snapshot = widget.snapshot;
    return ref
        .read(partyLocalMediaProvider)
        .where(
          (moment) =>
              moment.roomId == snapshot.room.id &&
              moment.roundNumber == snapshot.round.number &&
              moment.uploaderPlayerId == playerId,
        )
        .toList(growable: false);
  }

  Future<void> _captureMoment() async {
    final controller = _cameraController;
    final player = widget.currentPlayer;
    final moments = _momentsForCurrentRound();
    if (!mounted ||
        controller == null ||
        !controller.value.isInitialized ||
        player == null ||
        _isCapturing ||
        moments.length >= 3) {
      return;
    }
    setState(() => _isCapturing = true);
    try {
      HapticFeedback.mediumImpact();
      final photo = await controller.takePicture();
      if (!mounted) return;
      setState(() => _captureFlash = true);
      Timer(const Duration(milliseconds: 100), () {
        if (mounted) setState(() => _captureFlash = false);
      });
      final Uint8List bytes = await photo.readAsBytes();
      if (!mounted) return;
      ref
          .read(partyLocalMediaProvider.notifier)
          .add(
            roomId: widget.snapshot.room.id,
            roundNumber: widget.snapshot.round.number,
            playerId: player.id,
            playerName: player.name,
            playerColor: player.avatarColor,
            bytes: bytes,
          );
      HapticFeedback.heavyImpact();
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final moments = ref
        .watch(partyLocalMediaProvider)
        .where(
          (moment) =>
              moment.roomId == widget.snapshot.room.id &&
              moment.roundNumber == widget.snapshot.round.number &&
              moment.uploaderPlayerId == widget.currentPlayer?.id,
        )
        .toList(growable: false);
    final stageVisible = _isPerformancePhase;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 6,
          right: 6,
          top: widget.stageTop,
          bottom: 6,
          child: IgnorePointer(
            ignoring: !stageVisible,
            child: AnimatedSlide(
              offset: stageVisible ? Offset.zero : const Offset(0, 0.05),
              duration: const Duration(milliseconds: 480),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: stageVisible ? 1 : 0,
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOutCubic,
                child: _buildStage(moments),
              ),
            ),
          ),
        ),
        if (_showCamera) _buildCameraOverlay(moments),
      ],
    );
  }

  Widget _buildStage(List<PartyMoment> moments) {
    final round = widget.snapshot.round;
    final canOpenCamera =
        !round.challenge.isChoice && !_isPerformer && moments.length < 3;
    final cameraIsInline = round.phase == PartyRoundPhase.action;
    final hideCamera = cameraIsInline || round.challenge.isChoice;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            PartyPalette.surface,
            PartyPalette.night,
            PartyPalette.nightDeep,
          ],
          stops: [0.0, 0.45, 1.0],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: PartyPalette.orangeSoft.withValues(alpha: 0.38),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: PartyPalette.orange.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Ambient corner glow
            Positioned(
              top: -24,
              right: -24,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PartyPalette.orange.withValues(alpha: 0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildStageLabel()),
                      if (!hideCamera) ...[
                        const SizedBox(width: 8),
                        _cameraButton(
                          enabled: canOpenCamera,
                          momentCount: moments.length,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 9),
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          PartyPalette.orange.withValues(alpha: 0.35),
                          PartyPalette.cream.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 340),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final scale = Tween<double>(
                          begin: 0.985,
                          end: 1,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(scale: scale, child: child),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey(
                          '${round.number}-${round.phase}-${round.performerReady}',
                        ),
                        child: _buildStageBody(moments),
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

  Widget _buildStageLabel() {
    final round = widget.snapshot.round;
    final label = switch (round.phase) {
      PartyRoundPhase.ready =>
        round.performerReady ? 'READY TO START' : 'GET READY',
      PartyRoundPhase.action => 'LIVE PERFORMANCE',
      PartyRoundPhase.resultEntry =>
        round.challenge.isChoice ? 'MAKE YOUR CHOICE' : 'RECORD THE RESULT',
      PartyRoundPhase.resultConfirm => 'VERIFY RESULT',
      PartyRoundPhase.betting =>
        round.challenge.isPoll
            ? '🤫 SECRET VOTE · NO TALKING'
            : 'PLACE YOUR BETS',
      _ => 'PARTY STAGE',
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 190;
        return Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: PartyPalette.orange,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: PartyPalette.orange.withValues(alpha: 0.7),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: PartyPalette.orangeSoft,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: PartyPalette.nightDeep.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: PartyPalette.orangeSoft.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  'ROUND ${round.number}',
                  style: GoogleFonts.outfit(
                    color: PartyPalette.creamMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _cameraButton({required bool enabled, required int momentCount}) {
    return Semantics(
      button: true,
      label: 'Open camera',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled
              ? () {
                  HapticFeedback.lightImpact();
                  _enterCamera();
                }
              : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: enabled
                    ? [
                        PartyPalette.orange.withValues(alpha: 0.25),
                        PartyPalette.nightDeep.withValues(alpha: 0.45),
                      ]
                    : [
                        PartyPalette.nightDeep.withValues(alpha: 0.3),
                        PartyPalette.nightDeep.withValues(alpha: 0.15),
                      ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: enabled
                    ? PartyPalette.orangeSoft.withValues(alpha: 0.5)
                    : PartyPalette.cream.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  momentCount >= 3
                      ? Icons.check_circle_rounded
                      : Icons.photo_camera_rounded,
                  color: enabled
                      ? PartyPalette.orangeSoft
                      : PartyPalette.blueMuted.withValues(alpha: 0.45),
                  size: 17,
                ),
                const SizedBox(width: 6),
                Text(
                  'PAPARAZZI · $momentCount/3',
                  style: GoogleFonts.outfit(
                    color: enabled
                        ? PartyPalette.cream
                        : PartyPalette.blueMuted.withValues(alpha: 0.45),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStageBody(List<PartyMoment> moments) {
    final round = widget.snapshot.round;
    return switch (round.phase) {
      PartyRoundPhase.ready => _buildReady(),
      PartyRoundPhase.action => _buildAction(moments),
      PartyRoundPhase.resultEntry => _buildResultEntry(),
      PartyRoundPhase.resultConfirm => _buildResultReview(),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildReady() {
    final round = widget.snapshot.round;
    final performerName = round.performer.name.toUpperCase();
    final isAttempt = round.challenge.isAttempt;
    String roleMessage;
    IconData roleIcon;
    Widget? action;

    if (_isHost) {
      roleIcon = Icons.sports_score_rounded;
      roleMessage = isAttempt
          ? 'Check that $performerName is ready. They get 5 tries; record the result when landed.'
          : 'Check that $performerName is in position, then start the countdown timer.';
      action = _primaryButton(
        label: isAttempt
            ? 'START 5 ATTEMPTS'
            : 'START ${round.challenge.durationSeconds}s TIMER',
        icon: Icons.play_arrow_rounded,
        onPressed: widget.onStartAction,
      );
    } else if (_isPerformer) {
      roleIcon = Icons.bolt_rounded;
      roleMessage = isAttempt
          ? 'You have 5 attempts. Give it your best — the host records your winning try!'
          : 'Get into position! The host will start your countdown.';
    } else {
      roleIcon = Icons.visibility_rounded;
      roleMessage = isAttempt
          ? 'Watch all five tries! The host will record the first successful attempt.'
          : 'Keep your eyes on $performerName! The host starts when everyone is set.';
    }

    final initial = performerName.isEmpty ? '?' : performerName.substring(0, 1);
    final challengeTypeLabel = round.challenge.isChoice
        ? '⚖️ CHOICE CHALLENGE'
        : isAttempt
        ? '🎯 5 TRIES CHALLENGE'
        : '⏱️ ${round.challenge.durationSeconds}s COUNTDOWN';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 310;
        final avatarSize = compact ? 52.0 : 64.0;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Performer Emblem & Info Header Card
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: compact ? 8 : 11,
              ),
              decoration: BoxDecoration(
                color: PartyPalette.nightDeep.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: PartyPalette.cream.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [
                          PartyPalette.surfaceRaised,
                          PartyPalette.nightDeep,
                        ],
                      ),
                      border: Border.all(
                        color: PartyPalette.orangeSoft.withValues(alpha: 0.75),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: PartyPalette.orange.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontFamily: 'RehnCondensed',
                        color: PartyPalette.cream,
                        fontSize: compact ? 30 : 38,
                        fontWeight: FontWeight.w900,
                        height: 0.9,
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: PartyPalette.orange.withValues(
                                  alpha: 0.18,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: PartyPalette.orangeSoft.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              child: Text(
                                _isPerformer
                                    ? 'YOU ARE UP'
                                    : 'UP NEXT ON STAGE',
                                style: GoogleFonts.outfit(
                                  color: PartyPalette.orangeSoft,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                challengeTypeLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: PartyPalette.blueMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            performerName,
                            style: _stageTitleStyle(
                              fontSize: compact ? 30 : 36,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: compact ? 8 : 11),
            // Context Instruction Card
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: compact ? 8 : 10,
                ),
                decoration: BoxDecoration(
                  color: PartyPalette.nightDeep.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: PartyPalette.cream.withValues(alpha: 0.07),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(roleIcon, color: PartyPalette.orangeSoft, size: 19),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        roleMessage,
                        style: GoogleFonts.outfit(
                          color: PartyPalette.blueMuted,
                          fontSize: compact ? 11 : 12,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (action != null) ...[
              SizedBox(height: compact ? 10 : 13),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SizedBox(width: double.infinity, child: action),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAction(List<PartyMoment> moments) {
    final round = widget.snapshot.round;
    final isAttempt = round.challenge.isAttempt;
    final duration = round.challenge.durationSeconds;
    final progress = isAttempt || duration <= 0
        ? 0.0
        : (widget.secondsRemaining / duration).clamp(0.0, 1.0);
    final urgent = !isAttempt && widget.secondsRemaining <= 10;
    final canOpenCamera = !_isPerformer && moments.length < 3;
    final ownBet = _ownBetSummary();
    final canRecord = _isHost;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 310;
        final timerSize = compact ? 74.0 : 86.0;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(compact ? 11 : 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    PartyPalette.surfaceRaised.withValues(alpha: 0.7),
                    PartyPalette.nightDeep.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: urgent
                      ? PartyPalette.terracotta.withValues(alpha: 0.7)
                      : PartyPalette.orangeSoft.withValues(alpha: 0.3),
                  width: 1.3,
                ),
                boxShadow: [
                  if (urgent)
                    BoxShadow(
                      color: PartyPalette.terracotta.withValues(alpha: 0.3),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: Row(
                children: [
                  // Timer or Attempts Progress Ring
                  SizedBox(
                    width: timerSize,
                    height: timerSize,
                    child: isAttempt
                        ? Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(
                                colors: [
                                  PartyPalette.surfaceRaised,
                                  PartyPalette.nightDeep,
                                ],
                              ),
                              border: Border.all(
                                color: PartyPalette.orange,
                                width: 3.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: PartyPalette.orange.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'UP TO',
                                      style: GoogleFonts.outfit(
                                        color: PartyPalette.blueMuted,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    Text(
                                      '5 TRIES',
                                      style: TextStyle(
                                        fontFamily: 'RehnCondensed',
                                        color: PartyPalette.cream,
                                        fontSize: compact ? 22 : 25,
                                        fontWeight: FontWeight.w900,
                                        height: 0.95,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 5,
                                strokeCap: StrokeCap.round,
                                color: urgent
                                    ? PartyPalette.terracotta
                                    : PartyPalette.orange,
                                backgroundColor: PartyPalette.nightDeep
                                    .withValues(alpha: 0.6),
                              ),
                              Center(
                                child: Text(
                                  '00:${widget.secondsRemaining.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontFamily: 'RehnCondensed',
                                    color: urgent
                                        ? const Color(0xFFFF9E80)
                                        : PartyPalette.cream,
                                    fontSize: compact ? 26 : 30,
                                    fontWeight: FontWeight.w900,
                                    height: 0.9,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  SizedBox(width: compact ? 11 : 14),
                  // Middle: Performer status & user bet
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4ADE80),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${round.performer.name.toUpperCase()} · IN ACTION',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: PartyPalette.cream,
                                  fontSize: compact ? 13.5 : 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: PartyPalette.nightDeep.withValues(
                              alpha: 0.4,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: ownBet != null
                                  ? PartyPalette.orangeSoft.withValues(
                                      alpha: 0.3,
                                    )
                                  : PartyPalette.cream.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                ownBet == null
                                    ? (_isPerformer
                                          ? Icons.bolt_rounded
                                          : Icons.visibility_rounded)
                                    : Icons.casino_rounded,
                                color: PartyPalette.orangeSoft,
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  ownBet ??
                                      (_isPerformer
                                          ? 'GIVE IT EVERYTHING!'
                                          : _isHost
                                          ? 'RECORD WHEN DONE'
                                          : 'WATCHING LIVE'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    color: ownBet == null
                                        ? PartyPalette.blueMuted
                                        : PartyPalette.creamMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Paparazzi Camera tile
                  _cameraActionTile(
                    enabled: canOpenCamera,
                    momentCount: moments.length,
                  ),
                ],
              ),
            ),
            if (canRecord) ...[
              SizedBox(height: compact ? 9 : 12),
              _primaryButton(
                label: round.challenge.isAttempt || round.challenge.isBinary
                    ? 'RECORD RESULT'
                    : widget.secondsRemaining > 0
                    ? 'FINISH & RECORD'
                    : 'CONTINUE TO RESULT',
                icon: Icons.arrow_forward_rounded,
                onPressed: widget.onOpenResultEntry,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _cameraActionTile({required bool enabled, required int momentCount}) {
    return Semantics(
      button: true,
      label: 'Open camera',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('party-performance-camera'),
          onTap: enabled
              ? () {
                  HapticFeedback.lightImpact();
                  _enterCamera();
                }
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 60,
            height: 68,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: enabled
                    ? [
                        PartyPalette.orange.withValues(alpha: 0.25),
                        PartyPalette.nightDeep.withValues(alpha: 0.5),
                      ]
                    : [
                        PartyPalette.nightDeep.withValues(alpha: 0.3),
                        PartyPalette.nightDeep.withValues(alpha: 0.18),
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: enabled
                    ? PartyPalette.orangeSoft.withValues(alpha: 0.5)
                    : PartyPalette.cream.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  momentCount >= 3
                      ? Icons.check_circle_rounded
                      : Icons.photo_camera_rounded,
                  color: enabled
                      ? PartyPalette.orangeSoft
                      : PartyPalette.blueMuted.withValues(alpha: 0.42),
                  size: 22,
                ),
                const SizedBox(height: 4),
                Text(
                  '$momentCount/3',
                  style: GoogleFonts.outfit(
                    color: enabled
                        ? PartyPalette.creamMuted
                        : PartyPalette.blueMuted.withValues(alpha: 0.42),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _ownBetSummary() {
    final playerId = widget.currentPlayer?.id;
    if (playerId == null) return null;
    final bets = widget.snapshot.round.bets
        .where((bet) => bet.playerId == playerId)
        .toList(growable: false);
    if (bets.isEmpty) return null;

    final labels = <String>[];
    for (final bet in bets) {
      final label = _betSlotLabel(bet.slotIndex);
      if (!labels.contains(label)) labels.add(label);
    }
    final chips = bets.fold<int>(0, (total, bet) => total + bet.chips);
    return 'YOUR BET - ${labels.join(' + ')} - $chips CHIPS';
  }

  String _betSlotLabel(int slotIndex) {
    final challenge = widget.snapshot.round.challenge;
    if (challenge.isVersus) {
      if (slotIndex == 0) {
        return widget.snapshot.round.performer.name.toUpperCase();
      }
      return (widget.snapshot.round.witness?.name ?? 'CHALLENGER')
          .toUpperCase();
    }
    if (challenge.isShowdown || challenge.isPoll) {
      if (slotIndex >= 0 && slotIndex < widget.players.length) {
        return widget.players[slotIndex].name.toUpperCase();
      }
      return 'PLAYER ${slotIndex + 1}';
    }
    if (challenge.isChoice) {
      return challenge.choiceLabel(slotIndex)?.toUpperCase() ?? 'OPTION ';
    }
    if (challenge.isBinary) return slotIndex == 1 ? 'YES' : 'NO';
    if (challenge.isAttempt) {
      return switch (slotIndex) {
        0 => '1ST TRY',
        1 => '2ND TRY',
        2 => '3RD TRY',
        3 => '4-5 TRIES',
        4 => "FAILED",
        _ => 'ATTEMPT',
      };
    }

    final boundaries = challenge.betBoundaries;
    if (boundaries.length < 4) return 'RANGE ${slotIndex + 1}';
    return switch (slotIndex) {
      0 => 'UNDER ${boundaries[0]}',
      1 => '${boundaries[0]}-${boundaries[1] - 1}',
      2 => '${boundaries[1]}-${boundaries[2]}',
      3 => '${boundaries[2] + 1}-${boundaries[3]}',
      4 => '${boundaries[3] + 1}+',
      _ => 'RANGE ${slotIndex + 1}',
    };
  }

  Widget _buildChoiceEntry() {
    final round = widget.snapshot.round;
    final optionA = round.challenge.optionA;
    final optionB = round.challenge.optionB;
    if (!_isPerformer) {
      return _centeredStage(
        kicker: 'BETS ARE LOCKED',
        title: '${round.performer.name.toUpperCase()} IS CHOOSING',
        subtitle:
            'No hints allowed! Their secret choice will decide the payout.',
      );
    }
    if (optionA == null || optionB == null) {
      return _centeredStage(
        kicker: 'UNLOCKING OPTIONS',
        title: 'ONE MOMENT',
        subtitle: 'Your choices are being prepared right now.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 330;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _StageKicker('YOUR SECRET CHOICE'),
            SizedBox(height: compact ? 4 : 7),
            Text(
              'Your friends placed their bets. Pick what is truly right for you!',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: PartyPalette.blueMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: compact ? 9 : 13),
            _choiceButton(index: 0, label: optionA),
            SizedBox(height: compact ? 7 : 10),
            _choiceButton(index: 1, label: optionB),
          ],
        );
      },
    );
  }

  Widget _choiceButton({required int index, required String label}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('party-choice-$index'),
            onTap: widget.commandInFlight
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    unawaited(widget.onSubmitChoice(index));
                  },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    PartyPalette.surfaceRaised.withValues(alpha: 0.85),
                    PartyPalette.nightDeep.withValues(alpha: 0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: index == 0
                      ? PartyPalette.orange.withValues(alpha: 0.6)
                      : PartyPalette.orangeSoft.withValues(alpha: 0.6),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: PartyPalette.orange.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: PartyPalette.orange.withValues(alpha: 0.2),
                      border: Border.all(
                        color: PartyPalette.orangeSoft,
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      index == 0 ? 'A' : 'B',
                      style: GoogleFonts.outfit(
                        color: PartyPalette.orangeSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: PartyPalette.cream,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: PartyPalette.orangeSoft,
                    size: 19,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultEntry() {
    final round = widget.snapshot.round;
    if (round.challenge.isChoice) return _buildChoiceEntry();
    if (round.challenge.isVersus) return _buildVersusResultEntry();
    if (round.challenge.isShowdown) return _buildShowdownResultEntry();
    if (!_isHost) {
      return _centeredStage(
        kicker: 'CHALLENGE COMPLETE',
        title: 'RECORDING RESULT',
        subtitle:
            'The host is entering the final score. Results will be shown shortly!',
      );
    }

    if (round.challenge.isBinary) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _StageKicker('HOW DID THEY DO?'),
          const SizedBox(height: 8),
          Text(
            'Record the Outcome',
            textAlign: TextAlign.center,
            style: _stageTitleStyle(fontSize: 32),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _secondaryButton(
                  label: 'FAILED',
                  icon: Icons.close_rounded,
                  onPressed: () => widget.onSubmitResult(0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _primaryButton(
                  label: 'SUCCESS',
                  icon: Icons.check_rounded,
                  onPressed: () => widget.onSubmitResult(1),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (round.challenge.isAttempt) {
      return _buildAttemptResultEntry();
    }
    return _buildCountResultEntry();
  }

  Widget _buildVersusResultEntry() {
    final round = widget.snapshot.round;
    if (!_isHost) {
      return _centeredStage(
        kicker: 'DUEL COMPLETE',
        title: 'RECORDING WINNER',
        subtitle: 'The host is selecting who won the match!',
      );
    }

    final performerName = round.performer.name.toUpperCase();
    final opponentName = (round.witness?.name ?? 'CHALLENGER').toUpperCase();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 330;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _StageKicker('WHO WON THE DUEL?'),
            SizedBox(height: compact ? 4 : 8),
            Text(
              'Select the Victor',
              textAlign: TextAlign.center,
              style: _stageTitleStyle(fontSize: compact ? 26 : 30),
            ),
            SizedBox(height: compact ? 10 : 16),
            _versusResultButton(index: 0, label: '$performerName WON'),
            SizedBox(height: compact ? 8 : 12),
            _versusResultButton(index: 1, label: '$opponentName WON'),
          ],
        );
      },
    );
  }

  Widget _versusResultButton({required int index, required String label}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('party-choice-$index'),
            onTap: widget.commandInFlight
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    unawaited(widget.onSubmitResult(index));
                  },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    PartyPalette.surfaceRaised.withValues(alpha: 0.85),
                    PartyPalette.nightDeep.withValues(alpha: 0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: index == 0
                      ? PartyPalette.orange.withValues(alpha: 0.6)
                      : PartyPalette.orangeSoft.withValues(alpha: 0.6),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: PartyPalette.orange.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: PartyPalette.orange.withValues(alpha: 0.2),
                      border: Border.all(
                        color: PartyPalette.orangeSoft,
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      index == 0 ? 'A' : 'B',
                      style: GoogleFonts.outfit(
                        color: PartyPalette.orangeSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: PartyPalette.cream,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: PartyPalette.orangeSoft,
                    size: 19,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShowdownResultEntry() {
    if (!_isHost) {
      return _centeredStage(
        kicker: 'SHOWDOWN COMPLETE',
        title: 'SELECTING WINNER',
        subtitle:
            'The host is selecting the winning player with the best result!',
      );
    }

    final players = widget.players;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 330;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _StageKicker('WHO HAD THE WINNING STAT / RESULT?'),
            SizedBox(height: compact ? 4 : 8),
            Text(
              'Select Winning Player',
              textAlign: TextAlign.center,
              style: _stageTitleStyle(fontSize: compact ? 24 : 28),
            ),
            SizedBox(height: compact ? 8 : 12),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var i = 0; i < players.length; i++)
                      _showdownPlayerButton(index: i, player: players[i]),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _showdownPlayerButton({required int index, required Player player}) {
    final initial = player.name.isNotEmpty
        ? player.name.substring(0, 1).toUpperCase()
        : '?';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('party-showdown-winner-$index'),
        onTap: widget.commandInFlight
            ? null
            : () {
                HapticFeedback.mediumImpact();
                unawaited(widget.onSubmitResult(index));
              },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                PartyPalette.surfaceRaised.withValues(alpha: 0.85),
                PartyPalette.nightDeep.withValues(alpha: 0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: PartyPalette.orangeSoft.withValues(alpha: 0.45),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PartyPalette.surfaceRaised,
                  border: Border.all(
                    color: PartyPalette.orangeSoft,
                    width: 1.2,
                  ),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontFamily: 'RehnCondensed',
                    color: PartyPalette.cream,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: PartyPalette.cream,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountResultEntry() {
    final challenge = widget.snapshot.round.challenge;
    final displayValue = _resultDigits.isEmpty ? '--' : _resultDigits;
    const keys = <Object>[1, 2, 3, 4, 5, 6, 7, 8, 9, 'back', 0, 'submit'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 340;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _StageKicker('RECORD FINAL RESULT'),
            SizedBox(height: compact ? 4 : 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Container(
                height: compact ? 52 : 60,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      PartyPalette.surfaceRaised,
                      PartyPalette.nightDeep,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: PartyPalette.orange.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayValue,
                        key: const ValueKey('party-result-display'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'RehnCondensed',
                          color: _resultDigits.isEmpty
                              ? PartyPalette.blueMuted.withValues(alpha: 0.42)
                              : PartyPalette.cream,
                          fontSize: compact ? 34 : 40,
                          fontWeight: FontWeight.w900,
                          height: 0.95,
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: PartyPalette.cream.withValues(alpha: 0.12),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 80,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            challenge.answerUnit.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: PartyPalette.orangeSoft,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.7,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'MAX ${challenge.maxResult}',
                            style: GoogleFonts.outfit(
                              color: PartyPalette.blueMuted,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: compact ? 6 : 9),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: keys.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: compact ? 5 : 7,
                  childAspectRatio: compact ? 2.45 : 2.15,
                ),
                itemBuilder: (context, index) {
                  final keyValue = keys[index];
                  final isBack = keyValue == 'back';
                  final isSubmit = keyValue == 'submit';
                  final enabled =
                      !widget.commandInFlight &&
                      (!isSubmit || _resultDigits.isNotEmpty);
                  return Material(
                    color: isSubmit
                        ? PartyPalette.orange
                        : PartyPalette.surfaceRaised.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      key: ValueKey('party-result-key-$keyValue'),
                      onTap: !enabled
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              if (isBack) {
                                _removeResultDigit();
                              } else if (isSubmit) {
                                _submitNumpadResult();
                              } else {
                                _appendResultDigit(keyValue as int);
                              }
                            },
                      borderRadius: BorderRadius.circular(12),
                      child: Center(
                        child: isBack
                            ? const Icon(
                                Icons.backspace_outlined,
                                color: PartyPalette.creamMuted,
                                size: 18,
                              )
                            : isSubmit
                            ? const Icon(
                                Icons.check_rounded,
                                color: PartyPalette.nightDeep,
                                size: 23,
                              )
                            : Text(
                                '$keyValue',
                                style: const TextStyle(
                                  fontFamily: 'RehnCondensed',
                                  color: PartyPalette.cream,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _appendResultDigit(int digit) {
    final candidate = _resultDigits == '0' ? '$digit' : '$_resultDigits$digit';
    final value = int.tryParse(candidate);
    if (value == null || value > widget.snapshot.round.challenge.maxResult) {
      HapticFeedback.mediumImpact();
      return;
    }
    setState(() => _resultDigits = candidate);
  }

  void _removeResultDigit() {
    if (_resultDigits.isEmpty) return;
    setState(() {
      _resultDigits = _resultDigits.substring(0, _resultDigits.length - 1);
    });
  }

  void _submitNumpadResult() {
    final value = int.tryParse(_resultDigits);
    if (value == null || value > widget.snapshot.round.challenge.maxResult) {
      HapticFeedback.mediumImpact();
      return;
    }
    unawaited(widget.onSubmitResult(value));
  }

  Widget _buildAttemptResultEntry() {
    const attempts = [
      (value: 1, label: '1ST TRY'),
      (value: 2, label: '2ND TRY'),
      (value: 3, label: '3RD TRY'),
      (value: 4, label: '4TH TRY'),
      (value: 5, label: '5TH TRY'),
      (value: 0, label: 'FAILED'),
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _StageKicker('RECORD ATTEMPT RESULT'),
        const SizedBox(height: 6),
        Text(
          'Which attempt landed?',
          textAlign: TextAlign.center,
          style: _stageTitleStyle(fontSize: 30),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final attempt in attempts)
                SizedBox(
                  width: 134,
                  height: 46,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.commandInFlight
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              unawaited(widget.onSubmitResult(attempt.value));
                            },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: attempt.value == 0
                                ? [
                                    PartyPalette.terracotta.withValues(
                                      alpha: 0.35,
                                    ),
                                    PartyPalette.nightDeep,
                                  ]
                                : [
                                    PartyPalette.orange.withValues(alpha: 0.2),
                                    PartyPalette.surfaceRaised,
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: attempt.value == 0
                                ? PartyPalette.terracotta
                                : PartyPalette.orange.withValues(alpha: 0.55),
                            width: 1.2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          attempt.label,
                          style: GoogleFonts.outfit(
                            color: attempt.value == 0
                                ? const Color(0xFFF87171)
                                : PartyPalette.cream,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultReview() {
    final round = widget.snapshot.round;
    final result = round.challenge.isChoice
        ? (round.challenge.choiceLabel(round.proposedResult ?? -1) ?? 'CHOICE')
        : round.challenge.isBinary
        ? (round.proposedResult == 1 ? 'SUCCESS' : 'FAILED')
        : round.challenge.isAttempt
        ? (round.proposedResult == 0
              ? 'DOESN’T LAND'
              : 'ATTEMPT ${round.proposedResult ?? '—'}')
        : '${round.proposedResult ?? '—'} ${round.challenge.answerUnit}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 330;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _StageKicker('RESULT CONFIRMATION · SONUÇ ONAYI'),
            SizedBox(height: compact ? 4 : 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                result.toUpperCase(),
                textAlign: TextAlign.center,
                style: _stageTitleStyle(
                  fontSize: compact ? 36 : 44,
                ).copyWith(color: PartyPalette.orangeSoft),
              ),
            ),
            SizedBox(height: compact ? 4 : 8),
            Text(
              'Do you approve this result? / Sonucu onaylıyor musunuz?',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: PartyPalette.cream,
                fontSize: compact ? 12 : 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: compact ? 8 : 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: PartyPalette.nightDeep.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: PartyPalette.orangeSoft.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PartyPalette.orangeSoft,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _consensusSeconds > 0
                        ? 'AUTO-APPROVING IN ${_consensusSeconds}S'
                        : 'LOCKING THE RESULT…',
                    style: GoogleFonts.outfit(
                      color: PartyPalette.orangeSoft,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            if (!round.challenge.isChoice) ...[
              SizedBox(height: compact ? 10 : 16),
              if (_isHost)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'WAITING FOR PLAYERS TO REVIEW...',
                    style: GoogleFonts.outfit(
                      color: PartyPalette.cream.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap:
                                _consensusSeconds > 0 && !widget.commandInFlight
                                ? () async {
                                    HapticFeedback.heavyImpact();
                                    setState(() => _myReviewVote = 0);
                                    await widget.onDisputeResult();
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              height: compact ? 44 : 50,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _myReviewVote == 0
                                      ? [
                                          const Color(0xFFEF4444),
                                          const Color(0xFF991B1B),
                                        ]
                                      : [
                                          PartyPalette.terracotta.withValues(
                                            alpha: 0.3,
                                          ),
                                          PartyPalette.nightDeep,
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(
                                    0xFFEF4444,
                                  ).withValues(alpha: 0.7),
                                  width: 1.4,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _myReviewVote == 0
                                        ? 'OBJECTED'
                                        : 'NO / OBJECT',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _consensusSeconds > 0
                                ? () {
                                    HapticFeedback.lightImpact();
                                    setState(() => _myReviewVote = 1);
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              height: compact ? 44 : 50,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _myReviewVote == 1
                                      ? [
                                          const Color(0xFF22C55E),
                                          const Color(0xFF15803D),
                                        ]
                                      : [
                                          const Color(
                                            0xFF22C55E,
                                          ).withValues(alpha: 0.25),
                                          PartyPalette.nightDeep,
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(
                                    0xFF22C55E,
                                  ).withValues(alpha: 0.7),
                                  width: 1.4,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _myReviewVote == 1
                                        ? 'APPROVED'
                                        : 'YES / APPROVE',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _centeredStage({
    required String kicker,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 320;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: compact ? 42 : 48,
              height: compact ? 42 : 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [PartyPalette.surfaceRaised, PartyPalette.nightDeep],
                ),
                border: Border.all(
                  color: PartyPalette.orangeSoft.withValues(alpha: 0.45),
                ),
              ),
              child: const Icon(
                Icons.hourglass_top_rounded,
                color: PartyPalette.orangeSoft,
                size: 21,
              ),
            ),
            SizedBox(height: compact ? 7 : 10),
            _StageKicker(kicker),
            SizedBox(height: compact ? 6 : 9),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: _stageTitleStyle(fontSize: compact ? 30 : 36),
              ),
            ),
            SizedBox(height: compact ? 8 : 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: compact ? 8 : 10,
                ),
                decoration: BoxDecoration(
                  color: PartyPalette.nightDeep.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: PartyPalette.cream.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: PartyPalette.orangeSoft,
                      size: 17,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        subtitle,
                        style: GoogleFonts.outfit(
                          color: PartyPalette.blueMuted,
                          fontSize: compact ? 11 : 12,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (action != null) ...[
              SizedBox(height: compact ? 10 : 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SizedBox(width: double.infinity, child: action),
              ),
            ],
          ],
        );
      },
    );
  }

  TextStyle _stageTitleStyle({double fontSize = 42}) {
    return const TextStyle(
      fontFamily: 'RehnCondensed',
      color: PartyPalette.cream,
      fontWeight: FontWeight.w900,
      height: 0.95,
    ).copyWith(fontSize: fontSize);
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required PartySceneAction? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (onPressed != null && !widget.commandInFlight)
            BoxShadow(
              color: PartyPalette.orange.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: widget.commandInFlight || onPressed == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                unawaited(onPressed());
              },
        icon: Icon(icon, size: 20),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: FilledButton.styleFrom(
          backgroundColor: PartyPalette.orange,
          foregroundColor: PartyPalette.nightDeep,
          disabledBackgroundColor: PartyPalette.surfaceRaised,
          disabledForegroundColor: PartyPalette.blueMuted,
          minimumSize: const Size(190, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }

  Widget _secondaryButton({
    required String label,
    required IconData icon,
    required PartySceneAction? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: widget.commandInFlight || onPressed == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              unawaited(onPressed());
            },
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: PartyPalette.cream,
        backgroundColor: PartyPalette.nightDeep.withValues(alpha: 0.35),
        disabledForegroundColor: PartyPalette.blueMuted.withValues(alpha: 0.5),
        side: BorderSide(
          color: PartyPalette.orange.withValues(alpha: 0.45),
          width: 1.2,
        ),
        minimumSize: const Size(180, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.outfit(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildCameraOverlay(List<PartyMoment> moments) {
    final controller = _cameraController;
    final round = widget.snapshot.round;
    final capturePhase =
        !round.challenge.isChoice &&
        (round.phase == PartyRoundPhase.action ||
            round.phase == PartyRoundPhase.resultEntry ||
            round.phase == PartyRoundPhase.resultConfirm);
    final canCapture =
        capturePhase &&
        moments.length < 3 &&
        !_isCapturing &&
        controller != null &&
        controller.value.isInitialized;

    return Positioned.fill(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _closeCamera();
        },
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
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
                    stops: [0, 0.25, 0.68, 1],
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
                  child: CustomPaint(painter: _PartyCameraFramePainter()),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
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
                                const SizedBox(height: 3),
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
                            _cameraTimer(),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        capturePhase
                            ? moments.isEmpty
                                  ? 'SAVE THE MOMENT'
                                  : '${moments.length} OF 3 SAVED'
                            : 'THE SHUTTER UNLOCKS WHEN THE TIMER STARTS',
                        style: GoogleFonts.outfit(
                          color: capturePhase
                              ? PartyPalette.orangeSoft
                              : Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          SizedBox(
                            width: 62,
                            height: 62,
                            child: moments.isEmpty
                                ? const SizedBox.shrink()
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
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
                                onTap: canCapture ? _captureMoment : null,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  width: 82,
                                  height: 82,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: canCapture
                                        ? PartyPalette.orange
                                        : Colors.white24,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 5,
                                    ),
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
                                              ? PartyPalette.nightDeep
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
      ),
    );
  }

  Widget _cameraTimer() {
    final urgent = widget.secondsRemaining <= 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: urgent ? const Color(0xFFE85B48) : PartyPalette.orange,
        ),
      ),
      child: Text(
        '00:${widget.secondsRemaining.toString().padLeft(2, '0')}',
        style: const TextStyle(
          fontFamily: 'RehnCondensed',
          color: Colors.white,
          fontSize: 21,
          fontWeight: FontWeight.w900,
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
              const CircularProgressIndicator(color: PartyPalette.orange)
            else
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white54,
                size: 40,
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
              const SizedBox(height: 16),
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
}

class _StageKicker extends StatelessWidget {
  final String text;

  const _StageKicker(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: PartyPalette.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: PartyPalette.orangeSoft.withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(
          color: PartyPalette.orangeSoft,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.45,
          height: 1,
        ),
      ),
    );
  }
}

class _PartyCameraFramePainter extends CustomPainter {
  const _PartyCameraFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const inset = 16.0;
    const arm = 42.0;
    final left = inset;
    final top = inset;
    final right = size.width - inset;
    final bottom = size.height - inset;
    final path = Path()
      ..moveTo(left, top + arm)
      ..lineTo(left, top)
      ..lineTo(left + arm, top)
      ..moveTo(right - arm, top)
      ..lineTo(right, top)
      ..lineTo(right, top + arm)
      ..moveTo(right, bottom - arm)
      ..lineTo(right, bottom)
      ..lineTo(right - arm, bottom)
      ..moveTo(left + arm, bottom)
      ..lineTo(left, bottom)
      ..lineTo(left, bottom - arm);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PartyCameraFramePainter oldDelegate) => false;
}
