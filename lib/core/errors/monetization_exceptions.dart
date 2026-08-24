const freeHostLimitReachedMessage = 'FREE_HOST_LIMIT_REACHED';

bool isFreeHostLimitReachedMessage(String message) =>
    message == freeHostLimitReachedMessage;

class FreeHostLimitReachedException implements Exception {
  const FreeHostLimitReachedException();
}

const premiumPlayersRequiredMessage = 'PREMIUM_PLAYERS_REQUIRED';
const premiumRoundsRequiredMessage = 'PREMIUM_ROUNDS_REQUIRED';
const premiumCategoryRequiredMessage = 'PREMIUM_CATEGORY_REQUIRED';

enum PremiumSetupRequirement { players, rounds, category }

PremiumSetupRequirement? premiumSetupRequirementForMessage(String message) {
  switch (message) {
    case premiumPlayersRequiredMessage:
      return PremiumSetupRequirement.players;
    case premiumRoundsRequiredMessage:
      return PremiumSetupRequirement.rounds;
    case premiumCategoryRequiredMessage:
      return PremiumSetupRequirement.category;
    default:
      return null;
  }
}

class PremiumSetupRequiredException implements Exception {
  final PremiumSetupRequirement requirement;

  const PremiumSetupRequiredException(this.requirement);
}
