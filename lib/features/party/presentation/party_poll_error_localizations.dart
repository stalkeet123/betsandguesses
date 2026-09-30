import '../../../l10n/app_localizations.dart';

String partyPollErrorMessageForCode(AppLocalizations l10n, String? errorCode) {
  return switch (errorCode) {
    'POLL_MAX_THREE_TARGETS' => l10n.targetLimit,
    'POLL_CHIP_ALREADY_USED' => l10n.chipAlreadyUsed,
    'INVALID_PARTY_POLL_CHIP' => l10n.chooseAvailableChip,
    'INSUFFICIENT_CHIPS' => l10n.insufficientChips,
    'INVALID_POLL_TARGET' => l10n.invalidPollTarget,
    'BETTING_WINDOW_CLOSED' ||
    'BETTING_DEADLINE_MISSING' => l10n.bettingClosedRound,
    'INVALID_BET_MOVE' || 'INVALID_BET_POSITION' => l10n.betNoLongerMoved,
    'FREE_HOST_LIMIT_REACHED' => l10n.freeHostingUsed,
    _ => l10n.partyPollRequestFailed,
  };
}
