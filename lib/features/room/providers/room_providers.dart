import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/room_model.dart';
import '../../../core/providers/core_providers.dart';

// ── Current Room ──
final currentRoomProvider = NotifierProvider<CurrentRoomNotifier, Room?>(() {
  return CurrentRoomNotifier();
});

class CurrentRoomNotifier extends Notifier<Room?> {
  @override
  Room? build() => null;

  void set(Room? room) {
    state = room;
  }
}

// ── Room Code (for lobby navigation) ──
final roomCodeProvider = NotifierProvider<RoomCodeNotifier, String>(() {
  return RoomCodeNotifier();
});

class RoomCodeNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String code) {
    state = code;
  }
}

// ── Players Stream ──
final playersStreamProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, roomId) {
      final playerService = ref.watch(playerServiceProvider);
      return playerService.streamPlayers(roomId);
    });

final roomStreamProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, roomId) {
      final roomService = ref.watch(roomServiceProvider);
      return roomService.streamRoom(roomId);
    });

// ── Skip Auto-Join Flag ──
final skipAutoJoinProvider = NotifierProvider<SkipAutoJoinNotifier, bool>(() {
  return SkipAutoJoinNotifier();
});

class SkipAutoJoinNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool val) {
    state = val;
  }
}
