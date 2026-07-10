import 'dart:async';
import 'dart:math';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  final SharedPreferences _prefs;
  bool _isMuted = false;
  bool _isAmbiencePlaying = false;
  bool _isSuspensePlaying = false;

  AudioSource? _upbeatSource;
  AudioSource? _suspenseSource;
  AudioSource? _buttonClickSource;
  AudioSource? _chipMoveSource;
  AudioSource? _slotPayoutSource;
  AudioSource? _successSource;

  SoundHandle? _ambienceHandle;
  SoundHandle? _suspenseHandle;
  SoundHandle? _payoutHandle;
  Timer? _payoutStopTimer;

  static const _upbeatMusic = 'assets/sound/mixkit-upbeat-jazz-644.mp3';
  static const _suspenseMusic = 'assets/sound/mixkit-suspense-mystery-bass-685.wav';
  static const _buttonClick = 'assets/sound/button.wav';
  static const _chipMove = 'assets/sound/chip1.wav';
  static const _slotPayout = 'assets/sound/mixkit-slot-machine-payout-alarm-1996.wav';
  static const _success =
      'assets/sound/456965__funwithsound__short-success-sound-glockenspiel-treasure-video-game.mp3';

  AudioService(this._prefs) {
    _isMuted = _prefs.getBool('audio_muted') ?? false;
    _initPlayers();
  }

  bool get isMuted => _isMuted;

  Future<void> _initPlayers() async {
    try {
      await SoLoud.instance.init();
      
      _upbeatSource = await SoLoud.instance.loadAsset(_upbeatMusic);
      _suspenseSource = await SoLoud.instance.loadAsset(_suspenseMusic);
      _buttonClickSource = await SoLoud.instance.loadAsset(_buttonClick);
      _chipMoveSource = await SoLoud.instance.loadAsset(_chipMove);
      _slotPayoutSource = await SoLoud.instance.loadAsset(_slotPayout);
      _successSource = await SoLoud.instance.loadAsset(_success);

      await _applyVolumes();
    } catch (e) {
      debugPrint('SoLoud init failed: $e');
    }
  }

  Future<void> _applyVolumes() async {
    if (!SoLoud.instance.isInitialized) return;
    SoLoud.instance.setGlobalVolume(_isMuted ? 0.0 : 1.0);
  }

  Future<void> startAmbience() async {
    if (_isMuted || _isAmbiencePlaying || !SoLoud.instance.isInitialized) return;
    try {
      if (_upbeatSource != null) {
        _ambienceHandle = await SoLoud.instance.play(
          _upbeatSource!,
          volume: 0.09,
          looping: true,
        );
        _isAmbiencePlaying = true;
      }
    } catch (error) {
      debugPrint('Audio ambience failed: $error');
    }
  }

  Future<void> stopAmbience() async {
    if (!SoLoud.instance.isInitialized) return;
    _isAmbiencePlaying = false;
    if (_ambienceHandle != null) {
      await SoLoud.instance.stop(_ambienceHandle!);
      _ambienceHandle = null;
    }
  }

  Future<void> startSuspense() async {
    if (_isMuted || _isSuspensePlaying || !SoLoud.instance.isInitialized) return;
    try {
      await startAmbience();
      if (_suspenseSource != null) {
        _suspenseHandle = await SoLoud.instance.play(
          _suspenseSource!,
          volume: 0.18,
          looping: true,
        );
        _isSuspensePlaying = true;
      }
    } catch (error) {
      debugPrint('Audio suspense failed: $error');
    }
  }

  Future<void> stopSuspense() async {
    if (!SoLoud.instance.isInitialized) return;
    _isSuspensePlaying = false;
    if (_suspenseHandle != null) {
      await SoLoud.instance.stop(_suspenseHandle!);
      _suspenseHandle = null;
    }
  }

  Future<void> stopAllLoops() async {
    await stopAmbience();
    await stopSuspense();
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
      await startAmbience();
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

  Future<void> playClick() => _playSfx(_buttonClickSource, volume: 0.9);

  Future<void> playChip() => _playSfx(_chipMoveSource, volume: 0.78);

  Future<void> playDrop() => playChip();

  Future<void> playClink() => playChip();

  Future<void> playSuccess() => _playSfx(_successSource, volume: 0.86);

  Future<void> playPayout() async {
    if (_isMuted || !SoLoud.instance.isInitialized || _slotPayoutSource == null) return;
    try {
      _payoutStopTimer?.cancel();
      if (_payoutHandle != null) {
        await SoLoud.instance.stop(_payoutHandle!);
      }
      _payoutHandle = await SoLoud.instance.play(_slotPayoutSource!, volume: 0.72);
      _payoutStopTimer = Timer(const Duration(seconds: 5), stopPayout);
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
    await _playSfx(_chipMoveSource, volume: roll == 0 ? 0.72 : 0.78);
  }

  void dispose() {
    _payoutStopTimer?.cancel();
    if (SoLoud.instance.isInitialized) {
      SoLoud.instance.deinit();
    }
  }
}
