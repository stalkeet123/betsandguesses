import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../models/party_poll_snapshot.dart';
import '../services/party_poll_service.dart';

class PartyPollSessionState {
  final PartyPollSnapshot? snapshot;
  final bool isLoading;
  final bool isCommandRunning;
  final String? errorMessage;

  const PartyPollSessionState({
    this.snapshot,
    this.isLoading = false,
    this.isCommandRunning = false,
    this.errorMessage,
  });

  PartyPollSessionState copyWith({
    PartyPollSnapshot? snapshot,
    bool clearSnapshot = false,
    bool? isLoading,
    bool? isCommandRunning,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PartyPollSessionState(
      snapshot: clearSnapshot ? null : snapshot ?? this.snapshot,
      isLoading: isLoading ?? this.isLoading,
      isCommandRunning: isCommandRunning ?? this.isCommandRunning,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

final partyPollServiceProvider = Provider<PartyPollService>((ref) {
  return PartyPollService(ref.read(supabaseClientProvider));
});

final partyPollSessionProvider =
    NotifierProvider<PartyPollSessionNotifier, PartyPollSessionState>(
      PartyPollSessionNotifier.new,
    );

class PartyPollSessionNotifier extends Notifier<PartyPollSessionState> {
  int _pendingBetCommands = 0;
  PartyPollService get _service => ref.read(partyPollServiceProvider);

  @override
  PartyPollSessionState build() => const PartyPollSessionState();

  void setSnapshot(PartyPollSnapshot snapshot) {
    state = state.copyWith(snapshot: snapshot, clearError: true);
  }

  Future<PartyPollSnapshot?> load(String roomId) async {
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

  Future<PartyPollSnapshot?> startGame(
    String roomId, {
    int bettingDurationSeconds = 30,
  }) {
    return _run(
      () => _service.startGame(
        roomId: roomId,
        bettingDurationSeconds: bettingDurationSeconds,
      ),
    );
  }

  Future<PartyPollBetPlacement?> placeBet({
    required String roomId,
    required String targetPlayerId,
    required int chips,
    required String clientActionId,
    double? positionX,
    double? positionY,
  }) async {
    // Independent actions may be in flight together. The server still
    // serializes and validates each clientActionId authoritatively.
    _pendingBetCommands++;
    state = state.copyWith(isCommandRunning: true, clearError: true);
    try {
      final placement = await _service.placeBet(
        roomId: roomId,
        targetPlayerId: targetPlayerId,
        chips: chips,
        clientActionId: clientActionId,
        positionX: positionX,
        positionY: positionY,
      );
      final current = state.snapshot;
      final snapshot =
          current != null &&
              current.stateVersion > placement.snapshot.stateVersion
          ? current
          : placement.snapshot;
      state = state.copyWith(snapshot: snapshot, clearError: true);
      return placement;
    } catch (error) {
      state = state.copyWith(errorMessage: '$error');
      return null;
    } finally {
      _pendingBetCommands--;
      state = state.copyWith(isCommandRunning: _pendingBetCommands > 0);
    }
  }

  Future<PartyPollSnapshot?> moveBet({
    required String roomId,
    required String betId,
    required String targetPlayerId,
    double? positionX,
    double? positionY,
  }) => _runBetCommand(
    () => _service.moveBet(
      roomId: roomId,
      betId: betId,
      targetPlayerId: targetPlayerId,
      positionX: positionX,
      positionY: positionY,
    ),
  );

  Future<PartyPollSnapshot?> removeBet({
    required String roomId,
    required String betId,
  }) => _runBetCommand(() => _service.removeBet(roomId: roomId, betId: betId));

  Future<PartyPollSnapshot?> _runBetCommand(
    Future<PartyPollSnapshot> Function() command,
  ) async {
    _pendingBetCommands++;
    state = state.copyWith(isCommandRunning: true, clearError: true);
    try {
      final snapshot = await command();
      final current = state.snapshot;
      state = state.copyWith(
        snapshot:
            current != null && current.stateVersion > snapshot.stateVersion
            ? current
            : snapshot,
        clearError: true,
      );
      return snapshot;
    } catch (error) {
      state = state.copyWith(errorMessage: '$error');
      return null;
    } finally {
      _pendingBetCommands--;
      state = state.copyWith(isCommandRunning: _pendingBetCommands > 0);
    }
  }

  Future<PartyPollSnapshot?> settleRound(String roomId) =>
      _run(() => _service.settleRound(roomId));

  Future<Map<String, dynamic>?> advanceRound(
    String roomId, {
    int bettingDurationSeconds = 30,
  }) async {
    if (state.isCommandRunning) return null;
    state = state.copyWith(isCommandRunning: true, clearError: true);
    try {
      final response = await _service.advanceRound(
        roomId,
        bettingDurationSeconds: bettingDurationSeconds,
      );
      final isSnapshot =
          response['room'] is Map &&
          response['round'] is Map &&
          response['me'] is Map &&
          response['state_version'] != null;
      if (isSnapshot) {
        final snapshot = PartyPollSnapshot.fromJson(response);
        state = state.copyWith(
          snapshot: snapshot,
          isCommandRunning: false,
          clearError: true,
        );
      } else {
        state = state.copyWith(isCommandRunning: false, clearError: true);
      }
      return response;
    } catch (error) {
      state = state.copyWith(isCommandRunning: false, errorMessage: '$error');
      return null;
    }
  }

  Future<PartyPollSnapshot?> _run(
    Future<PartyPollSnapshot> Function() command,
  ) async {
    if (state.isCommandRunning) return state.snapshot;
    state = state.copyWith(isCommandRunning: true, clearError: true);
    try {
      final snapshot = await command();
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
    state = const PartyPollSessionState();
  }
}
