class MonetizationStatus {
  final bool isPremium, isLifetime;
  final DateTime? premiumExpiresAt;
  final int freeHostGamesUsed, freeHostGamesRemaining;
  const MonetizationStatus({
    required this.isPremium,
    required this.isLifetime,
    required this.premiumExpiresAt,
    required this.freeHostGamesUsed,
    required this.freeHostGamesRemaining,
  });
  factory MonetizationStatus.fromJson(Map<String, dynamic> j) =>
      MonetizationStatus(
        isPremium: j['is_premium'] == true,
        isLifetime: j['is_lifetime'] == true,
        premiumExpiresAt: DateTime.tryParse(
          '${j['premium_expires_at'] ?? ''}',
        )?.toUtc(),
        freeHostGamesUsed: (j['free_host_games_used'] as num?)?.toInt() ?? 0,
        freeHostGamesRemaining:
            (j['free_host_games_remaining'] as num?)?.toInt() ?? 0,
      );
}
