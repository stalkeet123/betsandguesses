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
  SoundHandle? _tickingHandle;
  SoundHandle? _payoutHandle;
  Timer? _payoutStopTimer;
  final Set<Timer> _fadeStopTimers = {};
  Future<void>? _initFuture;
  final Map<String, Future<AudioSource?>> _sourceLoadFutures = {};
  String? _pendingBgmKey;
  String? _desiredBgmKey;
  int _bgmRequestId = 0;
  bool _isAppActive = true;
  bool _disposed = false;

  static const _backgroundMusic = 'assets/sound/arka plan.mp3';
  static const _elevatorMusic =
      'assets/sound/686020__yellowtree__elevator-music.wav';
  static const _questionSuspenseMusic =
      'assets/sound/mixkit-game-show-suspense-waiting-667.wav';
  static const _questionReveal = 'assets/sound/soru-acılma.wav';
  static const _tickingClock = 'assets/sound/saat.wav';
  static const _timeUp = 'assets/sound/sürebitti.wav';
  static const _chipSelect = 'assets/sound/chip1.wav';
  static const _chipDrop = 'assets/sound/çip2.wav';
  static const _chipLoss = 'assets/sound/çipkaybolma.wav';
  static const _resultReveal = 'assets/sound/sonuç açıklanma.flac';
  static const _payoutWin = 'assets/sound/532861__joma86__allinpushchips.wav';
  static const _epicFanfare =
      'assets/sound/514492__metrostock99__grand-entrance-intro.wav';

  AudioService(this._prefs) {
    _isMuted = _prefs.getBool('audio_muted') ?? false;
    _initFuture = _initPlayers();
  }

  bool get isMuted => _isMuted;

  Future<void> _initPlayers() async {
    try {
      // Hot restart can preserve the native engine while losing Dart-side
      // temporary-directory state. Recreate both sides together.
      if (SoLoud.instance.isInitialized) SoLoud.instance.deinit();
      await SoLoud.instance.init();
      await _applyVolumes();
    } catch (e) {
      _initFuture = null;
      debugPrint('SoLoud init failed: $e');
    }
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
    if (_disposed || !SoLoud.instance.isInitialized) return null;

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

  Future<void> _applyVolumes() async {
    if (!SoLoud.instance.isInitialized) return;
    SoLoud.instance.setGlobalVolume(_isMuted ? 0.0 : 1.0);
  }

  Future<void> _fadeToBgm(
    Future<AudioSource?> Function() loadSource, {
    double volume = 0.15,
    String? bgmKey,
    Duration fadeDuration = const Duration(seconds: 1),
  }) async {
    if (bgmKey != null) {
      _desiredBgmKey = bgmKey;
      _pendingBgmKey = bgmKey;
    }
    final requestId = ++_bgmRequestId;
    if (_isMuted || !_isAppActive || _disposed) return;

    final source = await loadSource();
    if (_isMuted || !_isAppActive || _disposed) return;
    if (!SoLoud.instance.isInitialized || source == null) return;
    if (requestId != _bgmRequestId) return;
    if (bgmKey != null && _pendingBgmKey != bgmKey) return;
    if (bgmKey != null) _pendingBgmKey = null;

    if (_currentBgmSource == source && _bgmHandle != null) return;

    final oldHandle = _bgmHandle;
    if (oldHandle != null) {
      SoLoud.instance.fadeVolume(oldHandle, 0.0, fadeDuration);
      _scheduleHandleStop(oldHandle, fadeDuration);
    }

    _currentBgmSource = source;
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
        await SoLoud.instance.stop(newHandle);
        return;
      }
      _bgmHandle = newHandle;
      SoLoud.instance.fadeVolume(newHandle, volume, fadeDuration);
    } catch (e) {
      debugPrint('Fade to BGM failed: $e');
    }
  }

  Future<void> startLobbyMusic() =>
      _fadeToBgm(_loadElevatorSource, volume: 0.12, bgmKey: 'lobby');

  Future<void> startQuestionMusic() => _fadeToBgm(
    _loadQuestionSuspenseSource,
    volume: 0.12,
    bgmKey: 'question',
    fadeDuration: const Duration(milliseconds: 350),
  );

  Future<void> startMainBgm() =>
      _fadeToBgm(_loadBackgroundSource, volume: 0.12, bgmKey: 'main');

  Future<void> stopBackgroundMusic() async {
    _desiredBgmKey = null;
    await _stopBackgroundMusic(preserveDesired: false);
  }

  Future<void> _stopBackgroundMusic({
    required bool preserveDesired,
    bool immediate = false,
  }) async {
    if (!preserveDesired) _desiredBgmKey = null;
    _pendingBgmKey = null;
    _bgmRequestId++;
    if (!SoLoud.instance.isInitialized) return;
    final handle = _bgmHandle;
    _bgmHandle = null;
    _currentBgmSource = null;
    if (handle != null) {
      if (immediate) {
        await SoLoud.instance.stop(handle);
      } else {
        SoLoud.instance.fadeVolume(handle, 0.0, const Duration(seconds: 1));
        _scheduleHandleStop(handle);
      }
    }
  }

  void _scheduleHandleStop(
    SoundHandle handle, [
    Duration delay = const Duration(seconds: 1),
  ]) {
    late final Timer timer;
    timer = Timer(delay, () {
      _fadeStopTimers.remove(timer);
      if (SoLoud.instance.isInitialized) {
        unawaited(SoLoud.instance.stop(handle));
      }
    });
    _fadeStopTimers.add(timer);
  }

  /// Prepare only the assets needed at the first question transition.
  Future<void> prepareGameAudio() async {
    await _ensureInitialized();
    await Future.wait([
      _loadQuestionSuspenseSource(),
      _loadQuestionRevealSource(),
      _loadChipSelectSource(),
      _loadChipDropSource(),
    ]);
  }

  Future<void> startTicking() async {
    if (_isMuted || !_isAppActive || _isTickingPlaying) return;
    final source = await _loadTickingClockSource();
    if (_isMuted ||
        _isTickingPlaying ||
        !_isAppActive ||
        _disposed ||
        source == null ||
        !SoLoud.instance.isInitialized) {
      return;
    }
    try {
      _tickingHandle = await SoLoud.instance.play(
        source,
        volume: 0.15,
        looping: true,
      );
      _isTickingPlaying = true;
    } catch (error) {
      debugPrint('Audio ticking failed: $error');
    }
  }

  Future<void> stopTicking() async {
    _isTickingPlaying = false;
    if (!SoLoud.instance.isInitialized) {
      _tickingHandle = null;
      return;
    }
    if (_tickingHandle != null) {
      await SoLoud.instance.stop(_tickingHandle!);
      _tickingHandle = null;
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
      await stopPayout();
    } else if (_isAppActive) {
      await _resumeDesiredBgm();
    }
  }

  Future<void> setAppActive(bool active) async {
    if (_disposed || _isAppActive == active) return;
    _isAppActive = active;
    if (!active) {
      await _stopBackgroundMusic(preserveDesired: true, immediate: true);
      await stopTicking();
      await stopPayout();
      return;
    }
    if (!_isMuted) await _resumeDesiredBgm();
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
    }
  }

  Future<void> _playSfx(
    Future<AudioSource?> Function() loadSource, {
    double volume = 0.48,
  }) async {
    if (_isMuted || !_isAppActive) return;
    final source = await loadSource();
    if (_isMuted ||
        _disposed ||
        !_isAppActive ||
        source == null ||
        !SoLoud.instance.isInitialized) {
      return;
    }
    try {
      await SoLoud.instance.play(source, volume: volume);
    } catch (error) {
      debugPrint('Audio sfx failed: $error');
    }
  }

  Future<void> playClick() => _playSfx(_loadChipSelectSource, volume: 0.9);
  Future<void> playButtonTap() => _playSfx(_loadChipSelectSource, volume: 0.28);
  Future<void> playChip() => _playSfx(_loadChipSelectSource, volume: 0.78);
  Future<void> playDrop() => _playSfx(_loadChipDropSource, volume: 0.85);
  Future<void> playClink() => _playSfx(_loadChipDropSource, volume: 0.85);
  Future<void> playChipLoss() => _playSfx(_loadChipLossSource, volume: 0.65);
  Future<void> playQuestionReveal() =>
      _playSfx(_loadQuestionRevealSource, volume: 0.8);
  Future<void> playTimeUp() => _playSfx(_loadTimeUpSource, volume: 0.7);
  Future<void> playSuccess() => _playSfx(_loadEpicFanfareSource, volume: 0.85);
  Future<void> playResultReveal() =>
      _playSfx(_loadResultRevealSource, volume: 0.85);

  Future<void> playEpicFanfare() =>
      _playSfx(_loadEpicFanfareSource, volume: 0.9);

  Future<void> playPayout() async {
    if (_isMuted || !_isAppActive) return;
    final source = await _loadPayoutWinSource();
    if (_isMuted ||
        _disposed ||
        !_isAppActive ||
        source == null ||
        !SoLoud.instance.isInitialized) {
      return;
    }
    try {
      _payoutStopTimer?.cancel();
      if (_payoutHandle != null) {
        await SoLoud.instance.stop(_payoutHandle!);
      }
      _payoutHandle = await SoLoud.instance.play(source, volume: 0.8);
      _payoutStopTimer = Timer(const Duration(seconds: 4), stopPayout);
    } catch (error) {
      debugPrint('Audio payout failed: $error');
    }
  }

  Future<void> stopPayout() async {
    _payoutStopTimer?.cancel();
    _payoutStopTimer = null;
    if (!SoLoud.instance.isInitialized) {
      _payoutHandle = null;
      return;
    }
    if (_payoutHandle != null) {
      await SoLoud.instance.stop(_payoutHandle!);
      _payoutHandle = null;
    }
  }

  Future<void> playRandomChipSound() async {
    final roll = Random().nextInt(4);
    await _playSfx(_loadChipSelectSource, volume: roll == 0 ? 0.72 : 0.78);
  }

  void dispose() {
    _disposed = true;
    _bgmRequestId++;
    _payoutStopTimer?.cancel();
    for (final timer in _fadeStopTimers) {
      timer.cancel();
    }
    _fadeStopTimers.clear();
    unawaited(_disposeAudio());
  }

  Future<void> _disposeAudio() async {
    if (!SoLoud.instance.isInitialized) return;
    final handles = [_bgmHandle, _tickingHandle, _payoutHandle];
    _bgmHandle = null;
    _tickingHandle = null;
    _payoutHandle = null;
    for (final handle in handles.whereType<SoundHandle>()) {
      await SoLoud.instance.stop(handle);
    }
    SoLoud.instance.deinit();
  }
}
