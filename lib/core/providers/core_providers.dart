import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../services/realtime_service.dart';
import '../services/audio_service.dart';
import '../services/revenuecat_service.dart';
import '../services/monetization_service.dart';
import '../models/monetization_status.dart';
import '../../features/room/services/room_service.dart';
import '../../features/player/services/player_service.dart';
import '../../features/game/services/game_service.dart';
import '../../features/party/services/party_game_service.dart';
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

final partyGameServiceProvider = Provider<PartyGameService>((ref) {
  return PartyGameService(ref.watch(supabaseClientProvider));
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

final revenueCatServiceProvider = Provider<RevenueCatService>((ref) {
  return RevenueCatService();
});

final premiumStatusProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(revenueCatServiceProvider);
  final userId = Supabase.instance.client.auth.currentUser?.id;
  await service.initialize(appUserId: userId);
  return service.isPremium();
}, retry: (retryCount, error) => null);

bool resolveEffectivePremiumStatus({
  required bool revenueCatPremium,
  required MonetizationStatus serverStatus,
}) {
  return revenueCatPremium || serverStatus.isPremium;
}

// ── SharedPreferences ──
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in main');
});

// Stable per-install ID used for room membership identity.
final deviceIdProvider = Provider<String>((ref) {
  const key = 'device_id';
  final prefs = ref.watch(sharedPrefsProvider);
  final existing = prefs.getString(key);
  if (existing != null && existing.isNotEmpty) return existing;

  final id = const Uuid().v4();
  prefs.setString(key, id);
  return id;
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
// Onboarding
final onboardingSeenProvider = NotifierProvider<OnboardingSeenNotifier, bool>(
  () {
    return OnboardingSeenNotifier();
  },
);

class OnboardingSeenNotifier extends Notifier<bool> {
  static const _key = 'onboarding_seen_v1';

  @override
  bool build() {
    final prefs = ref.watch(sharedPrefsProvider);
    return prefs.getBool(_key) ?? false;
  }

  Future<void> markSeen() async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setBool(_key, true);
    state = true;
  }
}

// Current Player (after joining a room)
final currentPlayerProvider = NotifierProvider<CurrentPlayerNotifier, Player?>(
  () {
    return CurrentPlayerNotifier();
  },
);

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

final monetizationServiceProvider = Provider<MonetizationService>(
  (ref) => MonetizationService(ref.watch(supabaseClientProvider)),
);
final monetizationStatusProvider = FutureProvider<MonetizationStatus>(
  (ref) => ref.watch(monetizationServiceProvider).getStatus(),
);

final effectivePremiumStatusProvider = FutureProvider<bool>((ref) async {
  final serverStatus = await ref.watch(monetizationStatusProvider.future);

  try {
    final revenueCatPremium = await ref.watch(premiumStatusProvider.future);
    return resolveEffectivePremiumStatus(
      revenueCatPremium: revenueCatPremium,
      serverStatus: serverStatus,
    );
  } catch (error, stackTrace) {
    debugPrint(
      'RevenueCat premium status unavailable; '
      'using server monetization status: '
      '$error\n$stackTrace',
    );
    return serverStatus.isPremium;
  }
});
