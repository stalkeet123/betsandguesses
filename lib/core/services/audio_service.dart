import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  final SharedPreferences _prefs;
  bool _isMuted = false;

  // Players
  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _crowdPlayer = AudioPlayer();

  // Round-robin SFX player pool to allow overlapping sounds
  final List<AudioPlayer> _sfxPool = List.generate(4, (_) => AudioPlayer());
  int _sfxIndex = 0;

  // Sound URLs (Soundjay & Soundhelix are extremely reliable public mp3 sources)
  static const String _musicUrl =
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3';
  static const String _crowdUrl =
      'https://www.soundjay.com/misc/sounds/bar-chatter-1.mp3';
  static const String _clickUrl =
      'https://www.soundjay.com/buttons/sounds/button-16.mp3';
  static const String _tokUrl =
      'https://www.soundjay.com/buttons/sounds/button-20.mp3';
  static const String _clinkUrl =
      'https://www.soundjay.com/buttons/sounds/button-29.mp3';

  AudioService(this._prefs) {
    _isMuted = _prefs.getBool('audio_muted') ?? false;
    _initPlayers();
  }

  bool get isMuted => _isMuted;

  void _initPlayers() {
    _musicPlayer.setReleaseMode(ReleaseMode.loop);
    _crowdPlayer.setReleaseMode(ReleaseMode.loop);

    // Set volumes
    _musicPlayer.setVolume(_isMuted ? 0.0 : 0.08); // low-volume lounge music
    _crowdPlayer.setVolume(_isMuted ? 0.0 : 0.05); // low-volume crowd murmur
    for (final p in _sfxPool) {
      p.setVolume(_isMuted ? 0.0 : 0.4);
    }
  }

  /// Start ambient background noise and lounge music
  Future<void> startAmbience() async {
    if (_isMuted) return;
    try {
      await _musicPlayer.play(UrlSource(_musicUrl));
      await _crowdPlayer.play(UrlSource(_crowdUrl));
    } catch (e) {
      // Ignore audio loading errors gracefully (e.g. offline)
    }
  }

  /// Stop background music and murmur
  Future<void> stopAmbience() async {
    await _musicPlayer.stop();
    await _crowdPlayer.stop();
  }

  /// Toggle mute state and save to preferences
  void toggleMute() {
    _isMuted = !_isMuted;
    _prefs.setBool('audio_muted', _isMuted);

    _musicPlayer.setVolume(_isMuted ? 0.0 : 0.08);
    _crowdPlayer.setVolume(_isMuted ? 0.0 : 0.05);
    for (final p in _sfxPool) {
      p.setVolume(_isMuted ? 0.0 : 0.4);
    }

    if (!_isMuted) {
      startAmbience();
    } else {
      stopAmbience();
    }
  }

  AudioPlayer _getNextSfxPlayer() {
    final player = _sfxPool[_sfxIndex];
    _sfxIndex = (_sfxIndex + 1) % _sfxPool.length;
    return player;
  }

  /// Play chip select click
  Future<void> playClick() async {
    if (_isMuted) return;
    try {
      await _getNextSfxPlayer().play(UrlSource(_clickUrl));
    } catch (_) {}
  }

  /// Play chip drop (tok)
  Future<void> playDrop() async {
    if (_isMuted) return;
    try {
      await _getNextSfxPlayer().play(UrlSource(_tokUrl));
    } catch (_) {}
  }

  /// Play chip collision clink
  Future<void> playClink() async {
    if (_isMuted) return;
    try {
      await _getNextSfxPlayer().play(UrlSource(_clinkUrl));
    } catch (_) {}
  }

  /// Play randomized chip sound to make physical interaction feel rich
  Future<void> playRandomChipSound() async {
    final rand = Random().nextInt(3);
    if (rand == 0) {
      await playClick();
    } else if (rand == 1) {
      await playDrop();
    } else {
      await playClink();
    }
  }

  void dispose() {
    _musicPlayer.dispose();
    _crowdPlayer.dispose();
    for (final p in _sfxPool) {
      p.dispose();
    }
  }
}
