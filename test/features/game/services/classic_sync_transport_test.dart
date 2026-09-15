import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:witsgame/features/game/services/game_service.dart';
import 'package:witsgame/features/room/services/room_service.dart';

Map<String, dynamic> room({int version = 15}) => {
  'id': 'room-a',
  'code': 'ABCDEF',
  'host_id': 'host',
  'game_mode': 'classic',
  'status': 'playing',
  'current_round': 2,
  'round_phase': 'question',
  'state_version': version,
  'created_at': '2026-09-10T00:00:00Z',
  'phase_ends_at': '2026-09-10T00:00:01Z',
};

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late FutureOr<Object?> Function(HttpRequest) respond;
  late List<Uri> requests;

  setUp(() async {
    requests = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    respond = (_) => null;
    server.listen((request) async {
      requests.add(request.uri);
      await request.drain<void>();
      final value = await respond(request);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(value));
      await request.response.close();
    });
    client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-anon-key');
  });
  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  Object? legacyResponse(HttpRequest request, {int version = 15}) {
    switch (request.uri.path.split('/').last) {
      case 'get_classic_snapshot_v1':
        request.response.statusCode = 404;
        return {'code': 'PGRST202', 'message': 'Function not in schema cache'};
      case 'rooms':
        return room(version: version);
      case 'get_current_question_v2':
        return null;
      default:
        return <Object?>[];
    }
  }

  test('available RPC fetches the complete snapshot in one request', () async {
    respond = (_) => {
      'room': room(),
      'question': null,
      'players': [],
      'guesses': [],
      'bets': [],
    };
    final snapshot = await GameService(client).getClassicSnapshot('room-a');
    expect(snapshot.room.stateVersion, 15);
    expect(requests.map((u) => u.path), [
      '/rest/v1/rpc/get_classic_snapshot_v1',
    ]);
  });

  test('missing RPC uses guarded legacy reads without repeated 404s', () async {
    respond = legacyResponse;
    final service = GameService(client);
    expect((await service.getClassicSnapshot('room-a')).room.stateVersion, 15);
    expect((await service.getClassicSnapshot('room-a')).room.stateVersion, 15);
    expect(
      requests.where((u) => u.path.endsWith('get_classic_snapshot_v1')),
      hasLength(1),
    );
    expect(requests.where((u) => u.path.endsWith('/rooms')), hasLength(4));
    for (final uri in requests.where(
      (u) => u.path.endsWith('/bets') || u.path.endsWith('/guesses'),
    )) {
      expect(uri.queryParameters['round_number'], 'eq.2');
      expect(uri.queryParameters['room_id'], 'eq.room-a');
    }
  });

  test('transition during legacy read discards it and retries fresh', () async {
    var roomReads = 0;
    respond = (request) {
      if (request.uri.path.endsWith('/rooms')) {
        roomReads++;
        return room(version: roomReads == 1 ? 15 : 16);
      }
      return legacyResponse(request);
    };
    final snapshot = await GameService(client).getClassicSnapshot('room-a');
    expect(snapshot.room.stateVersion, 16);
    expect(roomReads, 4);
    expect(requests.where((u) => u.path.endsWith('/bets')), hasLength(2));
  });

  test('continuously changing room fails safely with bounded reads', () async {
    var roomReads = 0;
    respond = (request) => request.uri.path.endsWith('/rooms')
        ? room(version: ++roomReads)
        : legacyResponse(request);
    await expectLater(
      GameService(client).getClassicSnapshot('room-a'),
      throwsStateError,
    );
    expect(roomReads, 4);
  });

  test('auth failure must not silently downgrade to legacy reads', () async {
    respond = (request) {
      request.response.statusCode = 403;
      return {'code': '42501', 'message': 'Room membership required'};
    };
    await expectLater(
      GameService(client).getClassicSnapshot('room-a'),
      throwsA(isA<PostgrestException>()),
    );
    expect(requests, hasLength(1));
  });

  test('malformed RPC payload must not silently downgrade', () async {
    respond = (_) => null;
    await expectLater(
      GameService(client).getClassicSnapshot('room-a'),
      throwsStateError,
    );
    expect(requests, hasLength(1));
  });

  test('next-round RPC carries the prepared question in one request', () async {
    respond = (_) => {
      'room': {...room(), 'current_question_id': 'question-a'},
      'question': {'id': 'question-a', 'text_tr': 'Prepared question'},
    };
    final prepared = await GameService(client).prepareNextClassicRound(
      roomId: 'room-a',
      roundNumber: 1,
      transitionSeconds: 1,
    );
    expect(prepared!.room.currentRound, 2);
    expect(prepared.question.id, prepared.room.currentQuestionId);
    expect(prepared.question.answer, isNull);
    expect(requests.map((u) => u.path), [
      '/rest/v1/rpc/prepare_next_classic_round_v1',
    ]);
  });

  test(
    'lost preparation claim returns null without another picker call',
    () async {
      final prepared = await GameService(client).prepareNextClassicRound(
        roomId: 'room-a',
        roundNumber: 1,
        transitionSeconds: 1,
      );
      expect(prepared, isNull);
      expect(requests, hasLength(1));
    },
  );

  test('preparation rejects a mismatched round or question identity', () async {
    for (final overrides in [
      {'current_round': 4, 'current_question_id': 'question-a'},
      {'current_question_id': 'question-b'},
      {'round_phase': 'guessing', 'current_question_id': 'question-a'},
    ]) {
      respond = (_) => {
        'room': {...room(), ...overrides},
        'question': {'id': 'question-a', 'text_tr': 'Prepared question'},
      };
      await expectLater(
        GameService(client).prepareNextClassicRound(
          roomId: 'room-a',
          roundNumber: 1,
          transitionSeconds: 1,
        ),
        throwsStateError,
      );
    }
  });

  test('clock cold sampling is shared, cached, and can be refreshed', () async {
    respond = (_) async {
      await Future<void>.delayed(const Duration(milliseconds: 2));
      return DateTime.now().toUtc().toIso8601String();
    };
    final service = RoomService(client);
    await Future.wait([
      service.synchronizeServerClock(),
      service.synchronizeServerClock(),
    ]);
    expect(requests, hasLength(3));
    await service.synchronizeServerClock();
    expect(requests, hasLength(3));
    await service.synchronizeServerClock(force: true);
    expect(requests, hasLength(4));
  });

  test('clock keeps a valid sample if a later cold sample fails', () async {
    respond = (request) {
      if (requests.length == 1) return DateTime.now().toUtc().toIso8601String();
      request.response.statusCode = 503;
      return {'message': 'Unavailable'};
    };
    final service = RoomService(client);
    await service.synchronizeServerClock();
    expect(requests, hasLength(2));
    await service.synchronizeServerClock();
    expect(requests, hasLength(2));
  });

  test(
    'failed first clock sample clears single-flight for a later retry',
    () async {
      respond = (request) {
        request.response.statusCode = 503;
        return {'message': 'Unavailable'};
      };
      final service = RoomService(client);
      await expectLater(
        service.synchronizeServerClock(),
        throwsA(isA<PostgrestException>()),
      );
      respond = (_) => DateTime.now().toUtc().toIso8601String();
      await service.synchronizeServerClock();
      expect(requests, hasLength(4));
    },
  );
}
