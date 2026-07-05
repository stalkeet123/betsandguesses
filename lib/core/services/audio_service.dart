import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  final SharedPreferences _prefs;
  bool _isMuted = false;
  bool _isAmbiencePlaying = false;
  bool _isSuspensePlaying = false;

  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _suspensePlayer = AudioPlayer();
  final AudioPlayer _payoutPlayer = AudioPlayer();
  final List<AudioPlayer> _sfxPool = List.generate(6, (_) => AudioPlayer());
  int _sfxIndex = 0;
  Timer? _payoutStopTimer;

  static const _upbeatMusic = 'sound/mixkit-upbeat-jazz-644.mp3';
  static const _suspenseMusic = 'sound/mixkit-suspense-mystery-bass-685.wav';
  static const _buttonClick = 'sound/button.wav';
  static const _chipMove = 'sound/chip1.wav';
  static const _slotPayout = 'sound/mixkit-slot-machine-payout-alarm-1996.wav';
  static const _success =
      'sound/456965__funwithsound__short-success-sound-glockenspiel-treasure-video-game.mp3';

  AudioService(this._prefs) {
    _isMuted = _prefs.getBool('audio_muted') ?? false;
    _initPlayers();
  }

  bool get isMuted => _isMuted;

  Future<void> _initPlayers() async {
    await AudioPlayer.global.setAudioContext(
      AudioContextConfig(
        focus: AudioContextConfigFocus.gain,
        respectSilence: false,
      ).build(),
    );
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _suspensePlayer.setReleaseMode(ReleaseMode.loop);
    await _musicPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    await _suspensePlayer.setPlayerMode(PlayerMode.mediaPlayer);
    await _payoutPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    await _payoutPlayer.setReleaseMode(ReleaseMode.stop);
    for (final player in _sfxPool) {
      await player.setPlayerMode(PlayerMode.mediaPlayer);
      await player.setReleaseMode(ReleaseMode.stop);
    }
    await _applyVolumes();
  }

  Future<void> _applyVolumes() async {
    await _musicPlayer.setVolume(_isMuted ? 0.0 : 0.09);
    await _suspensePlayer.setVolume(_isMuted ? 0.0 : 0.18);
    await _payoutPlayer.setVolume(_isMuted ? 0.0 : 0.72);
    for (final player in _sfxPool) {
      await player.setVolume(_isMuted ? 0.0 : 0.85);
    }
  }

  Future<void> startAmbience() async {
    if (_isMuted || _isAmbiencePlaying) return;
    try {
      await _musicPlayer.play(AssetSource(_upbeatMusic));
      _isAmbiencePlaying = true;
    } catch (error) {
      debugPrint('Audio ambience failed: $error');
    }
  }

  Future<void> stopAmbience() async {
    _isAmbiencePlaying = false;
    await _musicPlayer.stop();
  }

  Future<void> startSuspense() async {
    if (_isMuted || _isSuspensePlaying) return;
    try {
      await startAmbience();
      await _suspensePlayer.play(AssetSource(_suspenseMusic));
      _isSuspensePlaying = true;
    } catch (error) {
      debugPrint('Audio suspense failed: $error');
    }
  }

  Future<void> stopSuspense() async {
    _isSuspensePlaying = false;
    await _suspensePlayer.stop();
  }

  Future<void> stopAllLoops() async {
    _isAmbiencePlaying = false;
    _isSuspensePlaying = false;
    await _musicPlayer.stop();
    await _suspensePlayer.stop();
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

  AudioPlayer _getNextSfxPlayer() {
    final player = _sfxPool[_sfxIndex];
    _sfxIndex = (_sfxIndex + 1) % _sfxPool.length;
    return player;
  }

  Future<void> _playSfx(String asset, {double volume = 0.48}) async {
    if (_isMuted) return;
    try {
      final player = _getNextSfxPlayer();
      await player.setVolume(volume);
      await player.stop();
      await player.play(AssetSource(asset));
    } catch (error) {
      debugPrint('Audio sfx failed for $asset: $error');
    }
  }

  Future<void> playClick() => _playSfx(_buttonClick, volume: 0.9);

  Future<void> playChip() => _playSfx(_chipMove, volume: 0.78);

  Future<void> playDrop() => playChip();

  Future<void> playClink() => playChip();

  Future<void> playSuccess() => _playSfx(_success, volume: 0.86);

  Future<void> playPayout() async {
    if (_isMuted) return;
    try {
      _payoutStopTimer?.cancel();
      await _payoutPlayer.setVolume(0.72);
      await _payoutPlayer.stop();
      await _payoutPlayer.play(AssetSource(_slotPayout));
      _payoutStopTimer = Timer(const Duration(seconds: 5), stopPayout);
    } catch (error) {
      debugPrint('Audio payout failed: $error');
    }
  }

  Future<void> stopPayout() async {
    _payoutStopTimer?.cancel();
    _payoutStopTimer = null;
    await _payoutPlayer.stop();
  }

  Future<void> playRandomChipSound() async {
    final roll = Random().nextInt(4);
    await _playSfx(_chipMove, volume: roll == 0 ? 0.72 : 0.78);
  }

  void dispose() {
    _payoutStopTimer?.cancel();
    _musicPlayer.dispose();
    _suspensePlayer.dispose();
    _payoutPlayer.dispose();
    for (final player in _sfxPool) {
      player.dispose();
    }
  }
}
