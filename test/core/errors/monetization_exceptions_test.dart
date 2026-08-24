import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/core/errors/monetization_exceptions.dart';

void main() {
  test('recognizes only the exact free-host quota message', () {
    expect(isFreeHostLimitReachedMessage('FREE_HOST_LIMIT_REACHED'), isTrue);
    expect(isFreeHostLimitReachedMessage('P0001'), isFalse);
    expect(
      isFreeHostLimitReachedMessage('FREE_HOST_LIMIT_REACHED now'),
      isFalse,
    );
  });

  test('maps only exact premium setup requirement messages', () {
    expect(
      premiumSetupRequirementForMessage('PREMIUM_PLAYERS_REQUIRED'),
      PremiumSetupRequirement.players,
    );
    expect(
      premiumSetupRequirementForMessage('PREMIUM_ROUNDS_REQUIRED'),
      PremiumSetupRequirement.rounds,
    );
    expect(
      premiumSetupRequirementForMessage('PREMIUM_CATEGORY_REQUIRED'),
      PremiumSetupRequirement.category,
    );
    expect(premiumSetupRequirementForMessage('P0001'), isNull);
    expect(
      premiumSetupRequirementForMessage('PREMIUM_PLAYERS_REQUIRED extra'),
      isNull,
    );
    expect(
      premiumSetupRequirementForMessage('some PREMIUM_PLAYERS_REQUIRED'),
      isNull,
    );
  });
}
