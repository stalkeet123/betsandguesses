import '../../l10n/app_localizations.dart';

String setupFreeHostingStatusText(
  AppLocalizations l10n, {
  required bool isPremium,
  required int freeHostGamesRemaining,
}) {
  if (isPremium) return l10n.premiumUnlimitedHosting;
  return switch (freeHostGamesRemaining) {
    3 => l10n.freeHostedGamesIncluded,
    2 => l10n.freeHostedGamesLeft,
    1 => l10n.lastFreeHostedGame,
    _ => l10n.freeHostingUsedPremiumNeeded,
  };
}

String paywallCurrentPlanText(
  AppLocalizations l10n, {
  required bool isPremium,
  int? freeHostGamesRemaining,
}) {
  if (isPremium) return l10n.premiumActive;
  if (freeHostGamesRemaining == null) return l10n.currentPlanFree;
  return switch (freeHostGamesRemaining) {
    3 => l10n.freePlanIncluded,
    2 => l10n.freePlanLeft,
    1 => l10n.freePlanLast,
    _ => l10n.freeHostingUsed,
  };
}
