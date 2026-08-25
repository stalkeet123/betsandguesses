class PartyPollRules {
  PartyPollRules._();

  static const chipValues = <int>[5, 10, 20];
  static const roundStakeLimit = 35;
  static const maxDistinctTargets = 3;

  static bool isValidChip(int chips) => chipValues.contains(chips);
}
