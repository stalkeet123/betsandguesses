import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:witsgame/core/models/monetization_status.dart';
import 'package:witsgame/core/providers/core_providers.dart';
import 'package:witsgame/features/paywall/screens/paywall_screen.dart';

void main() {
  const sizes = <Size>[
    Size(320, 568),
    Size(360, 640),
    Size(375, 667),
    Size(390, 844),
    Size(430, 932),
  ];

  for (final size in sizes) {
    testWidgets('paywall fits $size', (tester) async {
      await _pumpPaywall(tester, size: size, textScale: 1);
    });
  }

  testWidgets('paywall fits 320x568 at 1.2 text scale', (tester) async {
    await _pumpPaywall(tester, size: const Size(320, 568), textScale: 1.2);
  });

  testWidgets('purchase cards keep content-driven visual mass', (tester) async {
    await _pumpPaywall(tester, size: const Size(390, 844), textScale: 1);

    final partyPass = tester.getSize(
      find.byKey(const ValueKey('paywall-party-pass')),
    );
    final fullAccessFinder = find.byKey(const ValueKey('paywall-full-access'));
    final fullAccess = tester.getSize(fullAccessFinder);
    final fullAccessRect = tester.getRect(fullAccessFinder);
    final restorePurchases = tester.getRect(find.text('RESTORE PURCHASES'));

    expect(partyPass.width, closeTo(fullAccess.width, 0.1));
    expect(partyPass.height, lessThan(280));
    expect(fullAccess.height, inInclusiveRange(120, 155));
    expect(restorePurchases.top - fullAccessRect.bottom, lessThan(130));
  });
}

Future<void> _pumpPaywall(
  WidgetTester tester, {
  required Size size,
  required double textScale,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        monetizationStatusProvider.overrideWith(
          (ref) async => const MonetizationStatus(
            isPremium: false,
            isLifetime: false,
            premiumExpiresAt: null,
            freeHostGamesUsed: 0,
            freeHostGamesRemaining: 3,
          ),
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: const MaterialApp(home: PaywallScreen(enableStartupWork: false)),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));

  expect(tester.takeException(), isNull);
  expect(find.text('KEEP THE PARTY GOING'), findsOneWidget);
  expect(find.text('RESTORE PURCHASES'), findsOneWidget);
}
