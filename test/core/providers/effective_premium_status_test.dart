import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/core/models/monetization_status.dart';
import 'package:witsgame/core/providers/core_providers.dart';

MonetizationStatus _status({required bool isPremium}) {
  return MonetizationStatus(
    isPremium: isPremium,
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
  group('resolveEffectivePremiumStatus', () {
    test('server premium is authoritative when RevenueCat is false', () {
      expect(
        resolveEffectivePremiumStatus(
          revenueCatPremium: false,
          serverStatus: _status(isPremium: true),
        ),
        isTrue,
      );
    });

    test('RevenueCat premium is accepted while server sync catches up', () {
      expect(
        resolveEffectivePremiumStatus(
          revenueCatPremium: true,
          serverStatus: _status(isPremium: false),
        ),
        isTrue,
      );
    });

    test('free requires both authorities to be free', () {
      expect(
        resolveEffectivePremiumStatus(
          revenueCatPremium: false,
          serverStatus: _status(isPremium: false),
        ),
        isFalse,
      );
    });
  });

  group('effectivePremiumStatusProvider resilience', () {
    test('RevenueCat failure falls back to server premium', () async {
      final container = _container(
        serverStatus: _status(isPremium: true),
        revenueCatStatus: () async => throw Exception('RevenueCat unavailable'),
      );
      addTearDown(container.dispose);

      expect(
        await container.read(effectivePremiumStatusProvider.future),
        isTrue,
      );
    });

    test('RevenueCat failure falls back to server free', () async {
      final container = _container(
        serverStatus: _status(isPremium: false),
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
