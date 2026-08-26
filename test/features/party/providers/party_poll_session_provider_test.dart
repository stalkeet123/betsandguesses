import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:witsgame/features/party/providers/party_poll_session_provider.dart';

void main() {
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
