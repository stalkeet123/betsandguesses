import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

  static final _slides = [
    _OnboardingSlide(
      icon: Icons.qr_code_2_rounded,
      title: 'NO DOWNLOADS\nFOR FRIENDS',
      kicker: 'They scan. They play. You host.',
      body: 'The only party game where only the host needs the app. Pure chaos in seconds.',
      accent: AppColors.neonPurple,
    ),
    _OnboardingSlide(
      icon: Icons.psychology_alt_rounded,
      title: 'GUESS FIRST.\nBET SECOND.',
      kicker: 'Blind answers. Loud confidence.',
      body: 'Everyone locks in a number. Then bet your chips on who you think is closest.',
      accent: AppColors.neonCyan,
    ),
    _OnboardingSlide(
      icon: Icons.local_fire_department_rounded,
      title: 'PROVE YOU\'RE\nTHE SMARTEST',
      kicker: 'Read the room.',
      body: 'Trust the odds, not the ego. Big risks pay bigger.',
      accent: AppColors.brassLight,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioServiceProvider).startMainBgm();
      ref.read(gameServiceProvider).prefetchQuestions();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    if (!mounted) return;
    if (!kIsWeb) {
      context.goNamed('premium');
    } else {
      context.goNamed('home');
    }
  }

  void _next() {
    if (_pageIndex == _slides.length - 1) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.feltDark.withValues(alpha: 0.1),
                    AppColors.feltDark.withValues(alpha: 0.4),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth.clamp(320.0, 460.0).toDouble();
                final isShort = constraints.maxHeight < 720;
                return Center(
                  child: SizedBox(
                    width: width,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        isShort ? 10 : 24,
                        20,
                        24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Header(onSkip: _finish),
                          SizedBox(height: isShort ? 12 : 32),
                          Expanded(
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: _slides.length,
                              onPageChanged: (index) {
                                setState(() => _pageIndex = index);
                              },
                              itemBuilder: (context, index) {
                                return _SlidePanel(
                                  slide: _slides[index],
                                  isActive: index == _pageIndex,
                                  compact: isShort,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                          _ProgressRail(
                            count: _slides.length,
                            activeIndex: _pageIndex,
                          ),
                          const SizedBox(height: 32),
                          _ActionPanel(
                            isLast: _pageIndex == _slides.length - 1,
                            onNext: _next,
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
}

class _Header extends StatelessWidget {
  final VoidCallback onSkip;

  const _Header({required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.goldGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.brass.withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.track_changes_rounded, color: AppColors.ink, size: 22),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        const Spacer(),
        TextButton(
          onPressed: onSkip,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text(
            'SKIP',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ).animate().fadeIn(delay: 200.ms),
      ],
    );
  }
}

class _SlidePanel extends StatelessWidget {
  final _OnboardingSlide slide;
  final bool isActive;
  final bool compact;

  const _SlidePanel({
    required this.slide,
    required this.isActive,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    if (!isActive) return const SizedBox.shrink();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroGlass(slide: slide, compact: compact),
        SizedBox(height: compact ? 32 : 48),
        Text(
          slide.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'RehnCondensed',
            color: AppColors.ivory,
            fontSize: compact ? 48 : 58,
            fontWeight: FontWeight.w900,
            height: 0.95,
            shadows: [
              Shadow(
                color: slide.accent.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: slide.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: slide.accent.withValues(alpha: 0.3)),
            ),
            child: Text(
              slide.kicker,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: slide.accent,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 150.ms, duration: 400.ms)
              .scale(begin: const Offset(0.9, 0.9)),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            slide.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
      ],
    );
  }
}

class _HeroGlass extends StatelessWidget {
  final _OnboardingSlide slide;
  final bool compact;

  const _HeroGlass({required this.slide, required this.compact});

  @override
  Widget build(BuildContext context) {
    final size = compact ? 180.0 : 220.0;
    return Center(
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: slide.accent.withValues(alpha: 0.2),
                  blurRadius: 40,
                  spreadRadius: -10,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: size * 0.5,
                height: size * 0.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: slide.accent.withValues(alpha: 0.15),
                  boxShadow: [
                    BoxShadow(
                      color: slide.accent.withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  slide.icon,
                  color: Colors.white,
                  size: size * 0.25,
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .scale(end: const Offset(1.05, 1.05), duration: 2.seconds)
                  .shimmer(duration: 3.seconds, color: Colors.white24),
            ),
          ),
        ),
      ),
    )
        .animate()
        .scale(duration: 500.ms, curve: Curves.easeOutBack)
        .fadeIn(duration: 400.ms);
  }
}

class _ProgressRail extends StatelessWidget {
  final int count;
  final int activeIndex;

  const _ProgressRail({required this.count, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.fastOutSlowIn,
            width: index == activeIndex ? 36 : 10,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: index == activeIndex
                  ? AppColors.ivory
                  : Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
              boxShadow: index == activeIndex
                  ? [
                      BoxShadow(
                        color: AppColors.ivory.withValues(alpha: 0.4),
                        blurRadius: 8,
                      )
                    ]
                  : null,
            ),
          ),
      ],
    );
  }
}

class _ActionPanel extends StatelessWidget {
  final bool isLast;
  final VoidCallback onNext;

  const _ActionPanel({
    required this.isLast,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: FilledButton(
        onPressed: onNext,
        style: FilledButton.styleFrom(
          backgroundColor: isLast ? AppColors.brassLight : AppColors.ivory,
          foregroundColor: AppColors.ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: isLast ? 8 : 0,
          shadowColor: AppColors.brassLight.withValues(alpha: 0.5),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Row(
            key: ValueKey(isLast),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isLast ? 'START PLAYING' : 'CONTINUE',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isLast ? Icons.local_fire_department_rounded : Icons.arrow_forward_rounded,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    ).animate().slideY(begin: 0.5, end: 0, duration: 400.ms, curve: Curves.easeOutBack);
  }
}

class _OnboardingSlide {
  final IconData icon;
  final String title;
  final String kicker;
  final String body;
  final Color accent;

  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.kicker,
    required this.body,
    required this.accent,
  });
}
