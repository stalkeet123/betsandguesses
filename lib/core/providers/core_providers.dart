import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/realtime_service.dart';
import '../services/audio_service.dart';
import '../../features/room/services/room_service.dart';
import '../../features/player/services/player_service.dart';
import '../../features/game/services/game_service.dart';
import '../../features/player/models/player_model.dart';

// ── Supabase Client ──
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// ── Services ──
final roomServiceProvider = Provider<RoomService>((ref) {
  return RoomService(ref.watch(supabaseClientProvider));
});

final playerServiceProvider = Provider<PlayerService>((ref) {
  return PlayerService(ref.watch(supabaseClientProvider));
});

final gameServiceProvider = Provider<GameService>((ref) {
  return GameService(ref.watch(supabaseClientProvider));
});

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final service = RealtimeService(ref.watch(supabaseClientProvider));
  ref.onDispose(() => service.dispose());
  return service;
});

final audioServiceProvider = Provider<AudioService>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  final service = AudioService(prefs);
  ref.onDispose(() => service.dispose());
  return service;
});

// ── SharedPreferences ──
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in main');
});

// ── Player Name (persisted) ──
final playerNameProvider = NotifierProvider<PlayerNameNotifier, String>(() {
  return PlayerNameNotifier();
});

class PlayerNameNotifier extends Notifier<String> {
  @override
  String build() {
    final prefs = ref.watch(sharedPrefsProvider);
    return prefs.getString('player_name') ?? '';
  }

  void setName(String name) {
    final prefs = ref.read(sharedPrefsProvider);
    prefs.setString('player_name', name);
    state = name;
  }
}

// ── Current Player (after joining a room) ──
final currentPlayerProvider = NotifierProvider<CurrentPlayerNotifier, Player?>(() {
  return CurrentPlayerNotifier();
});

class CurrentPlayerNotifier extends Notifier<Player?> {
  @override
  Player? build() => null;

  void set(Player? player) {
    state = player;
  }
}

// ── Is Host ──
final isHostProvider = Provider<bool>((ref) {
  final player = ref.watch(currentPlayerProvider);
  return player?.isHost ?? false;
});
