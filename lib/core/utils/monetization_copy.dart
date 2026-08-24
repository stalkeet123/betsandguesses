String setupFreeHostingStatusText({
  required bool isPremium,
  required int freeHostGamesRemaining,
}) {
  if (isPremium) return 'PREMIUM • UNLIMITED HOSTING';

  return switch (freeHostGamesRemaining) {
    3 => '3 FREE HOSTED GAMES INCLUDED',
    2 => '2 FREE HOSTED GAMES LEFT',
    1 => 'LAST FREE HOSTED GAME',
    _ => 'FREE HOSTING USED • PREMIUM NEEDED FOR ANOTHER GAME',
  };
}

String paywallCurrentPlanText({
  required bool isPremium,
  int? freeHostGamesRemaining,
}) {
  if (isPremium) return 'PREMIUM ACTIVE';
  if (freeHostGamesRemaining == null) return 'CURRENT PLAN: FREE';

  return switch (freeHostGamesRemaining) {
    3 => 'FREE • 3 HOSTED GAMES INCLUDED',
    2 => 'FREE • 2 HOSTED GAMES LEFT',
    1 => 'FREE • LAST HOSTED GAME',
    _ => 'FREE HOSTING USED',
  };
}
