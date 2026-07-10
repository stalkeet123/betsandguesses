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

  static const _backgroundMusic = 'assets/sound/arka plan.mp3';
  static const _elevatorMusic = 'assets/sound/686020__yellowtree__elevator-music.wav';
  static const _questionSuspenseMusic = 'assets/sound/mixkit-game-show-suspense-waiting-667.wav';
  static const _questionReveal = 'assets/sound/soru-acılma.wav';
  static const _tickingClock = 'assets/sound/saat.wav';
  static const _timeUp = 'assets/sound/sürebitti.wav';
  static const _chipSelect = 'assets/sound/chip1.wav';
  static const _chipDrop = 'assets/sound/çip2.wav';
  static const _chipLoss = 'assets/sound/çipkaybolma.wav';
  static const _resultReveal = 'assets/sound/sonuç açıklanma.flac';
  static const _payoutWin = 'assets/sound/532861__joma86__allinpushchips.wav';
  static const _epicFanfare = 'assets/sound/514492__metrostock99__grand-entrance-intro.wav';

  AudioService(this._prefs) {
    _isMuted = _prefs.getBool('audio_muted') ?? false;
    _initPlayers();
  }

  String? _pendingBgmKey;

  bool get isMuted => _isMuted;

  Future<void> _initPlayers() async {
    try {
      await SoLoud.instance.init();
      
      _backgroundSource = await SoLoud.instance.loadAsset(_backgroundMusic);
      _elevatorSource = await SoLoud.instance.loadAsset(_elevatorMusic);
      _questionSuspenseSource = await SoLoud.instance.loadAsset(_questionSuspenseMusic);
      _questionRevealSource = await SoLoud.instance.loadAsset(_questionReveal);
      _tickingClockSource = await SoLoud.instance.loadAsset(_tickingClock);
      _timeUpSource = await SoLoud.instance.loadAsset(_timeUp);
      _chipSelectSource = await SoLoud.instance.loadAsset(_chipSelect);
      _chipDropSource = await SoLoud.instance.loadAsset(_chipDrop);
      _chipLossSource = await SoLoud.instance.loadAsset(_chipLoss);
      _resultRevealSource = await SoLoud.instance.loadAsset(_resultReveal);
      _payoutWinSource = await SoLoud.instance.loadAsset(_payoutWin);
      _epicFanfareSource = await SoLoud.instance.loadAsset(_epicFanfare);

      _applyVolumes();
      
      // Replay any BGM that was requested before init finished
      if (_pendingBgmKey != null) {
        final key = _pendingBgmKey!;
        _pendingBgmKey = null;
        switch (key) {
          case 'main':
            startMainBgm();
            break;
          case 'lobby':
            startLobbyMusic();
            break;
          case 'question':
            startQuestionMusic();
            break;
        }
      }
    } catch (e) {
      debugPrint('SoLoud init failed: $e');
    }
  }

  Future<void> _applyVolumes() async {
    if (!SoLoud.instance.isInitialized) return;
    SoLoud.instance.setGlobalVolume(_isMuted ? 0.0 : 1.0);
  }

  Future<void> _fadeToBgm(AudioSource? source, {double volume = 0.15, String? bgmKey}) async {
    if (_isMuted) return;
    if (!SoLoud.instance.isInitialized || source == null) {
      if (bgmKey != null) _pendingBgmKey = bgmKey;
      return;
    }
    if (_currentBgmSource == source && _bgmHandle != null) return;

    final oldHandle = _bgmHandle;
    if (oldHandle != null) {
      SoLoud.instance.fadeVolume(oldHandle, 0.0, const Duration(seconds: 1));
      Timer(const Duration(seconds: 1), () {
        if (SoLoud.instance.isInitialized) {
          SoLoud.instance.stop(oldHandle);
        }
      });
    }

    _currentBgmSource = source;
    try {
      _bgmHandle = await SoLoud.instance.play(
        source,
        volume: 0.0,
        looping: true,
      );
      SoLoud.instance.fadeVolume(_bgmHandle!, volume, const Duration(seconds: 1));
    } catch (e) {
      debugPrint('Fade to BGM failed: $e');
    }
  }

  Future<void> startLobbyMusic() => _fadeToBgm(_elevatorSource, volume: 0.12, bgmKey: 'lobby');
  Future<void> startQuestionMusic() => _fadeToBgm(_questionSuspenseSource, volume: 0.12, bgmKey: 'question');
  Future<void> startMainBgm() => _fadeToBgm(_backgroundSource, volume: 0.12, bgmKey: 'main');

  Future<void> stopBackgroundMusic() async {
    if (!SoLoud.instance.isInitialized) return;
    final handle = _bgmHandle;
    if (handle != null) {
      SoLoud.instance.fadeVolume(handle, 0.0, const Duration(seconds: 1));
      Timer(const Duration(seconds: 1), () {
        if (SoLoud.instance.isInitialized) {
          SoLoud.instance.stop(handle);
        }
      });
      _bgmHandle = null;
      _currentBgmSource = null;
    }
  }

  Future<void> startTicking() async {
    if (_isMuted || _isTickingPlaying || !SoLoud.instance.isInitialized) return;
    try {
      if (_tickingClockSource != null) {
        _tickingHandle = await SoLoud.instance.play(
          _tickingClockSource!,
          volume: 0.15,
          looping: true,
        );
        _isTickingPlaying = true;
      }
    } catch (error) {
      debugPrint('Audio ticking failed: $error');
    }
  }

  Future<void> stopTicking() async {
    if (!SoLoud.instance.isInitialized) return;
    _isTickingPlaying = false;
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
      await stopAllLoops();
    } else {
      await startLobbyMusic();
    }
  }

  Future<void> _playSfx(AudioSource? source, {double volume = 0.48}) async {
    if (_isMuted || source == null || !SoLoud.instance.isInitialized) return;
    try {
      await SoLoud.instance.play(source, volume: volume);
    } catch (error) {
      debugPrint('Audio sfx failed: $error');
    }
  }

  Future<void> playClick() => _playSfx(_chipSelectSource, volume: 0.9);
  Future<void> playChip() => _playSfx(_chipSelectSource, volume: 0.78);
  Future<void> playDrop() => _playSfx(_chipDropSource, volume: 0.85);
  Future<void> playClink() => _playSfx(_chipDropSource, volume: 0.85);
  Future<void> playChipLoss() => _playSfx(_chipLossSource, volume: 0.65);
  Future<void> playQuestionReveal() => _playSfx(_questionRevealSource, volume: 0.8);
  Future<void> playTimeUp() => _playSfx(_timeUpSource, volume: 0.7);
  Future<void> playSuccess() => _playSfx(_epicFanfareSource, volume: 0.85);
  Future<void> playResultReveal() => _playSfx(_resultRevealSource, volume: 0.85);
  
  Future<void> playEpicFanfare() => _playSfx(_epicFanfareSource, volume: 0.9);

  Future<void> playPayout() async {
    if (_isMuted || !SoLoud.instance.isInitialized || _payoutWinSource == null) return;
    try {
      _payoutStopTimer?.cancel();
      if (_payoutHandle != null) {
        await SoLoud.instance.stop(_payoutHandle!);
      }
      _payoutHandle = await SoLoud.instance.play(_payoutWinSource!, volume: 0.8);
      _payoutStopTimer = Timer(const Duration(seconds: 4), stopPayout);
    } catch (error) {
      debugPrint('Audio payout failed: $error');
    }
  }

  Future<void> stopPayout() async {
    if (!SoLoud.instance.isInitialized) return;
    _payoutStopTimer?.cancel();
    _payoutStopTimer = null;
    if (_payoutHandle != null) {
      await SoLoud.instance.stop(_payoutHandle!);
      _payoutHandle = null;
    }
  }

  Future<void> playRandomChipSound() async {
    final roll = Random().nextInt(4);
    await _playSfx(_chipSelectSource, volume: roll == 0 ? 0.72 : 0.78);
  }

  void dispose() {
    _payoutStopTimer?.cancel();
    if (SoLoud.instance.isInitialized) {
      SoLoud.instance.deinit();
    }
  }
}
