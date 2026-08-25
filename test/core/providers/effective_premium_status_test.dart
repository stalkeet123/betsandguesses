import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/core/models/monetization_status.dart';
import 'package:witsgame/core/providers/core_providers.dart';

MonetizationStatus _status({
  required bool isPremium,
  bool? realIsPremium,
  bool debugOverrideAllowed = true,
  bool? debugPremiumOverride,
}) {
  return MonetizationStatus(
    isPremium: isPremium,
    realIsPremium: realIsPremium,
    debugOverrideAllowed: debugOverrideAllowed,
    debugPremiumOverride: debugPremiumOverride,
    isLifetime: false,
    premiumExpiresAt: null,
    freeHostGamesUsed: 0,
    freeHostGamesRemaining: 3,
  );
}

void main() {
  group('MonetizationStatus debug fields', () {
    test('parses an allowed premium override', () {
      final status = MonetizationStatus.fromJson({
        'is_premium': true,
        'real_is_premium': false,
        'debug_override_allowed': true,
        'debug_premium_override': true,
      });

      expect(status.realIsPremium, isFalse);
      expect(status.debugOverrideAllowed, isTrue);
      expect(status.debugPremiumOverride, isTrue);
    });

    test('preserves false instead of treating it as null', () {
      final status = MonetizationStatus.fromJson({
        'is_premium': false,
        'real_is_premium': true,
        'debug_override_allowed': true,
        'debug_premium_override': false,
      });

      expect(status.debugPremiumOverride, isFalse);
    });

    test('uses null when the override field is missing', () {
      final status = MonetizationStatus.fromJson({'is_premium': false});

      expect(status.debugPremiumOverride, isNull);
    });

    test('keeps older responses backwards safe', () {
      final premium = MonetizationStatus.fromJson({'is_premium': true});
      final free = MonetizationStatus.fromJson({'is_premium': false});

      expect(premium.realIsPremium, isTrue);
      expect(free.realIsPremium, isFalse);
      expect(premium.debugOverrideAllowed, isFalse);
      expect(premium.debugPremiumOverride, isNull);
    });
  });

  group('resolveEffectivePremiumStatus', () {
    test('forced premium uses the effective server value', () {
      expect(
        resolveEffectivePremiumStatus(
          revenueCatPremium: false,
          serverStatus: _status(
            isPremium: true,
            realIsPremium: false,
            debugPremiumOverride: true,
          ),
          debugMode: true,
        ),
        isTrue,
      );
    });

    test('forced free cannot be defeated by RevenueCat premium', () {
      expect(
        resolveEffectivePremiumStatus(
          revenueCatPremium: true,
          serverStatus: _status(
            isPremium: false,
            realIsPremium: true,
            debugPremiumOverride: false,
          ),
          debugMode: true,
        ),
        isFalse,
      );
    });

    test('real mode falls back to normal entitlement behavior', () {
      expect(
        resolveEffectivePremiumStatus(
          revenueCatPremium: true,
          serverStatus: _status(
            isPremium: false,
            realIsPremium: false,
            debugPremiumOverride: null,
          ),
          debugMode: true,
        ),
        isTrue,
      );
    });
  });
}
