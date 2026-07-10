import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/game_constants.dart';
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
      icon: Icons.psychology_alt_rounded,
      title: 'Guess first.',
      kicker: 'Secret answers. Loud confidence.',
      body: 'Everyone locks in a number before the table sees the spread.',
      accent: AppColors.neonCyan,
      chips: const ['30s', 'Blind', 'Closest'],
    ),
    _OnboardingSlide(
      icon: Icons.casino_rounded,
      title: 'Bet smart.',
      kicker: 'Trust the range, not the ego.',
      body: 'Place chips after the guesses reveal. Big reads pay bigger.',
      accent: AppColors.brassLight,
      chips: const ['Risk', 'Read', 'Payout'],
    ),
    _OnboardingSlide(
      icon: Icons.workspace_premium_rounded,
      title: 'Go bigger.',
      kicker: 'Premium turns the table up.',
      body: 'Host larger rooms, longer games, and focused categories.',
      accent: AppColors.neonPurple,
      chips: [
        '${GameConstants.maxPlayers} players',
        '${GameConstants.maxRounds} rounds',
        'Categories',
      ],
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

  Future<void> _finish({bool openPremium = false}) async {
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    if (!mounted) return;
    if (openPremium && !kIsWeb) {
      context.goNamed('premium');
      return;
    }
    context.goNamed('home');
  }

  void _next() {
    if (_pageIndex == _slides.length - 1) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: CachedAssetImage(
              AppAssetPaths.background,
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.feltLight.withValues(alpha: 0.22),
                    AppColors.feltDark.withValues(alpha: 0.28),
                    Colors.black.withValues(alpha: 0.62),
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
                        isShort ? 10 : 18,
                        20,
                        16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Header(onSkip: () => _finish()),
                          SizedBox(height: isShort ? 12 : 24),
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
                                  compact: isShort,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 18),
                          _ProgressRail(
                            count: _slides.length,
                            activeIndex: _pageIndex,
                          ),
                          const SizedBox(height: 18),
                          _Actions(
                            isLast: _pageIndex == _slides.length - 1,
                            showPremium: !kIsWeb,
                            onNext: _next,
                            onPremium: () => _finish(openPremium: true),
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
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.goldGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.brass.withValues(alpha: 0.28),
                blurRadius: 16,
                spreadRadius: -4,
              ),
            ],
          ),
          child: const Icon(Icons.track_changes_rounded, color: AppColors.ink),
        ),
        const Spacer(),
        TextButton(
          onPressed: onSkip,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text(
            'SKIP',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _SlidePanel extends StatelessWidget {
  final _OnboardingSlide slide;
  final bool compact;

  const _SlidePanel({required this.slide, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroChip(slide: slide, compact: compact),
        SizedBox(height: compact ? 24 : 34),
        Text(
          slide.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'RehnCondensed',
            color: AppColors.ivory,
            fontSize: compact ? 46 : 56,
            fontWeight: FontWeight.w900,
            height: 0.9,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          slide.kicker,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: slide.accent,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          slide.body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.32,
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final chip in slide.chips)
              _SmallChip(label: chip, color: slide.accent),
          ],
        ),
      ],
    );
  }
}

class _HeroChip extends StatelessWidget {
  final _OnboardingSlide slide;
  final bool compact;

  const _HeroChip({required this.slide, required this.compact});

  @override
  Widget build(BuildContext context) {
    final size = compact ? 164.0 : 196.0;
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.feltDark,
                border: Border.all(color: AppColors.brassLight, width: 5),
                boxShadow: [
                  BoxShadow(
                    color: slide.accent.withValues(alpha: 0.35),
                    blurRadius: 38,
                    spreadRadius: -4,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < 8; i++)
              Transform.rotate(
                angle: i * 0.785398,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: size * 0.16,
                    height: size * 0.22,
                    margin: EdgeInsets.only(top: size * 0.04),
                    decoration: BoxDecoration(
                      color: i.isEven ? AppColors.mahogany : AppColors.ink,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppColors.brass.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                ),
              ),
            Container(
              width: size * 0.68,
              height: size * 0.68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.ivory, width: 13),
              ),
            ),
            Container(
              width: size * 0.42,
              height: size * 0.42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.felt,
                border: Border.all(color: AppColors.brass, width: 5),
              ),
            ),
            Container(
              width: size * 0.24,
              height: size * 0.24,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.goldGradient,
              ),
              child: Icon(slide.icon, color: AppColors.ink, size: size * 0.13),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SmallChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.62)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.ivory,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
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
            duration: const Duration(milliseconds: 180),
            width: index == activeIndex ? 30 : 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: index == activeIndex
                  ? AppColors.brassLight
                  : AppColors.textMuted.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  final bool isLast;
  final bool showPremium;
  final VoidCallback onNext;
  final VoidCallback onPremium;

  const _Actions({
    required this.isLast,
    required this.showPremium,
    required this.onNext,
    required this.onPremium,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: onNext,
            icon: Icon(
              isLast ? Icons.play_arrow_rounded : Icons.arrow_forward_rounded,
            ),
            label: Text(isLast ? 'START PLAYING' : 'CONTINUE'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brassLight,
              foregroundColor: AppColors.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        if (showPremium) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 46,
            child: TextButton.icon(
              onPressed: onPremium,
              icon: const Icon(Icons.workspace_premium_rounded, size: 20),
              label: const Text('SEE PREMIUM'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brassLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: AppColors.brassLight.withValues(alpha: 0.68),
                  ),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _OnboardingSlide {
  final IconData icon;
  final String title;
  final String kicker;
  final String body;
  final Color accent;
  final List<String> chips;

  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.kicker,
    required this.body,
    required this.accent,
    required this.chips,
  });
}
