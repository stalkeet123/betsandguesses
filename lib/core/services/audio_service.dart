import 'dart:async';
import 'dart:math';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  final SharedPreferences _prefs;
  bool _isMuted = false;
  bool _isTickingPlaying = false;

  AudioSource? _backgroundSource;
  AudioSource? _elevatorSource;
  AudioSource? _questionSuspenseSource;
  AudioSource? _questionRevealSource;
  AudioSource? _tickingClockSource;
  AudioSource? _timeUpSource;
  AudioSource? _chipSelectSource;
  AudioSource? _chipDropSource;
  AudioSource? _chipLossSource;
  AudioSource? _resultRevealSource;
  AudioSource? _payoutWinSource;
  AudioSource? _epicFanfareSource;

  SoundHandle? _bgmHandle;
  AudioSource? _currentBgmSource;
  String? _currentBgmKey;
  SoundHandle? _tickingHandle;
  Future<void>? _tickingStartFuture;
  int _tickingGeneration = 0;

  final Set<Timer> _fadeStopTimers = {};
  Future<void>? _initFuture;
  final Map<String, Future<AudioSource?>> _sourceLoadFutures = {};
  String? _pendingBgmKey;
  String? _desiredBgmKey;
  int _bgmRequestId = 0;
  bool _isAppActive = true;
  bool _bgmPausedForLifecycle = false;
  bool _disposed = false;
  bool _webEngineReady = false;
  bool _webUserGestureReceived = !kIsWeb;
  final Map<String, DateTime> _lastSfxPlayedAt = {};

  static const _backgroundMusic = 'assets/sound/bgm_main.mp3';
  static const _elevatorMusic = 'assets/sound/bgm_lobby.wav';
  static const _questionSuspenseMusic = 'assets/sound/bgm_question.wav';
  static const _questionReveal = 'assets/sound/sfx_question_reveal.wav';
  static const _tickingClock = 'assets/sound/sfx_clock.wav';
  static const _timeUp = 'assets/sound/sfx_time_up.wav';
  static const _chipSelect = 'assets/sound/sfx_chip_select.wav';
  static const _chipDrop = 'assets/sound/sfx_chip_drop.wav';
  static const _chipLoss = 'assets/sound/sfx_chip_loss.wav';
  static const _resultReveal = 'assets/sound/sfx_result_reveal.flac';
  static const _payoutWin = 'assets/sound/sfx_payout.wav';
  static const _epicFanfare = 'assets/sound/sfx_fanfare.wav';

  AudioService(this._prefs) {
    _isMuted = _prefs.getBool('audio_muted') ?? false;
    _initFuture = _initPlayers();
  }

  bool get isMuted => _isMuted;

  bool get _engineReady =>
      kIsWeb ? _webEngineReady : SoLoud.instance.isInitialized;

  Future<void> _initPlayers() async {
    Object? lastError;
    final attempts = kIsWeb ? 20 : 1;
    final bufferSize =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? 4096
        : 2048;

    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        // A larger Android buffer protects slower devices from audio
        // underruns, which are heard as a repeating buzz or stutter.
        await SoLoud.instance.init(sampleRate: 44100, bufferSize: bufferSize);
        if (kIsWeb) _webEngineReady = true;
        SoLoud.instance.setMaxActiveVoiceCount(16);
        await _applyVolumes();
        return;
      } catch (error) {
        lastError = error;
        if (kIsWeb) _webEngineReady = false;
        if (!kIsWeb || attempt + 1 >= attempts) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }

    _initFuture = null;
    debugPrint('SoLoud init failed: $lastError');
  }

  Future<void> _ensureInitialized() async {
    if (_disposed) return;
    final initFuture = _initFuture ??= _initPlayers();
    await initFuture;
  }

  Future<AudioSource?> _loadSource(
    String asset,
    AudioSource? cached,
    void Function(AudioSource source) cache,
  ) async {
    if (cached != null) return cached;
    if (_disposed) return null;

    await _ensureInitialized();
    if (_disposed || !_engineReady) return null;

    final loading = _sourceLoadFutures.putIfAbsent(asset, () async {
      try {
        final source = await SoLoud.instance.loadAsset(asset);
        if (!_disposed) cache(source);
        return source;
      } catch (error) {
        debugPrint('Audio load failed for $asset: $error');
        return null;
      }
    });

    final source = await loading;
    _sourceLoadFutures.remove(asset);
    return source;
  }

  Future<AudioSource?> _loadBackgroundSource() => _loadSource(
    _backgroundMusic,
    _backgroundSource,
    (source) => _backgroundSource = source,
  );

  Future<AudioSource?> _loadElevatorSource() => _loadSource(
    _elevatorMusic,
    _elevatorSource,
    (source) => _elevatorSource = source,
  );

  Future<AudioSource?> _loadQuestionSuspenseSource() => _loadSource(
    _questionSuspenseMusic,
    _questionSuspenseSource,
    (source) => _questionSuspenseSource = source,
  );

  Future<AudioSource?> _loadQuestionRevealSource() => _loadSource(
    _questionReveal,
    _questionRevealSource,
    (source) => _questionRevealSource = source,
  );

  Future<AudioSource?> _loadTickingClockSource() => _loadSource(
    _tickingClock,
    _tickingClockSource,
    (source) => _tickingClockSource = source,
  );

  Future<AudioSource?> _loadTimeUpSource() =>
      _loadSource(_timeUp, _timeUpSource, (source) => _timeUpSource = source);

  Future<AudioSource?> _loadChipSelectSource() => _loadSource(
    _chipSelect,
    _chipSelectSource,
    (source) => _chipSelectSource = source,
  );

  Future<AudioSource?> _loadChipDropSource() => _loadSource(
    _chipDrop,
    _chipDropSource,
    (source) => _chipDropSource = source,
  );

  Future<AudioSource?> _loadChipLossSource() => _loadSource(
    _chipLoss,
    _chipLossSource,
    (source) => _chipLossSource = source,
  );

  Future<AudioSource?> _loadResultRevealSource() => _loadSource(
    _resultReveal,
    _resultRevealSource,
    (source) => _resultRevealSource = source,
  );

  Future<AudioSource?> _loadPayoutWinSource() => _loadSource(
    _payoutWin,
    _payoutWinSource,
    (source) => _payoutWinSource = source,
  );

  Future<AudioSource?> _loadEpicFanfareSource() => _loadSource(
    _epicFanfare,
    _epicFanfareSource,
    (source) => _epicFanfareSource = source,
  );

  Future<void> unlockFromUserGesture() async {
    if (!kIsWeb || _disposed) return;
    _webUserGestureReceived = true;
    await _ensureInitialized();
    await _applyVolumes();
    if (!_isMuted && _isAppActive) await _resumeDesiredBgm();
  }

  Future<void> _applyVolumes() async {
    if (!_engineReady) return;
    SoLoud.instance.setGlobalVolume(
      _isMuted || !_isAppActive || (kIsWeb && !_webUserGestureReceived)
          ? 0.0
          : 1.0,
    );
  }

  Future<void> _fadeToBgm(
    Future<AudioSource?> Function() loadSource, {
    double volume = 0.15,
    String? bgmKey,
    Duration fadeDuration = const Duration(milliseconds: 300),
  }) async {
    if (bgmKey != null) {
      _desiredBgmKey = bgmKey;
      if (_currentBgmKey == bgmKey && _bgmHandle != null) {
        _pendingBgmKey = null;
        return;
      }
    }
    if (_isMuted ||
        !_isAppActive ||
        _disposed ||
        (kIsWeb && !_webUserGestureReceived))
      return;
    if (bgmKey != null && _pendingBgmKey == bgmKey) {
      return;
    }

    if (bgmKey != null) _pendingBgmKey = bgmKey;
    final requestId = ++_bgmRequestId;
    final source = await loadSource();
    if (_isMuted ||
        !_isAppActive ||
        _disposed ||
        !_engineReady ||
        source == null) {
      if (requestId == _bgmRequestId && _pendingBgmKey == bgmKey) {
        _pendingBgmKey = null;
      }
      return;
    }
    if (requestId != _bgmRequestId) return;
    if (bgmKey != null && _pendingBgmKey != bgmKey) return;
    _pendingBgmKey = null;

    if (_currentBgmSource == source && _bgmHandle != null) {
      _currentBgmKey = bgmKey;
      try {
        SoLoud.instance.fadeVolume(_bgmHandle!, volume, fadeDuration);
      } catch (error) {
        debugPrint('BGM volume update failed: $error');
      }
      return;
    }

    final oldHandle = _bgmHandle;
    _bgmHandle = null;
    _currentBgmSource = null;
    _currentBgmKey = null;
    _bgmPausedForLifecycle = false;
    if (oldHandle != null) {
      try {
        SoLoud.instance.fadeVolume(oldHandle, 0.0, fadeDuration);
        _scheduleHandleStop(oldHandle, fadeDuration);
      } catch (error) {
        await _safeStop(oldHandle);
      }
    }

    try {
      final newHandle = await SoLoud.instance.play(
        source,
        volume: 0.0,
        looping: true,
      );
      if (_disposed ||
          _isMuted ||
          !_isAppActive ||
          requestId != _bgmRequestId) {
        await _safeStop(newHandle);
        return;
      }
      _bgmHandle = newHandle;
      _currentBgmSource = source;
      _currentBgmKey = bgmKey;
      _bgmPausedForLifecycle = false;
      SoLoud.instance.setProtectVoice(newHandle, true);
      SoLoud.instance.fadeVolume(newHandle, volume, fadeDuration);
    } catch (error) {
      debugPrint('Fade to BGM failed: $error');
    }
  }

  Future<void> startLobbyMusic() =>
      _fadeToBgm(_loadElevatorSource, volume: 0.12, bgmKey: 'lobby');

  Future<void> startQuestionMusic() => _fadeToBgm(
    _loadQuestionSuspenseSource,
    volume: 0.12,
    bgmKey: 'question',
    fadeDuration: const Duration(milliseconds: 220),
  );

  Future<void> startMainBgm() =>
      _fadeToBgm(_loadBackgroundSource, volume: 0.12, bgmKey: 'main');

  Future<void> startPartyGameBgm() =>
      _fadeToBgm(_loadBackgroundSource, volume: 0.06, bgmKey: 'party_main');

  Future<void> startGameSilence() async {
    _desiredBgmKey = null;
    await _stopBackgroundMusic(preserveDesired: false, immediate: true);
  }

  Future<void> stopBackgroundMusic({bool immediate = false}) async {
    _desiredBgmKey = null;
    await _stopBackgroundMusic(preserveDesired: false, immediate: immediate);
  }

  Future<void> _stopBackgroundMusic({
    required bool preserveDesired,
    bool immediate = false,
  }) async {
    if (!preserveDesired) _desiredBgmKey = null;
    _pendingBgmKey = null;
    _bgmRequestId++;

    final currentHandle = _bgmHandle;
    final handles = <SoundHandle>{
      if (currentHandle != null) currentHandle,
      ...?_backgroundSource?.handles,
      ...?_elevatorSource?.handles,
      ...?_questionSuspenseSource?.handles,
    };
    _bgmHandle = null;
    _currentBgmSource = null;
    _currentBgmKey = null;
    _bgmPausedForLifecycle = false;
    if (!_engineReady) return;

    for (final handle in handles) {
      if (!immediate && handle == currentHandle) {
        try {
          const fadeDuration = Duration(milliseconds: 250);
          SoLoud.instance.fadeVolume(handle, 0.0, fadeDuration);
          _scheduleHandleStop(handle, fadeDuration);
        } catch (error) {
          await _safeStop(handle);
        }
      } else {
        await _safeStop(handle);
      }
    }
  }

  void _scheduleHandleStop(
    SoundHandle handle, [
    Duration delay = const Duration(milliseconds: 250),
  ]) {
    late final Timer timer;
    timer = Timer(delay, () {
      _fadeStopTimers.remove(timer);
      unawaited(_safeStop(handle));
    });
    _fadeStopTimers.add(timer);
  }

  Future<void> _safeStop(SoundHandle handle) async {
    if (!_engineReady) return;
    try {
      await SoLoud.instance.stop(handle);
    } catch (error) {
      debugPrint('Audio stop failed for $handle: $error');
    }
  }

  /// Prepare only the assets needed at the first question transition.
  Future<void> prepareGameAudio() async {
    await _ensureInitialized();
    await Future.wait(<Future<AudioSource?>>[
      _loadQuestionSuspenseSource(),
      _loadQuestionRevealSource(),
      _loadChipSelectSource(),
      _loadChipDropSource(),
      if (kIsWeb) _loadResultRevealSource(),
      if (kIsWeb) _loadChipLossSource(),
      if (kIsWeb) _loadPayoutWinSource(),
    ]);
  }

  /// Preloads the Party Poll reveal cues without changing Classic playback.
  Future<void> preparePartyPollRevealAudio() async {
    await _ensureInitialized();
    await Future.wait(<Future<AudioSource?>>[
      _loadResultRevealSource(),
      _loadPayoutWinSource(),
      _loadChipLossSource(),
    ]);
  }

  Future<void> startTicking() {
    if (_isMuted || !_isAppActive || _isTickingPlaying || _disposed) {
      return Future<void>.value();
    }
    final pendingStart = _tickingStartFuture;
    if (pendingStart != null) return pendingStart;

    final generation = _tickingGeneration;
    late final Future<void> startFuture;
    startFuture = _startTicking(generation).whenComplete(() {
      if (identical(_tickingStartFuture, startFuture)) {
        _tickingStartFuture = null;
      }
    });
    _tickingStartFuture = startFuture;
    return startFuture;
  }

  Future<void> _startTicking(int generation) async {
    final source = await _loadTickingClockSource();
    if (_isMuted ||
        !_isAppActive ||
        _disposed ||
        generation != _tickingGeneration ||
        source == null ||
        !_engineReady) {
      return;
    }

    // Clean up any loop left by an older race before starting the sole timer.
    for (final handle in source.handles.toList(growable: false)) {
      await _safeStop(handle);
    }
    if (generation != _tickingGeneration || !_isAppActive || _isMuted) return;

    try {
      final handle = await SoLoud.instance.play(
        source,
        volume: 0.15,
        looping: true,
      );
      if (_disposed ||
          _isMuted ||
          !_isAppActive ||
          generation != _tickingGeneration) {
        await _safeStop(handle);
        return;
      }
      SoLoud.instance.setProtectVoice(handle, true);
      _tickingHandle = handle;
      _isTickingPlaying = true;
    } catch (error) {
      debugPrint('Audio ticking failed: $error');
    }
  }

  Future<void> stopTicking() async {
    _tickingGeneration++;
    _tickingStartFuture = null;
    _isTickingPlaying = false;

    final currentHandle = _tickingHandle;
    final handles = <SoundHandle>{
      if (currentHandle != null) currentHandle,
      ...?_tickingClockSource?.handles,
    };
    _tickingHandle = null;
    for (final handle in handles) {
      await _safeStop(handle);
    }
  }

  Future<void> stopAllLoops() async {
    await stopBackgroundMusic();
    await stopTicking();
    await stopPayout();
  }

  Future<void> toggleMute() async {
    await setMuted(!_isMuted);
  }

  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
    await _prefs.setBool('audio_muted', _isMuted);
    await _applyVolumes();

    if (_isMuted) {
      await _stopBackgroundMusic(preserveDesired: true, immediate: true);
      await stopTicking();
      await stopTransientEffects();
    } else if (_isAppActive) {
      await _resumeDesiredBgm();
    }
  }

  Future<void> setAppActive(bool active) async {
    if (_disposed || _isAppActive == active) return;
    _isAppActive = active;
    if (!active) {
      _bgmRequestId++;
      _pendingBgmKey = null;
      final handle = _bgmHandle;
      if (handle != null && _engineReady) {
        try {
          SoLoud.instance.setPause(handle, true);
          _bgmPausedForLifecycle = true;
        } catch (_) {
          _bgmHandle = null;
          _currentBgmSource = null;
          _currentBgmKey = null;
          _bgmPausedForLifecycle = false;
          await _safeStop(handle);
        }
      }
      await stopTicking();
      await stopTransientEffects();
      await _applyVolumes();
      return;
    }
    await _applyVolumes();
    final pausedHandle = _bgmHandle;
    if (!_isMuted && _bgmPausedForLifecycle && pausedHandle != null) {
      try {
        SoLoud.instance.setPause(pausedHandle, false);
        _bgmPausedForLifecycle = false;
      } catch (_) {
        _bgmHandle = null;
        _currentBgmSource = null;
        _currentBgmKey = null;
        _bgmPausedForLifecycle = false;
        await _safeStop(pausedHandle);
      }
    }
    if (!_isMuted && (_currentBgmKey != _desiredBgmKey || _bgmHandle == null)) {
      await _resumeDesiredBgm();
    }
  }

  Future<void> _resumeDesiredBgm() async {
    switch (_desiredBgmKey) {
      case 'lobby':
        await startLobbyMusic();
        return;
      case 'question':
        await startQuestionMusic();
        return;
      case 'main':
        await startMainBgm();
        return;
      case 'party_main':
        await startPartyGameBgm();
        return;
    }
  }

  Future<void> _playSfx(
    Future<AudioSource?> Function() loadSource, {
    required String key,
    double volume = 0.48,
    Duration minInterval = const Duration(milliseconds: 45),
    int maxInstances = 3,
  }) async {
    if (_isMuted ||
        !_isAppActive ||
        _disposed ||
        (kIsWeb && !_webUserGestureReceived))
      return;

    final requestedAt = DateTime.now();
    final previousRequest = _lastSfxPlayedAt[key];
    if (previousRequest != null &&
        requestedAt.difference(previousRequest) < minInterval) {
      return;
    }

    final source = await loadSource();
    if (_isMuted ||
        _disposed ||
        !_isAppActive ||
        source == null ||
        !_engineReady) {
      return;
    }

    final playAt = DateTime.now();
    final previousPlay = _lastSfxPlayedAt[key];
    if (previousPlay != null && playAt.difference(previousPlay) < minInterval) {
      return;
    }
    if (source.handles.length >= maxInstances) return;

    _lastSfxPlayedAt[key] = playAt;
    try {
      await SoLoud.instance.play(source, volume: volume);
    } catch (error) {
      debugPrint('Audio sfx failed for $key: $error');
    }
  }

  Future<void> playClick() =>
      _playSfx(_loadChipSelectSource, key: 'chip-select', volume: 0.72);

  Future<void> playButtonTap() =>
      _playSfx(_loadChipSelectSource, key: 'chip-select', volume: 0.28);

  Future<void> playChip() =>
      _playSfx(_loadChipSelectSource, key: 'chip-select', volume: 0.68);

  Future<void> playDrop() =>
      _playSfx(_loadChipDropSource, key: 'chip-drop', volume: 0.75);

  Future<void> playClink() => _playSfx(
    _loadChipDropSource,
    key: 'chip-drop',
    volume: 0.72,
    minInterval: const Duration(milliseconds: 90),
  );

  Future<void> playChipLoss() => _playSfx(
    _loadChipLossSource,
    key: 'chip-loss',
    volume: 0.58,
    minInterval: const Duration(milliseconds: 500),
    maxInstances: 1,
  );

  Future<void> playQuestionReveal() => _playSfx(
    _loadQuestionRevealSource,
    key: 'question-reveal',
    volume: 0.72,
    minInterval: const Duration(milliseconds: 750),
    maxInstances: 1,
  );

  Future<void> playTimeUp() => _playSfx(
    _loadTimeUpSource,
    key: 'time-up',
    volume: 0.62,
    minInterval: const Duration(milliseconds: 750),
    maxInstances: 1,
  );

  Future<void> playSuccess() => _playSfx(
    _loadEpicFanfareSource,
    key: 'fanfare',
    volume: 0.75,
    minInterval: const Duration(seconds: 2),
    maxInstances: 1,
  );

  Future<void> playResultReveal() => _playSfx(
    _loadResultRevealSource,
    key: 'result-reveal',
    volume: 0.72,
    minInterval: const Duration(seconds: 2),
    maxInstances: 1,
  );

  Future<void> playEpicFanfare() => _playSfx(
    _loadEpicFanfareSource,
    key: 'fanfare',
    volume: 0.78,
    minInterval: const Duration(seconds: 2),
    maxInstances: 1,
  );

  Future<void> playPayout() => _playSfx(
    _loadPayoutWinSource,
    key: 'payout',
    volume: 0.72,
    minInterval: const Duration(milliseconds: 300),
    maxInstances: 1,
  );

  Future<void> _stopSourceHandles(AudioSource? source) async {
    final handles = source?.handles.toList(growable: false);
    if (handles == null) {
      return;
    }
    for (final handle in handles) {
      await _safeStop(handle);
    }
  }

  Future<void> stopResultReveal() => _stopSourceHandles(_resultRevealSource);
  Future<void> stopFanfare() => _stopSourceHandles(_epicFanfareSource);

  Future<void> stopTransientEffects() async {
    await stopResultReveal();
    await stopFanfare();
    await _stopSourceHandles(_questionRevealSource);
    await _stopSourceHandles(_timeUpSource);
    await _stopSourceHandles(_chipLossSource);
    await stopPayout();
  }

  Future<void> stopPayout() async {
    final handles = _payoutWinSource?.handles.toList(growable: false);
    if (handles == null) {
      return;
    }
    for (final handle in handles) {
      await _safeStop(handle);
    }
  }

  Future<void> playRandomChipSound() async {
    final roll = Random().nextInt(4);
    await _playSfx(
      _loadChipSelectSource,
      key: 'chip-select',
      volume: roll == 0 ? 0.62 : 0.68,
    );
  }

  void dispose() {
    _disposed = true;
    _bgmRequestId++;
    _tickingGeneration++;
    for (final timer in _fadeStopTimers) {
      timer.cancel();
    }
    _fadeStopTimers.clear();
    unawaited(_disposeAudio());
  }

  Future<void> _disposeAudio() async {
    if (!_engineReady) return;
    await _stopBackgroundMusic(preserveDesired: false, immediate: true);
    await stopTicking();
    await stopPayout();
    if (!_engineReady) return;
    SoLoud.instance.deinit();
    if (kIsWeb) _webEngineReady = false;
  }
}
