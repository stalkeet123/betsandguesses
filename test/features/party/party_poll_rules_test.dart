import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/features/party/constants/party_poll_rules.dart';

void main() {
  group('PartyPollRules', () {
    test('uses the balanced one-shot chip set', () {
      expect(PartyPollRules.chipValues, const [5, 10, 20]);
      expect(PartyPollRules.roundStakeLimit, 35);
      expect(PartyPollRules.maxDistinctTargets, 3);
    });

    test('accepts only current party poll chips', () {
      expect(PartyPollRules.isValidChip(5), isTrue);
      expect(PartyPollRules.isValidChip(10), isTrue);
      expect(PartyPollRules.isValidChip(20), isTrue);
      expect(PartyPollRules.isValidChip(25), isFalse);
    });
  });
}
