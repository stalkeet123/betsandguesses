import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/monetization_exceptions.dart';
import '../../../core/providers/core_providers.dart';
import '../models/party_poll_snapshot.dart';
import '../services/party_poll_service.dart';

class PartyPollErrorDetails {
  final String message;
  final String? backendCode;

  const PartyPollErrorDetails({required this.message, this.backendCode});
}

final _partyPollBackendMarker = RegExp(r'\b[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+\b');

PartyPollErrorDetails partyPollErrorDetails(Object error) {
  if (error is PostgrestException) {
    final marker = _partyPollBackendMarker.firstMatch(error.message)?.group(0);
    final message = switch (marker) {
      'POLL_MAX_THREE_TARGETS' => 'You can bet on up to 3 players per round.',
      'POLL_CHIP_ALREADY_USED' => 'That chip is already used this round.',
      'INVALID_PARTY_POLL_CHIP' => 'Choose an available 5, 10, or 20 chip.',
      'INSUFFICIENT_CHIPS' => 'You do not have enough chips left this round.',
      'INVALID_POLL_TARGET' => 'That player is not available for betting.',
      'BETTING_WINDOW_CLOSED' ||
      'BETTING_DEADLINE_MISSING' => 'Betting has closed for this round.',
      'INVALID_BET_MOVE' ||
      'INVALID_BET_POSITION' => 'That bet can no longer be moved.',
      _ => 'Party Poll request failed. Please try again.',
    };
    return PartyPollErrorDetails(
      message: message,
      backendCode: marker ?? error.code,
    );
  }
  if (error is ArgumentError && error.name == 'chips') {
    return const PartyPollErrorDetails(
      message: 'Choose an available 5, 10, or 20 chip.',
      backendCode: 'INVALID_PARTY_POLL_CHIP',
    );
  }
  return const PartyPollErrorDetails(
    message: 'Party Poll request failed. Please try again.',
  );
}

PartyPollSnapshot selectPartyPollSnapshot(
  PartyPollSnapshot? current,
  PartyPollSnapshot incoming,
) {
  if (current == null || current.room.id != incoming.room.id) return incoming;
  return incoming.stateVersion >= current.stateVersion ? incoming : current;
}

class PartyPollSessionState {
  final PartyPollSnapshot? snapshot;
  final bool isLoading;
  final bool isCommandRunning;
  final String? errorMessage;
  final String? errorCode;

  const PartyPollSessionState({
    this.snapshot,
    this.isLoading = false,
    this.isCommandRunning = false,
    this.errorMessage,
    this.errorCode,
  });

  PartyPollSessionState copyWith({
    PartyPollSnapshot? snapshot,
    bool clearSnapshot = false,
    bool? isLoading,
    bool? isCommandRunning,
    String? errorMessage,
    String? errorCode,
    bool clearError = false,
  }) {
    return PartyPollSessionState(
      snapshot: clearSnapshot ? null : snapshot ?? this.snapshot,
      isLoading: isLoading ?? this.isLoading,
      isCommandRunning: isCommandRunning ?? this.isCommandRunning,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      errorCode: clearError ? null : errorCode ?? this.errorCode,
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
  PartyPollSnapshot _acceptedSnapshot(PartyPollSnapshot incoming) =>
      selectPartyPollSnapshot(state.snapshot, incoming);

  void _setError(Object error, {bool? isLoading, bool? isCommandRunning}) {
    final details = partyPollErrorDetails(error);
    state = state.copyWith(
      isLoading: isLoading,
      isCommandRunning: isCommandRunning,
      errorMessage: details.message,
      errorCode: details.backendCode,
    );
  }

  @override
  PartyPollSessionState build() => const PartyPollSessionState();

  void setSnapshot(PartyPollSnapshot snapshot) {
    state = state.copyWith(
      snapshot: _acceptedSnapshot(snapshot),
      clearError: true,
    );
  }

  Future<PartyPollSnapshot?> load(String roomId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final incoming = await _service.getSnapshot(roomId);
      final accepted = _acceptedSnapshot(incoming);
      state = state.copyWith(
        snapshot: accepted,
        isLoading: false,
        clearError: true,
      );
      return accepted;
    } catch (error) {
      _setError(error, isLoading: false);
      return null;
    }
  }

  Future<PartyPollSnapshot?> startGame(
    String roomId, {
    int bettingDurationSeconds = 30,
  }) async {
    if (state.isCommandRunning) return state.snapshot;
    state = state.copyWith(isCommandRunning: true, clearError: true);
    try {
      final snapshot = await _service.startGame(
        roomId: roomId,
        bettingDurationSeconds: bettingDurationSeconds,
      );
      final accepted = _acceptedSnapshot(snapshot);
      state = state.copyWith(
        snapshot: accepted,
        isCommandRunning: false,
        clearError: true,
      );
      return accepted;
    } on FreeHostLimitReachedException {
      state = state.copyWith(
        isCommandRunning: false,
        errorMessage: freeHostLimitReachedMessage,
      );
      rethrow;
    } catch (error) {
      _setError(error, isCommandRunning: false);
      return null;
    }
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
      state = state.copyWith(
        snapshot: _acceptedSnapshot(placement.snapshot),
        clearError: true,
      );
      return placement;
    } catch (error) {
      _setError(error);
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
      state = state.copyWith(
        snapshot: _acceptedSnapshot(snapshot),
        clearError: true,
      );
      return snapshot;
    } catch (error) {
      _setError(error);
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
          snapshot: _acceptedSnapshot(snapshot),
          isCommandRunning: false,
          clearError: true,
        );
      } else {
        state = state.copyWith(isCommandRunning: false, clearError: true);
      }
      return response;
    } catch (error) {
      _setError(error, isCommandRunning: false);
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
        snapshot: _acceptedSnapshot(snapshot),
        isCommandRunning: false,
        clearError: true,
      );
      return snapshot;
    } catch (error) {
      _setError(error, isCommandRunning: false);
      return null;
    }
  }

  void clear() {
    state = const PartyPollSessionState();
  }
}
