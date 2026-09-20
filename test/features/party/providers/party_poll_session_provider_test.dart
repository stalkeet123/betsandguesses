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
    test('presents max-three-target failures without raw Postgrest text', () {
      const raw = PostgrestException(
        message: 'POLL_MAX_THREE_TARGETS',
        code: '22023',
        details: 'Forbidden target count',
      );

      final details = partyPollErrorDetails(raw);

      expect(details.message, 'You can bet on up to 3 players per round.');
      expect(details.message, isNot(contains('PostgrestException')));
      expect(details.message, isNot(contains('POLL_MAX_THREE_TARGETS')));
      expect(details.backendCode, 'POLL_MAX_THREE_TARGETS');
    });

    test('keeps backend code while hiding unknown database details', () {
      const raw = PostgrestException(
        message: 'unexpected internal database detail',
        code: 'P0001',
        hint: 'private hint',
      );

      final details = partyPollErrorDetails(raw);

      expect(details.message, 'Party Poll request failed. Please try again.');
      expect(details.message, isNot(contains(raw.message)));
      expect(details.message, isNot(contains('private hint')));
      expect(details.backendCode, 'P0001');
    });

    test('maps common bet validation markers to safe messages', () {
      const cases = <String, String>{
        'POLL_CHIP_ALREADY_USED': 'That chip is already used this round.',
        'INVALID_PARTY_POLL_CHIP': 'Choose an available 5, 10, or 20 chip.',
        'INSUFFICIENT_CHIPS': 'You do not have enough chips left this round.',
        'INVALID_POLL_TARGET': 'That player is not available for betting.',
        'BETTING_WINDOW_CLOSED': 'Betting has closed for this round.',
      };

      for (final entry in cases.entries) {
        final details = partyPollErrorDetails(
          PostgrestException(message: entry.key, code: 'P0001'),
        );
        expect(details.message, entry.value, reason: entry.key);
        expect(details.backendCode, entry.key, reason: entry.key);
      }
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
