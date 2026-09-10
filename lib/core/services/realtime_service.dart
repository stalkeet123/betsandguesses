import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'game_trace_service.dart';

typedef BetRowChangeCallback =
    void Function(Map<String, dynamic> record, bool isDelete);
typedef RoomRowChangeCallback = void Function(Map<String, dynamic> record);

/// Wrapper around Supabase Realtime channels for game communication
class RealtimeService {
  final SupabaseClient _client;
  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, Future<void>> _channelOperations = {};

  RealtimeService(this._client);

  /// Join a broadcast channel for a room
  Future<void> joinRoom(
    String roomCode, {
    String? roomId,
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
    BetRowChangeCallback? onBetRowChanged,
    RoomRowChangeCallback? onRoomRowChanged,
    void Function(RealtimeSubscribeStatus)? onConnectionChanged,
  }) {
    final channelName = 'room:$roomCode';
    GameTraceService.instance.trace('realtime_join_requested', {
      'source': 'broadcast',
      'has_room_row_subscription': roomId != null && onRoomRowChanged != null,
    });

    return _enqueueChannelOperation(channelName, () async {
      final existingChannel = _channels.remove(channelName);
      if (existingChannel != null) {
        await _client.removeChannel(existingChannel);
      }

      final accessToken = _client.auth.currentSession?.accessToken;
      if (accessToken == null) {
        throw StateError('Realtime requires an authenticated session.');
      }
      await _client.realtime.setAuth(accessToken);
      final channel = _client.channel(
        channelName,
        opts: const RealtimeChannelConfig(private: true),
      );

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
          .onBroadcast(
            event: 'phase_change',
            callback: (payload) {
              GameTraceService.instance.trace('phase_change', {
                'source': 'broadcast',
                if (payload['round'] is num)
                  'round': (payload['round'] as num).toInt(),
                if (payload['phase'] != null) 'phase': '${payload['phase']}',
                if (payload['state_version'] is num)
                  'state_version': (payload['state_version'] as num).toInt(),
                if (payload['phase_ends_at'] != null)
                  'deadline_utc': '${payload['phase_ends_at']}',
              });
              onPhaseChange(payload);
            },
          )
          .onBroadcast(event: 'guess_submitted', callback: onGuessSubmitted)
          .onBroadcast(event: 'guesses_revealed', callback: onGuessesRevealed)
          .onBroadcast(event: 'bet_placed', callback: onBetPlaced)
          .onBroadcast(event: 'bet_removed', callback: onBetRemoved)
          .onBroadcast(event: 'score_update', callback: onScoreUpdate)
          .onBroadcast(
            event: 'answer_revealed',
            callback: (payload) {
              GameTraceService.instance.trace('answer_revealed', {
                'source': 'broadcast',
              });
              onAnswerRevealed(payload);
            },
          )
          .onBroadcast(
            event: 'game_started',
            callback: (payload) {
              GameTraceService.instance.trace('game_started', {
                'source': 'broadcast',
              });
              onGameStarted(payload);
            },
          )
          .onBroadcast(event: 'game_ended', callback: onGameEnded)
          .onBroadcast(
            event: 'player_joined',
            callback: (payload) => onPlayerJoined?.call(payload),
          )
          .onBroadcast(
            event: 'player_left',
            callback: (payload) => onPlayerLeft?.call(payload),
          );

      if (roomId != null && onBetRowChanged != null) {
        channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) {
            final isDelete = payload.eventType == PostgresChangeEvent.delete;
            final record = isDelete ? payload.oldRecord : payload.newRecord;
            if (record.isNotEmpty) onBetRowChanged(record, isDelete);
          },
        );
      }

      if (roomId != null && onRoomRowChanged != null) {
        channel.onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'rooms',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: roomId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              final record = payload.newRecord;
              GameTraceService.instance.trace('room_row_received', {
                'source': 'postgres',
                if (record['current_round'] is num)
                  'round': (record['current_round'] as num).toInt(),
                if (record['round_phase'] != null)
                  'phase': '${record['round_phase']}',
                if (record['state_version'] is num)
                  'state_version': (record['state_version'] as num).toInt(),
                if (record['phase_ends_at'] != null)
                  'deadline_utc': '${record['phase_ends_at']}',
              });
              onRoomRowChanged(record);
            }
          },
        );
      }

      final subscriptionReady = Completer<void>();
      channel.subscribe((status, error) async {
        if (subscriptionReady.isCompleted &&
            !identical(_channels[channelName], channel)) {
          return;
        }
        onConnectionChanged?.call(status);
        if (status == RealtimeSubscribeStatus.subscribed) {
          GameTraceService.instance.trace('realtime_subscribed', {
            'source': 'broadcast',
          });
          if (!subscriptionReady.isCompleted) subscriptionReady.complete();
          if (presencePayload != null) {
            try {
              await channel.track(presencePayload);
              onPresenceChanged?.call(currentPresenceDeviceIds());
            } catch (_) {
              // Presence is optional; broadcast and database sync stay active.
            }
          }
          return;
        }

        if (!subscriptionReady.isCompleted &&
            (status == RealtimeSubscribeStatus.channelError ||
                status == RealtimeSubscribeStatus.closed ||
                status == RealtimeSubscribeStatus.timedOut)) {
          GameTraceService.instance.trace('realtime_join_failed', {
            'source': 'broadcast',
            'status': status.name,
          });
          subscriptionReady.completeError(
            StateError('Realtime subscription failed: $status ($error)'),
          );
        }
      });

      try {
        await subscriptionReady.future.timeout(const Duration(seconds: 10));
      } catch (_) {
        await _client.removeChannel(channel);
        rethrow;
      }

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
    final pendingOperation = _channelOperations[channelName];
    if (pendingOperation != null) {
      try {
        await pendingOperation.timeout(const Duration(milliseconds: 750));
      } on TimeoutException {
        // Database mutations and local game flow must not wait for transport.
        return;
      }
    }
    final channel = _channels[channelName];
    if (channel != null) {
      final mutablePayload = Map<String, dynamic>.of(payload);
      try {
        await channel.sendBroadcastMessage(
          event: event,
          payload: mutablePayload,
        );
      } catch (error) {
        // Broadcast is a hint. A committed database mutation remains successful
        // and subscribers recover from the server snapshot after reconnect.
        GameTraceService.instance.trace('broadcast_send_failed', {
          'event_name': event,
          'error_type': error.runtimeType.toString(),
        });
      }
    }
  }

  /// Leave a room channel
  Future<void> leaveRoom(String roomCode) {
    final channelName = 'room:$roomCode';
    GameTraceService.instance.trace('realtime_leave', {'source': 'broadcast'});
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
