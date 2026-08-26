class PartyPollRules {
  PartyPollRules._();

  static const chipValues = <int>[5, 10, 20];
  static const roundStakeLimit = 35;
  static const maxDistinctTargets = 3;

  static bool isValidChip(int chips) => chipValues.contains(chips);

  static bool isChipAvailable({
    required int chip,
    required Iterable<int> usedChips,
  }) => isValidChip(chip) && !usedChips.contains(chip);

  static bool canTargetPlayer({
    required Iterable<String> occupiedTargetPlayerIds,
    required String targetPlayerId,
  }) {
    final targets = occupiedTargetPlayerIds
        .where((id) => id.isNotEmpty)
        .toSet();
    return targets.contains(targetPlayerId) ||
        targets.length < maxDistinctTargets;
  }

  static int availableChipsForStake(int stake) =>
      (roundStakeLimit - stake).clamp(0, roundStakeLimit).toInt();
}
