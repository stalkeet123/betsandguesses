import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/party_moment.dart';

/// Device-only, session-scoped Party media.
///
/// Nothing in this provider is uploaded or synchronized. Keeping the bytes in
/// memory also makes captures immediately available to the recap without file
/// or network work on the performance screen.
final partyLocalMediaProvider =
    NotifierProvider<PartyLocalMediaNotifier, List<PartyMoment>>(
      PartyLocalMediaNotifier.new,
    );

class PartyLocalMediaNotifier extends Notifier<List<PartyMoment>> {
  @override
  List<PartyMoment> build() => const [];

  PartyMoment add({
    required String roomId,
    required int roundNumber,
    required String playerId,
    required String playerName,
    required String? playerColor,
    required Uint8List bytes,
  }) {
    final moment = PartyMoment(
      id: const Uuid().v4(),
      roomId: roomId,
      roundNumber: roundNumber,
      uploaderPlayerId: playerId,
      uploaderName: playerName,
      uploaderColor: playerColor,
      bytes: bytes,
      createdAt: DateTime.now().toUtc(),
    );
    state = [...state, moment];
    return moment;
  }

  void delete(String id) {
    state = state.where((moment) => moment.id != id).toList(growable: false);
  }

  void clearRoom(String roomId) {
    state = state
        .where((moment) => moment.roomId != roomId)
        .toList(growable: false);
  }
}
