import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/core/theme/app_colors.dart';
import 'package:witsgame/core/widgets/cached_asset_image.dart';
import 'package:witsgame/features/onboarding/screens/onboarding_screen.dart';

const _slides = <OnboardingSlideData>[
  OnboardingSlideData(
    imageAsset: AppAssetPaths.onboarding1,
    kicker: 'INSTANT JOIN',
    title: 'ONE PHONE.\nWHOLE ROOM.',
    body:
        'Host from your phone. Friends scan the QR code and join from their browser — no app install needed.',
    accent: AppColors.brassLight,
    glowColor: Color(0xFFD7A84A),
  ),
  OnboardingSlideData(
    imageAsset: AppAssetPaths.onboarding2,
    kicker: 'GUESS & BET',
    title: 'GUESS IT.\nTHEN BET IT.',
    body:
        'Make your number guess, then use your chips to bet where you think the real answer lands.',
    accent: AppColors.neonCyan,
    glowColor: Color(0xFF47C7C0),
  ),
  OnboardingSlideData(
    imageAsset: AppAssetPaths.onboarding3,
    kicker: 'READ THE ROOM',
    title: 'BACK YOUR\nBEST READ.',
    body:
        'Every guess changes the table. Trust your instincts, place your chips and build the biggest bankroll.',
    accent: AppColors.chipGold,
    glowColor: Color(0xFFFFC84D),
  ),
  OnboardingSlideData(
    imageAsset: AppAssetPaths.onboarding4,
    kicker: 'TWO WAYS TO PLAY',
    title: 'CLASSIC\nOR PARTY.',
    body:
        'Go Classic for number questions and betting, or Party for prompts where you vote on your friends with chips.',
    accent: AppColors.neonOrange,
    glowColor: Color(0xFFE58B37),
  ),
];

void main() {
  const sizes = <Size>[
    Size(320, 568),
    Size(360, 640),
    Size(375, 667),
    Size(390, 844),
    Size(430, 932),
  ];

  for (final size in sizes) {
    testWidgets('onboarding hero copy fits $size', (tester) async {
      await _pumpSlides(tester, size: size, textScale: 1);
    });
  }

  testWidgets('onboarding hero copy fits 320x568 at 1.2 text scale', (
    tester,
  ) async {
    await _pumpSlides(tester, size: const Size(320, 568), textScale: 1.2);
  });
}

Future<void> _pumpSlides(
  WidgetTester tester, {
  required Size size,
  required double textScale,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  for (final slide in _slides) {
    final veryShort = size.height < 590;
    final short = size.height < 720;

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: OnboardingSlideContent(
                  slide: slide,
                  isActive: true,
                  veryShort: veryShort,
                  short: short,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  }
}
