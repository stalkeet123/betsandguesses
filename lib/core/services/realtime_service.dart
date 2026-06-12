import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Wrapper around Supabase Realtime channels for game communication
class RealtimeService {
  final SupabaseClient _client;
  final Map<String, RealtimeChannel> _channels = {};

  RealtimeService(this._client);

  /// Join a broadcast channel for a room
  RealtimeChannel joinRoom(String roomCode, {
    required void Function(Map<String, dynamic> payload) onPhaseChange,
    required void Function(Map<String, dynamic> payload) onGuessSubmitted,
    required void Function(Map<String, dynamic> payload) onGuessesRevealed,
    required void Function(Map<String, dynamic> payload) onBetPlaced,
    required void Function(Map<String, dynamic> payload) onBetRemoved,
    required void Function(Map<String, dynamic> payload) onScoreUpdate,
    required void Function(Map<String, dynamic> payload) onAnswerRevealed,
    required void Function(Map<String, dynamic> payload) onGameStarted,
    required void Function(Map<String, dynamic> payload) onGameEnded,
  }) {
    final channelName = 'room:$roomCode';

    // Remove existing channel if any
    if (_channels.containsKey(channelName)) {
      _client.removeChannel(_channels[channelName]!);
    }

    final channel = _client.channel(channelName);

    channel
      .onBroadcast(event: 'phase_change', callback: (payload) {
        onPhaseChange(payload);
      })
      .onBroadcast(event: 'guess_submitted', callback: (payload) {
        onGuessSubmitted(payload);
      })
      .onBroadcast(event: 'guesses_revealed', callback: (payload) {
        onGuessesRevealed(payload);
      })
      .onBroadcast(event: 'bet_placed', callback: (payload) {
        onBetPlaced(payload);
      })
      .onBroadcast(event: 'bet_removed', callback: (payload) {
        onBetRemoved(payload);
      })
      .onBroadcast(event: 'score_update', callback: (payload) {
        onScoreUpdate(payload);
      })
      .onBroadcast(event: 'answer_revealed', callback: (payload) {
        onAnswerRevealed(payload);
      })
      .onBroadcast(event: 'game_started', callback: (payload) {
        onGameStarted(payload);
      })
      .onBroadcast(event: 'game_ended', callback: (payload) {
        onGameEnded(payload);
      })
      .subscribe();

    _channels[channelName] = channel;
    return channel;
  }

  /// Broadcast an event to the room
  Future<void> broadcast(String roomCode, String event, Map<String, dynamic> payload) async {
    final channelName = 'room:$roomCode';
    final channel = _channels[channelName];
    if (channel != null) {
      await channel.sendBroadcastMessage(event: event, payload: payload);
    }
  }

  /// Leave a room channel
  void leaveRoom(String roomCode) {
    final channelName = 'room:$roomCode';
    final channel = _channels.remove(channelName);
    if (channel != null) {
      _client.removeChannel(channel);
    }
  }

  /// Dispose all channels
  void dispose() {
    for (final channel in _channels.values) {
      _client.removeChannel(channel);
    }
    _channels.clear();
  }
}
