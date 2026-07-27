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
  final int secondsRemaining;
  final bool commandInFlight;
  final double stageTop;
  final PartySceneAction onMarkReady;
  final PartySceneAction onStartAction;
  final PartySceneAction onOpenResultEntry;
  final PartySceneResultAction onSubmitResult;
  final PartySceneAction onConfirmResult;
  final PartySceneAction onDisputeResult;

  const PartySingleSceneLayer({
    super.key,
    required this.snapshot,
    required this.currentPlayer,
    required this.secondsRemaining,
    required this.commandInFlight,
    this.stageTop = 0,
    required this.onMarkReady,
    required this.onStartAction,
    required this.onOpenResultEntry,
    required this.onSubmitResult,
    required this.onConfirmResult,
    required this.onDisputeResult,
  });

  @override
  ConsumerState<PartySingleSceneLayer> createState() =>
      _PartySingleSceneLayerState();
}

class _PartySingleSceneLayerState extends ConsumerState<PartySingleSceneLayer>
    with WidgetsBindingObserver {
  final TextEditingController _resultController = TextEditingController();
  CameraController? _cameraController;
  Future<List<CameraDescription>>? _cameraDiscoveryFuture;
  List<CameraDescription> _availableCameras = const [];
  Timer? _consensusTimer;
  int? _consensusStateVersion;
  int _consensusSeconds = 6;
  int _cameraIndex = 0;
  bool _showCamera = false;
  bool _isOpeningCamera = false;
  bool _isCapturing = false;
  bool _captureFlash = false;
  bool _autoConfirmInFlight = false;
  String? _cameraError;

  bool get _isPerformancePhase {
    final phase = widget.snapshot.round.phase;
    return phase == PartyRoundPhase.ready ||
        phase == PartyRoundPhase.action ||
        phase == PartyRoundPhase.resultEntry ||
        phase == PartyRoundPhase.resultConfirm;
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
      _resultController.clear();
      _autoConfirmInFlight = false;
      _showCamera = false;
      unawaited(_disposeCamera());
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
    _resultController.dispose();
    unawaited(_cameraController?.dispose());
    super.dispose();
  }

  void _syncConsensusTimer() {
    final snapshot = widget.snapshot;
    if (snapshot.round.phase != PartyRoundPhase.resultConfirm) {
      _consensusTimer?.cancel();
      _consensusTimer = null;
      _consensusStateVersion = null;
      _consensusSeconds = 6;
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
        snapshot.round.phaseEndsAt ?? serverNow.add(const Duration(seconds: 6));

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

    _consensusSeconds = 6;
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
          left: 8,
          right: 8,
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
    final canOpenCamera = !_isPerformer && moments.length < 3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _buildStageLabel()),
              const SizedBox(width: 10),
              _cameraButton(
                enabled: canOpenCamera,
                momentCount: moments.length,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 360),
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
                child: _buildStageBody(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageLabel() {
    final round = widget.snapshot.round;
    final label = switch (round.phase) {
      PartyRoundPhase.ready =>
        round.performerReady ? 'READY TO START' : 'GET READY',
      PartyRoundPhase.action => 'LIVE CHALLENGE',
      PartyRoundPhase.resultEntry => 'RECORD THE RESULT',
      PartyRoundPhase.resultConfirm => 'FINAL CHECK',
      _ => 'PARTY MODE',
    };
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: round.phase == PartyRoundPhase.action
                ? PartyPalette.orange
                : PartyPalette.sage,
          ),
        ),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: PartyPalette.creamMuted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _cameraButton({required bool enabled, required int momentCount}) {
    return Semantics(
      button: true,
      label: 'Open camera',
      child: Material(
        color: PartyPalette.surfaceRaised.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: enabled ? _enterCamera : null,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    momentCount >= 3
                        ? Icons.check_rounded
                        : Icons.photo_camera_outlined,
                    color: enabled
                        ? PartyPalette.orangeSoft
                        : PartyPalette.blueMuted.withValues(alpha: 0.45),
                    size: 19,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'CAMERA  ·  $momentCount/3',
                    style: GoogleFonts.outfit(
                      color: enabled
                          ? PartyPalette.cream
                          : PartyPalette.blueMuted.withValues(alpha: 0.45),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
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

  Widget _buildStageBody() {
    final round = widget.snapshot.round;
    return switch (round.phase) {
      PartyRoundPhase.ready => _buildReady(),
      PartyRoundPhase.action => _buildAction(),
      PartyRoundPhase.resultEntry => _buildResultEntry(),
      PartyRoundPhase.resultConfirm => _buildResultReview(),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildReady() {
    final round = widget.snapshot.round;
    final performerName = round.performer.name.toUpperCase();
    String message;
    Widget? action;

    if (_isPerformer && !round.performerReady) {
      message = 'Take your position. Start only when you are actually ready.';
      action = _primaryButton(
        label: 'I AM READY',
        icon: Icons.check_rounded,
        onPressed: widget.onMarkReady,
      );
    } else if (_isHost && round.performerReady) {
      message = '$performerName is ready. Start the shared timer.';
      action = _primaryButton(
        label: 'START ${round.challenge.durationSeconds} SECONDS',
        icon: Icons.play_arrow_rounded,
        onPressed: widget.onStartAction,
      );
    } else {
      message = round.performerReady
          ? 'Waiting for the host to start.'
          : 'Waiting for $performerName to get ready.';
    }

    return _centeredStage(
      kicker: 'UP NEXT',
      title: performerName,
      subtitle: message,
      action: action,
    );
  }

  Widget _buildAction() {
    final round = widget.snapshot.round;
    final duration = round.challenge.durationSeconds;
    final progress = duration <= 0
        ? 0.0
        : (widget.secondsRemaining / duration).clamp(0.0, 1.0);
    final urgent = widget.secondsRemaining <= 10;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${round.performer.name.toUpperCase()} — GO',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: PartyPalette.cream,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 156,
          height: 156,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 6,
                strokeCap: StrokeCap.round,
                color: urgent ? const Color(0xFFD85C49) : PartyPalette.orange,
                backgroundColor: PartyPalette.surfaceRaised,
              ),
              Center(
                child: Text(
                  '00:${widget.secondsRemaining.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontFamily: 'RehnCondensed',
                    color: PartyPalette.cream,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    height: 0.9,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _isPerformer
              ? 'Give it a real attempt.'
              : _isHost
              ? (round.challenge.isBinary
                    ? 'Watch the success condition.'
                    : 'Keep the count clean.')
              : 'Watch the attempt. Save the moment if it gets good.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: PartyPalette.blueMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
        if (_isHost && widget.secondsRemaining == 0) ...[
          const SizedBox(height: 16),
          _secondaryButton(
            label: 'CONTINUE TO RESULT',
            icon: Icons.arrow_forward_rounded,
            onPressed: widget.onOpenResultEntry,
          ),
        ],
      ],
    );
  }

  Widget _buildResultEntry() {
    final round = widget.snapshot.round;
    if (!_isHost) {
      return _centeredStage(
        kicker: 'TIME IS UP',
        title: 'WAITING FOR THE HOST',
        subtitle: 'The observed result will appear here for a quick review.',
      );
    }

    if (round.challenge.isBinary) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _StageKicker('WHAT HAPPENED?'),
          const SizedBox(height: 12),
          Text(
            'Record the real result',
            textAlign: TextAlign.center,
            style: _stageTitleStyle(fontSize: 34),
          ),
          const SizedBox(height: 28),
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

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _StageKicker('ACTUAL RESULT'),
        const SizedBox(height: 10),
        Text(
          round.challenge.answerUnit.toUpperCase(),
          style: GoogleFonts.outfit(
            color: PartyPalette.blueMuted,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 270),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _resultController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'RehnCondensed',
                    color: PartyPalette.cream,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                  ),
                  decoration: InputDecoration(
                    hintText: '0–${round.challenge.maxResult}',
                    hintStyle: TextStyle(
                      color: PartyPalette.blueMuted.withValues(alpha: 0.35),
                    ),
                    filled: true,
                    fillColor: PartyPalette.surface.withValues(alpha: 0.92),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: PartyPalette.orange,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _submitTypedResult(),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                onPressed: widget.commandInFlight ? null : _submitTypedResult,
                icon: const Icon(Icons.arrow_forward_rounded),
                style: IconButton.styleFrom(
                  minimumSize: const Size(62, 62),
                  backgroundColor: PartyPalette.orange,
                  foregroundColor: PartyPalette.nightDeep,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _submitTypedResult() {
    final value = int.tryParse(_resultController.text);
    final max = widget.snapshot.round.challenge.maxResult;
    if (value == null || value < 0 || value > max) {
      HapticFeedback.mediumImpact();
      return;
    }
    FocusScope.of(context).unfocus();
    unawaited(widget.onSubmitResult(value));
  }

  Widget _buildResultReview() {
    final round = widget.snapshot.round;
    final result = round.challenge.isBinary
        ? (round.proposedResult == 1 ? 'SUCCESS' : 'FAILED')
        : '${round.proposedResult ?? '—'} ${round.challenge.answerUnit}';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _StageKicker('QUICK REVIEW'),
        const SizedBox(height: 12),
        Text(
          result.toUpperCase(),
          textAlign: TextAlign.center,
          style: _stageTitleStyle(
            fontSize: 54,
          ).copyWith(color: PartyPalette.orangeSoft),
        ),
        const SizedBox(height: 16),
        Text(
          _consensusSeconds > 0
              ? 'LOCKS IN ${_consensusSeconds}s'
              : 'LOCKING THE RESULT…',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: PartyPalette.blueMuted,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 22),
        _secondaryButton(
          label: 'OBJECT — RESULT IS WRONG',
          icon: Icons.flag_outlined,
          onPressed: _consensusSeconds > 0 ? widget.onDisputeResult : null,
        ),
      ],
    );
  }

  Widget _centeredStage({
    required String kicker,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StageKicker(kicker),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _stageTitleStyle(),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: PartyPalette.blueMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
        if (action != null) ...[const SizedBox(height: 26), action],
      ],
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
    return FilledButton.icon(
      onPressed: widget.commandInFlight || onPressed == null
          ? null
          : () => unawaited(onPressed()),
      icon: Icon(icon, size: 20),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(
        backgroundColor: PartyPalette.orange,
        foregroundColor: PartyPalette.nightDeep,
        disabledBackgroundColor: PartyPalette.surfaceRaised,
        disabledForegroundColor: PartyPalette.blueMuted,
        minimumSize: const Size(190, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
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
          : () => unawaited(onPressed()),
      icon: Icon(icon, size: 19),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: PartyPalette.cream,
        disabledForegroundColor: PartyPalette.blueMuted.withValues(alpha: 0.5),
        side: BorderSide(color: PartyPalette.orange.withValues(alpha: 0.52)),
        minimumSize: const Size(180, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.35,
        ),
      ),
    );
  }

  Widget _buildCameraOverlay(List<PartyMoment> moments) {
    final controller = _cameraController;
    final round = widget.snapshot.round;
    final capturePhase =
        round.phase == PartyRoundPhase.action ||
        round.phase == PartyRoundPhase.resultEntry ||
        round.phase == PartyRoundPhase.resultConfirm;
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
    return Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.outfit(
        color: PartyPalette.orangeSoft,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.8,
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
