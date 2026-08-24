import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_asset_image.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _pageController;
  int _pageIndex = 0;

  static const _heroCacheWidth = 960;

  static const _slides = <OnboardingSlideData>[
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

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioServiceProvider).startMainBgm();
      ref.read(gameServiceProvider).prefetchQuestions();
      unawaited(_precacheNextSlide(0));
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _precacheNextSlide(int currentIndex) async {
    final nextIndex = currentIndex + 1;
    if (nextIndex >= _slides.length || !mounted) return;

    try {
      await precacheImage(
        ResizeImage(
          AssetImage(_slides[nextIndex].imageAsset),
          width: _heroCacheWidth,
        ),
        context,
      );
    } catch (_) {
      // The hero still loads normally when an optional pre-cache misses.
    }
  }

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    ref.read(audioServiceProvider).playClick();
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    if (!mounted) return;
    context.goNamed('home');
  }

  void _next() {
    HapticFeedback.lightImpact();
    ref.read(audioServiceProvider).playClick();
    if (_pageIndex == _slides.length - 1) {
      unawaited(_finish());
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: RepaintBoundary(
              child: CachedAssetImage(
                AppAssetPaths.background,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.25,
                  colors: [
                    const Color(0xFF1B4E38).withValues(alpha: 0.25),
                    const Color(0xFF0A2218).withValues(alpha: 0.58),
                    Colors.black.withValues(alpha: 0.84),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth.clamp(0.0, 540.0);
                final veryShort = constraints.maxHeight < 590;
                final short = constraints.maxHeight < 720;
                final horizontalPadding = constraints.maxWidth <= 340
                    ? 14.0
                    : constraints.maxWidth < 390
                    ? 18.0
                    : 24.0;
                final verticalPadding = veryShort ? 8.0 : 14.0;

                return Center(
                  child: SizedBox(
                    width: maxWidth,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        verticalPadding,
                        horizontalPadding,
                        veryShort ? 10 : 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTopHeader(compact: veryShort),
                          SizedBox(height: veryShort ? 6 : 12),
                          Expanded(
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: _slides.length,
                              onPageChanged: (index) {
                                HapticFeedback.selectionClick();
                                setState(() => _pageIndex = index);
                                unawaited(_precacheNextSlide(index));
                              },
                              itemBuilder: (context, index) {
                                return OnboardingSlideContent(
                                  slide: _slides[index],
                                  isActive: index == _pageIndex,
                                  veryShort: veryShort,
                                  short: short,
                                  heroCacheWidth: _heroCacheWidth,
                                );
                              },
                            ),
                          ),
                          SizedBox(height: veryShort ? 6 : 10),
                          _buildProgressIndicator(),
                          SizedBox(height: veryShort ? 8 : 12),
                          _buildBottomAction(
                            isLast: _pageIndex == _slides.length - 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader({required bool compact}) {
    return SizedBox(
      height: compact ? 40 : 44,
      child: Row(
        children: [
          Flexible(
            child: Container(
              height: compact ? 32 : 36,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.26),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.brassLight.withValues(alpha: 0.24),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.brassLight,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Flexible(
                    child: Text(
                      'BETS & GUESSES',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'RehnCondensed',
                        color: AppColors.ivory,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: compact ? 40 : 44,
            child: TextButton(
              onPressed: _finish,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brassLight,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                minimumSize: const Size(62, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: AppColors.brassLight.withValues(alpha: 0.22),
                  ),
                ),
                backgroundColor: Colors.black.withValues(alpha: 0.22),
              ),
              child: const Text(
                'SKIP',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return SizedBox(
      height: 28,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < _slides.length; index++)
            Semantics(
              button: true,
              label: 'Go to onboarding page ${index + 1}',
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  HapticFeedback.selectionClick();
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                  );
                },
                child: SizedBox(
                  width: index == _pageIndex ? 42 : 24,
                  height: 28,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      height: 7,
                      width: index == _pageIndex ? 30 : 7,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: index == _pageIndex
                            ? AppColors.goldGradient
                            : null,
                        color: index == _pageIndex
                            ? null
                            : AppColors.ivory.withValues(alpha: 0.24),
                        boxShadow: index == _pageIndex
                            ? [
                                BoxShadow(
                                  color: AppColors.brass.withValues(
                                    alpha: 0.34,
                                  ),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomAction({required bool isLast}) {
    return Semantics(
      button: true,
      label: isLast ? 'Let us play' : 'Continue',
      child: SizedBox(
        height: 54,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: AppColors.goldGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.brass.withValues(alpha: 0.34),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.36),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _next,
              child: Center(
                child: Text(
                  isLast ? "LET'S PLAY" : 'CONTINUE',
                  style: const TextStyle(
                    fontFamily: 'RehnCondensed',
                    color: AppColors.ink,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@immutable
class OnboardingSlideData {
  final String imageAsset;
  final String kicker;
  final String title;
  final String body;
  final Color accent;
  final Color glowColor;

  const OnboardingSlideData({
    required this.imageAsset,
    required this.kicker,
    required this.title,
    required this.body,
    required this.accent,
    required this.glowColor,
  });
}

@visibleForTesting
class OnboardingSlideContent extends StatelessWidget {
  final OnboardingSlideData slide;
  final bool isActive;
  final bool veryShort;
  final bool short;
  final int heroCacheWidth;

  const OnboardingSlideContent({
    super.key,
    required this.slide,
    required this.isActive,
    required this.veryShort,
    required this.short,
    this.heroCacheWidth = 960,
  });

  @override
  Widget build(BuildContext context) {
    final titleSize = veryShort
        ? 36.0
        : short
        ? 40.0
        : 46.0;
    final bodySize = veryShort
        ? 11.0
        : short
        ? 12.0
        : 13.0;
    final titleGap = veryShort ? 5.0 : 8.0;
    final bodyGap = veryShort ? 5.0 : 8.0;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: RepaintBoundary(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                opacity: isActive ? 1 : 0.88,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  scale: isActive ? 1 : 0.985,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: veryShort ? 10 : 18,
                      vertical: veryShort ? 2 : 8,
                    ),
                    child: CachedAssetImage(
                      slide.imageAsset,
                      fit: BoxFit.contain,
                      cacheWidth: heroCacheWidth,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Text(
          slide.kicker,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: slide.accent,
            fontSize: veryShort ? 10 : 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            height: 1,
          ),
        ),
        SizedBox(height: titleGap),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            slide.title,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'RehnCondensed',
              color: AppColors.ivory,
              fontSize: titleSize,
              fontWeight: FontWeight.w900,
              height: 0.94,
              letterSpacing: 0.8,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.78),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
                Shadow(
                  color: slide.glowColor.withValues(alpha: 0.26),
                  blurRadius: 14,
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: bodyGap),
        Text(
          slide.body,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: bodySize,
            fontWeight: FontWeight.w600,
            height: 1.32,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}
