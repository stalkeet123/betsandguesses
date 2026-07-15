import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Wrapper around Supabase Realtime channels for game communication
class RealtimeService {
  final SupabaseClient _client;
  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, Future<void>> _channelOperations = {};

  RealtimeService(this._client);

  /// Join a broadcast channel for a room
  Future<void> joinRoom(
    String roomCode, {
    required void Function(Map<String, dynamic> payload) onPhaseChange,
    required void Function(Map<String, dynamic> payload) onGuessSubmitted,
    required void Function(Map<String, dynamic> payload) onGuessesRevealed,
    required void Function(Map<String, dynamic> payload) onBetPlaced,
    required void Function(Map<String, dynamic> payload) onBetRemoved,
    required void Function(Map<String, dynamic> payload) onScoreUpdate,
    required void Function(Map<String, dynamic> payload) onAnswerRevealed,
    required void Function(Map<String, dynamic> payload) onGameStarted,
    required void Function(Map<String, dynamic> payload) onGameEnded,
    void Function(Map<String, dynamic> payload)? onPlayerJoined,
    void Function(Map<String, dynamic> payload)? onPlayerLeft,
    Map<String, dynamic>? presencePayload,
    void Function(Set<String> deviceIds)? onPresenceChanged,
  }) {
    final channelName = 'room:$roomCode';

    return _enqueueChannelOperation(channelName, () async {
      final existingChannel = _channels.remove(channelName);
      if (existingChannel != null) {
        await _client.removeChannel(existingChannel);
      }

      final channel = _client.channel(channelName);

      Set<String> currentPresenceDeviceIds() {
        final ids = <String>{};
        for (final state in channel.presenceState()) {
          for (final presence in state.presences) {
            final deviceId = presence.payload['device_id'] as String?;
            if (deviceId != null && deviceId.isNotEmpty) ids.add(deviceId);
          }
        }
        return ids;
      }

      channel
          .onPresenceSync((_) {
            onPresenceChanged?.call(currentPresenceDeviceIds());
          })
          .onBroadcast(event: 'phase_change', callback: onPhaseChange)
          .onBroadcast(event: 'guess_submitted', callback: onGuessSubmitted)
          .onBroadcast(event: 'guesses_revealed', callback: onGuessesRevealed)
          .onBroadcast(event: 'bet_placed', callback: onBetPlaced)
          .onBroadcast(event: 'bet_removed', callback: onBetRemoved)
          .onBroadcast(event: 'score_update', callback: onScoreUpdate)
          .onBroadcast(event: 'answer_revealed', callback: onAnswerRevealed)
          .onBroadcast(event: 'game_started', callback: onGameStarted)
          .onBroadcast(event: 'game_ended', callback: onGameEnded)
          .onBroadcast(
            event: 'player_joined',
            callback: (payload) => onPlayerJoined?.call(payload),
          )
          .onBroadcast(
            event: 'player_left',
            callback: (payload) => onPlayerLeft?.call(payload),
          )
          .subscribe((status, error) async {
            if (status == RealtimeSubscribeStatus.subscribed &&
                presencePayload != null) {
              await channel.track(presencePayload);
              onPresenceChanged?.call(currentPresenceDeviceIds());
            }
          });

      _channels[channelName] = channel;
    });
  }

  /// Broadcast an event to the room
  Future<void> broadcast(
    String roomCode,
    String event,
    Map<String, dynamic> payload,
  ) async {
    final channelName = 'room:$roomCode';
    await _channelOperations[channelName];
    final channel = _channels[channelName];
    if (channel != null) {
      await channel.sendBroadcastMessage(event: event, payload: payload);
    }
  }

  /// Leave a room channel
  Future<void> leaveRoom(String roomCode) {
    final channelName = 'room:$roomCode';
    return _enqueueChannelOperation(channelName, () async {
      final channel = _channels.remove(channelName);
      if (channel != null) await _client.removeChannel(channel);
    });
  }

  /// Dispose all channels
  void dispose() {
    for (final channel in _channels.values) {
      unawaited(_client.removeChannel(channel));
    }
    _channels.clear();
  }

  Future<void> _enqueueChannelOperation(
    String channelName,
    Future<void> Function() operation,
  ) {
    final previous = _channelOperations[channelName] ?? Future<void>.value();
    final completer = Completer<void>();

    late final Future<void> queued;
    queued = previous.then((_) async {
      try {
        await operation();
        completer.complete();
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    _channelOperations[channelName] = queued;
    unawaited(
      queued.whenComplete(() {
        if (identical(_channelOperations[channelName], queued)) {
          _channelOperations.remove(channelName);
        }
      }),
    );
    return completer.future;
  }
}
