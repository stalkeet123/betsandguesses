import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../models/party_moment.dart';
import '../models/party_snapshot.dart';
import '../services/party_game_service.dart';

class PartySessionState {
  final PartySnapshot? snapshot;
  final List<PartyMoment> moments;
  final bool isLoading;
  final bool isCommandRunning;
  final String? errorMessage;

  const PartySessionState({
    this.snapshot,
    this.moments = const [],
    this.isLoading = false,
    this.isCommandRunning = false,
    this.errorMessage,
  });

  PartySessionState copyWith({
    PartySnapshot? snapshot,
    List<PartyMoment>? moments,
    bool? isLoading,
    bool? isCommandRunning,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PartySessionState(
      snapshot: snapshot ?? this.snapshot,
      moments: moments ?? this.moments,
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

  Future<PartySnapshot?> load(String roomId, {bool loadMoments = false}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final snapshot = await _service.getSnapshot(roomId);
      var moments = state.moments;
      if (loadMoments) {
        moments = await _service.getMoments(roomId);
      }
      state = state.copyWith(
        snapshot: snapshot,
        moments: moments,
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

  Future<void> refreshMoments(String roomId) async {
    try {
      final moments = await _service.getMoments(roomId);
      state = state.copyWith(moments: moments, clearError: true);
    } catch (error) {
      state = state.copyWith(errorMessage: '$error');
    }
  }

  Future<PartyMoment?> uploadMoment({
    required String roomId,
    required int roundNumber,
    required String playerId,
    required Uint8List bytes,
  }) async {
    if (state.isCommandRunning) return null;
    state = state.copyWith(isCommandRunning: true, clearError: true);
    try {
      final moment = await _service.uploadMoment(
        roomId: roomId,
        roundNumber: roundNumber,
        playerId: playerId,
        bytes: bytes,
      );
      state = state.copyWith(
        moments: [...state.moments, moment]
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
        isCommandRunning: false,
        clearError: true,
      );
      return moment;
    } catch (error) {
      state = state.copyWith(isCommandRunning: false, errorMessage: '$error');
      return null;
    }
  }

  Future<bool> deleteMoment(PartyMoment moment) async {
    if (state.isCommandRunning) return false;
    state = state.copyWith(isCommandRunning: true, clearError: true);
    try {
      await _service.deleteMoment(moment);
      state = state.copyWith(
        moments: state.moments
            .where((candidate) => candidate.id != moment.id)
            .toList(growable: false),
        isCommandRunning: false,
        clearError: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(isCommandRunning: false, errorMessage: '$error');
      return false;
    }
  }

  void clear() {
    state = const PartySessionState();
  }
}
