import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../models/party_snapshot.dart';
import '../services/party_game_service.dart';

class PartySessionState {
  final PartySnapshot? snapshot;
  final bool isLoading;
  final bool isCommandRunning;
  final String? errorMessage;

  const PartySessionState({
    this.snapshot,
    this.isLoading = false,
    this.isCommandRunning = false,
    this.errorMessage,
  });

  PartySessionState copyWith({
    PartySnapshot? snapshot,
    bool? isLoading,
    bool? isCommandRunning,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PartySessionState(
      snapshot: snapshot ?? this.snapshot,
      isLoading: isLoading ?? this.isLoading,
      isCommandRunning: isCommandRunning ?? this.isCommandRunning,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

final partySessionProvider =
    NotifierProvider<PartySessionNotifier, PartySessionState>(
      PartySessionNotifier.new,
    );

class PartySessionNotifier extends Notifier<PartySessionState> {
  PartyGameService get _service => ref.read(partyGameServiceProvider);

  @override
  PartySessionState build() => const PartySessionState();

  void setSnapshot(PartySnapshot snapshot) {
    final current = state.snapshot;
    if (current != null &&
        current.round.number == snapshot.round.number &&
        current.stateVersion > snapshot.stateVersion) {
      return;
    }
    state = state.copyWith(snapshot: snapshot, clearError: true);
  }

  Future<PartySnapshot?> load(String roomId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final snapshot = await _service.getSnapshot(roomId);
      state = state.copyWith(
        snapshot: snapshot,
        isLoading: false,
        clearError: true,
      );
      return snapshot;
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: '$error');
      return null;
    }
  }

  Future<PartySnapshot?> runCommand(
    Future<PartySnapshot> Function(PartyGameService service) command,
  ) async {
    if (state.isCommandRunning) return state.snapshot;
    state = state.copyWith(isCommandRunning: true, clearError: true);
    try {
      final snapshot = await command(_service);
      state = state.copyWith(
        snapshot: snapshot,
        isCommandRunning: false,
        clearError: true,
      );
      return snapshot;
    } catch (error) {
      state = state.copyWith(isCommandRunning: false, errorMessage: '$error');
      return null;
    }
  }

  void clear() {
    state = const PartySessionState();
  }
}
