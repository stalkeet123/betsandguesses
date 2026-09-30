import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:witsgame/features/party/models/party_poll_snapshot.dart';
import 'package:witsgame/features/party/services/party_poll_service.dart';

import '../support/party_poll_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:witsgame/features/party/providers/party_poll_session_provider.dart';

void main() {
  group('selectPartyPollSnapshot', () {
    for (final version in [9, 10, 11]) {
      test(
        'current 10 + incoming $version preserves authoritative ordering',
        () {
          final current = partyPollFixture();
          final incoming = partyPollFixture(
            version: version,
            phase: PartyPollPhase.reveal,
          );
          expect(
            selectPartyPollSnapshot(current, incoming),
            same(version > 10 ? incoming : current),
          );
        },
      );
    }
    test('different room accepts incoming even with a lower version', () {
      final incoming = partyPollFixture(roomId: 'other-room', version: 1);
      expect(
        selectPartyPollSnapshot(partyPollFixture(), incoming),
        same(incoming),
      );
    });
    test('missing current snapshot accepts incoming', () {
      final incoming = partyPollFixture();
      expect(selectPartyPollSnapshot(null, incoming), same(incoming));
    });
  });

  group('asynchronous snapshot ordering', () {
    for (final version in [9, 10]) {
      test(
        'late load at $version cannot replace accepted version 10',
        () async {
          final service = _DelayedService();
          final container = ProviderContainer(
            overrides: [partyPollServiceProvider.overrideWithValue(service)],
          );
          addTearDown(container.dispose);
          final notifier = container.read(partyPollSessionProvider.notifier);
          final request = notifier.load('party-room');
          final accepted = partyPollFixture();
          notifier.setSnapshot(accepted);
          service.response.complete(partyPollFixture(version: version));
          expect(await request, same(accepted));
          expect(
            container.read(partyPollSessionProvider).snapshot,
            same(accepted),
          );
        },
      );

      test(
        'late command at $version returns response but keeps provider version 10',
        () async {
          final service = _DelayedService();
          final container = ProviderContainer(
            overrides: [partyPollServiceProvider.overrideWithValue(service)],
          );
          addTearDown(container.dispose);
          final notifier = container.read(partyPollSessionProvider.notifier);
          final request = notifier.removeBet(
            roomId: 'party-room',
            betId: 'bet',
          );
          final accepted = partyPollFixture();
          notifier.setSnapshot(accepted);
          final response = partyPollFixture(version: version);
          service.response.complete(response);
          expect(await request, same(response));
          expect(
            container.read(partyPollSessionProvider).snapshot,
            same(accepted),
          );
        },
      );
    }
  });

  group('partyPollErrorDetails', () {
    test('retains the max-three-target backend marker as a stable code', () {
      const raw = PostgrestException(
        message: 'POLL_MAX_THREE_TARGETS',
        code: '22023',
        details: 'Forbidden target count',
      );

      final details = partyPollErrorDetails(raw);

      expect(details.errorCode, 'POLL_MAX_THREE_TARGETS');
    });

    test('keeps unknown backend codes without exposing database details', () {
      const raw = PostgrestException(
        message: 'unexpected internal database detail',
        code: 'P0001',
        hint: 'private hint',
      );

      final details = partyPollErrorDetails(raw);

      expect(details.errorCode, 'P0001');
    });

    test('preserves each Party Poll validation marker', () {
      const codes = <String>[
        'POLL_CHIP_ALREADY_USED',
        'INVALID_PARTY_POLL_CHIP',
        'INSUFFICIENT_CHIPS',
        'INVALID_POLL_TARGET',
        'BETTING_WINDOW_CLOSED',
        'BETTING_DEADLINE_MISSING',
        'INVALID_BET_MOVE',
        'INVALID_BET_POSITION',
      ];

      for (final code in codes) {
        final details = partyPollErrorDetails(
          PostgrestException(message: code, code: 'P0001'),
        );
        expect(details.errorCode, code, reason: code);
      }
    });

    test('uses a stable code for client validation and unknown failures', () {
      expect(
        partyPollErrorDetails(ArgumentError.value(1, 'chips')).errorCode,
        'INVALID_PARTY_POLL_CHIP',
      );
      expect(
        partyPollErrorDetails(Exception('network')).errorCode,
        partyPollRequestFailedCode,
      );
    });
  });
}

class _DelayedService extends Fake implements PartyPollService {
  final response = Completer<PartyPollSnapshot>();
  @override
  Future<PartyPollSnapshot> getSnapshot(String roomId) => response.future;
  @override
  Future<PartyPollSnapshot> removeBet({
    required String roomId,
    required String betId,
  }) => response.future;
}
