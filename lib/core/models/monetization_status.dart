class MonetizationStatus {
  final bool isPremium, isLifetime;
  final bool realIsPremium;
  final bool debugOverrideAllowed;
  final bool? debugPremiumOverride;
  final DateTime? premiumExpiresAt;
  final int freeHostGamesUsed, freeHostGamesRemaining;

  const MonetizationStatus({
    required this.isPremium,
    bool? realIsPremium,
    this.debugOverrideAllowed = false,
    this.debugPremiumOverride,
    required this.isLifetime,
    required this.premiumExpiresAt,
    required this.freeHostGamesUsed,
    required this.freeHostGamesRemaining,
  }) : realIsPremium = realIsPremium ?? isPremium;

  factory MonetizationStatus.fromJson(Map<String, dynamic> j) =>
      MonetizationStatus(
        isPremium: j['is_premium'] == true,
        realIsPremium: j.containsKey('real_is_premium')
            ? j['real_is_premium'] == true
            : j['is_premium'] == true,
        debugOverrideAllowed: j['debug_override_allowed'] == true,
        debugPremiumOverride: j['debug_premium_override'] is bool
            ? j['debug_premium_override'] as bool
            : null,
        isLifetime: j['is_lifetime'] == true,
        premiumExpiresAt: DateTime.tryParse(
          '${j['premium_expires_at'] ?? ''}',
        )?.toUtc(),
        freeHostGamesUsed: (j['free_host_games_used'] as num?)?.toInt() ?? 0,
        freeHostGamesRemaining:
            (j['free_host_games_remaining'] as num?)?.toInt() ?? 0,
      );
}
