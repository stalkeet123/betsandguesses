import 'package:flutter_riverpod/flutter_riverpod.dart';
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

ProviderContainer _container({
  required MonetizationStatus serverStatus,
  required Future<bool> Function() revenueCatStatus,
}) {
  return ProviderContainer(
    overrides: [
      monetizationStatusProvider.overrideWith((ref) async => serverStatus),
      premiumStatusProvider.overrideWith((ref) => revenueCatStatus()),
    ],
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
        ),
        isTrue,
      );
    });
  });

  group('effectivePremiumStatusProvider resilience', () {
    test('forced premium short-circuits before RevenueCat', () async {
      var revenueCatReads = 0;
      final container = _container(
        serverStatus: _status(
          isPremium: true,
          realIsPremium: false,
          debugPremiumOverride: true,
        ),
        revenueCatStatus: () async {
          revenueCatReads++;
          throw Exception('RevenueCat unavailable');
        },
      );
      addTearDown(container.dispose);

      expect(
        await container.read(effectivePremiumStatusProvider.future),
        isTrue,
      );
      expect(revenueCatReads, 0);
    });

    test('RevenueCat failure falls back to REAL server premium', () async {
      final container = _container(
        serverStatus: _status(
          isPremium: true,
          realIsPremium: true,
          debugOverrideAllowed: false,
        ),
        revenueCatStatus: () async => throw Exception('RevenueCat unavailable'),
      );
      addTearDown(container.dispose);

      expect(
        await container.read(effectivePremiumStatusProvider.future),
        isTrue,
      );
    });

    test('RevenueCat failure falls back to REAL server free', () async {
      final container = _container(
        serverStatus: _status(
          isPremium: false,
          realIsPremium: false,
          debugOverrideAllowed: false,
        ),
        revenueCatStatus: () async => throw Exception('RevenueCat unavailable'),
      );
      addTearDown(container.dispose);

      expect(
        await container.read(effectivePremiumStatusProvider.future),
        isFalse,
      );
    });
  });
}
