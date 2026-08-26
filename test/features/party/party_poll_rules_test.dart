import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/features/party/constants/party_poll_rules.dart';
import 'package:witsgame/features/party/models/party_poll_snapshot.dart';

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

    test('the same one-shot chip cannot be used twice', () {
      expect(
        PartyPollRules.isChipAvailable(chip: 10, usedChips: const [5]),
        isTrue,
      );
      expect(
        PartyPollRules.isChipAvailable(chip: 5, usedChips: const [5]),
        isFalse,
      );
      expect(
        PartyPollRules.isChipAvailable(chip: 25, usedChips: const []),
        isFalse,
      );
    });

    test('allows a third distinct target and rejects a fourth', () {
      expect(
        PartyPollRules.canTargetPlayer(
          occupiedTargetPlayerIds: const ['a', 'b'],
          targetPlayerId: 'c',
        ),
        isTrue,
      );
      expect(
        PartyPollRules.canTargetPlayer(
          occupiedTargetPlayerIds: const ['a', 'b', 'c'],
          targetPlayerId: 'd',
        ),
        isFalse,
      );
    });

    test('move validation uses targets remaining after the moved bet', () {
      expect(
        PartyPollRules.canTargetPlayer(
          occupiedTargetPlayerIds: const ['a', 'b'],
          targetPlayerId: 'c',
        ),
        isTrue,
      );
      expect(
        PartyPollRules.canTargetPlayer(
          occupiedTargetPlayerIds: const ['a', 'b', 'c'],
          targetPlayerId: 'd',
        ),
        isFalse,
      );
      expect(
        PartyPollRules.canTargetPlayer(
          occupiedTargetPlayerIds: const ['a', 'b', 'c'],
          targetPlayerId: 'b',
        ),
        isTrue,
      );
    });

    test('all one-shot chips consume the full authoritative limit', () {
      final stake = PartyPollRules.chipValues.fold<int>(
        0,
        (total, chip) => total + chip,
      );
      expect(stake, PartyPollRules.roundStakeLimit);
      expect(PartyPollRules.availableChipsForStake(stake), 0);

      final me = PartyPollMe.fromJson(const {
        'player_id': 'player-1',
        'score': 0,
        'bet_limit': 35,
        'bet_total': 35,
        'available_chips': 0,
      });
      expect(me.betLimit, PartyPollRules.roundStakeLimit);
      expect(me.betTotal, PartyPollRules.roundStakeLimit);
      expect(me.availableChips, 0);
    });
  });
}
