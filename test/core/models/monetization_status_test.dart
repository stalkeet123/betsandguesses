import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/core/models/monetization_status.dart';
import 'package:witsgame/core/utils/monetization_copy.dart';

void main() {
  test('parses free quota counts', () {
    final fresh = MonetizationStatus.fromJson({
      'is_premium': false,
      'is_lifetime': false,
      'premium_expires_at': null,
      'free_host_games_used': 0,
      'free_host_games_remaining': 3,
    });
    final exhausted = MonetizationStatus.fromJson({
      'is_premium': false,
      'is_lifetime': false,
      'premium_expires_at': null,
      'free_host_games_used': 3,
      'free_host_games_remaining': 0,
    });

    expect(fresh.freeHostGamesUsed, 0);
    expect(fresh.freeHostGamesRemaining, 3);
    expect(exhausted.freeHostGamesUsed, 3);
    expect(exhausted.freeHostGamesRemaining, 0);
  });

  test('formats hosted-game status without inventing credits', () {
    expect(
      setupFreeHostingStatusText(isPremium: true, freeHostGamesRemaining: 0),
      'PREMIUM • UNLIMITED HOSTING',
    );
    expect(
      setupFreeHostingStatusText(isPremium: false, freeHostGamesRemaining: 3),
      '3 FREE HOSTED GAMES INCLUDED',
    );
    expect(
      setupFreeHostingStatusText(isPremium: false, freeHostGamesRemaining: 2),
      '2 FREE HOSTED GAMES LEFT',
    );
    expect(
      setupFreeHostingStatusText(isPremium: false, freeHostGamesRemaining: 1),
      'LAST FREE HOSTED GAME',
    );
    expect(
      setupFreeHostingStatusText(isPremium: false, freeHostGamesRemaining: 0),
      'FREE HOSTING USED • PREMIUM NEEDED FOR ANOTHER GAME',
    );
  });

  test('formats the paywall plan strip safely when status is unavailable', () {
    expect(
      paywallCurrentPlanText(isPremium: false, freeHostGamesRemaining: null),
      'CURRENT PLAN: FREE',
    );
    expect(
      paywallCurrentPlanText(isPremium: false, freeHostGamesRemaining: 1),
      'FREE • LAST HOSTED GAME',
    );
    expect(
      paywallCurrentPlanText(isPremium: false, freeHostGamesRemaining: 0),
      'FREE TRIAL USED',
    );
  });
  test('parses lifetime and expiry entitlement fields safely', () {
    final lifetime = MonetizationStatus.fromJson({
      'is_premium': true,
      'is_lifetime': true,
      'premium_expires_at': null,
      'free_host_games_used': 0,
      'free_host_games_remaining': 3,
    });
    final expiring = MonetizationStatus.fromJson({
      'is_premium': true,
      'is_lifetime': false,
      'premium_expires_at': '2026-08-24T12:00:00Z',
      'free_host_games_used': 0,
      'free_host_games_remaining': 3,
    });
    final malformed = MonetizationStatus.fromJson({
      'is_premium': false,
      'is_lifetime': false,
      'premium_expires_at': 'not-a-date',
      'free_host_games_used': 0,
      'free_host_games_remaining': 3,
    });

    expect(lifetime.isLifetime, isTrue);
    expect(lifetime.premiumExpiresAt, isNull);
    expect(expiring.premiumExpiresAt, DateTime.utc(2026, 8, 24, 12));
    expect(expiring.premiumExpiresAt?.isUtc, isTrue);
    expect(malformed.premiumExpiresAt, isNull);
  });
}
