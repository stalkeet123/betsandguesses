import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    const _OnboardingSlide(
      icon: Icons.qr_code_scanner_rounded,
      kicker: 'INSTANT ACCESS',
      title: 'NO DOWNLOADS\nFOR FRIENDS',
      body:
          'Only the host needs the app. Friends just scan your screen and play instantly from any mobile browser.',
      featureTag: '📱 ONLY 1 APP NEEDED FOR THE ENTIRE ROOM',
      accent: AppColors.brassLight,
      glowColor: Color(0xFFD7A84A),
    ),
    const _OnboardingSlide(
      icon: Icons.casino_rounded,
      kicker: 'THE CORE MECHANIC',
      title: 'GUESS FIRST.\nBET SECOND.',
      body:
          'Everyone locks in their numerical guess blindly. Then place your casino chips on who you think got closest.',
      featureTag: '🎲 BLIND GUESSES + REAL CASINO BOARD ODDS',
      accent: AppColors.neonCyan,
      glowColor: Color(0xFF47C7C0),
    ),
    const _OnboardingSlide(
      icon: Icons.workspace_premium_rounded,
      kicker: 'RISK & REWARD',
      title: 'PLAY THE ODDS.\nTAKE THE POT.',
      body:
          'Trust the math or call someone\'s bluff. Correct bets pay out up to 5x odds. Highest bankroll takes victory.',
      featureTag: '💰 UP TO 5X PAYOUTS ON EVERY ROUND',
      accent: AppColors.chipGold,
      glowColor: Color(0xFFFFC84D),
    ),
    const _OnboardingSlide(
      icon: Icons.celebration_rounded,
      kicker: 'TWO WAYS TO PLAY',
      title: 'CLASSIC TRIVIA\nOR PARTY CHAOS',
      body:
          'Switch between high-IQ numerical trivia and hilarious physical party challenges. The ultimate party experience.',
      featureTag: '✨ TRIVIA + LIVING ROOM PHYSICAL CHALLENGES',
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
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    ref.read(audioServiceProvider).playClick();
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    if (!mounted) return;
    if (!kIsWeb) {
      context.goNamed('premium');
    } else {
      context.goNamed('home');
    }
  }

  void _next() {
    HapticFeedback.lightImpact();
    ref.read(audioServiceProvider).playClick();
    if (_pageIndex == _slides.length - 1) {
      _finish();
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
          // Background Table Felt Image
          const Positioned.fill(
            child: RepaintBoundary(
              child: CachedAssetImage(
                AppAssetPaths.background,
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Luxury Ambient Vignette & Mood Glow
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.3,
                  colors: [
                    const Color(0xFF1B4E38).withValues(alpha: 0.35),
                    const Color(0xFF0A2218).withValues(alpha: 0.65),
                    Colors.black.withValues(alpha: 0.92),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth.clamp(320.0, 480.0).toDouble();
                final isShort = constraints.maxHeight < 740;

                return Center(
                  child: SizedBox(
                    width: width,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        isShort ? 8 : 16,
                        20,
                        isShort ? 14 : 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTopHeader(),
                          SizedBox(height: isShort ? 10 : 20),
                          Expanded(
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: _slides.length,
                              onPageChanged: (index) {
                                HapticFeedback.selectionClick();
                                setState(() => _pageIndex = index);
                              },
                              itemBuilder: (context, index) {
                                return _LuxurySlideCard(
                                  slide: _slides[index],
                                  isActive: index == _pageIndex,
                                  compact: isShort,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildProgressIndicator(),
                          SizedBox(height: isShort ? 14 : 22),
                          _buildBottomAction(isLast: _pageIndex == _slides.length - 1),
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

  Widget _buildTopHeader() {
    return Row(
      children: [
        // Brand Logo Chip
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.brassLight.withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.casino_rounded,
                color: AppColors.brassLight,
                size: 17,
              ),
              const SizedBox(width: 7),
              Text(
                'BETS & GUESSES',
                style: TextStyle(
                  fontFamily: 'RehnCondensed',
                  color: AppColors.ivory,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  height: 1,
                  shadows: [
                    Shadow(
                      color: AppColors.brass.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0),
        const Spacer(),
        // Skip Button
        TextButton(
          onPressed: _finish,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.brassLight,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: AppColors.brassLight.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            backgroundColor: Colors.black.withValues(alpha: 0.25),
          ),
          child: const Text(
            'SKIP',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ).animate().fadeIn(delay: 200.ms),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _slides.length; i++)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _pageController.animateToPage(
                i,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 7,
              width: i == _pageIndex ? 36 : 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: i == _pageIndex ? AppColors.goldGradient : null,
                color: i == _pageIndex
                    ? null
                    : Colors.white.withValues(alpha: 0.18),
                boxShadow: i == _pageIndex
                    ? [
                        BoxShadow(
                          color: AppColors.brass.withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
                border: Border.all(
                  color: i == _pageIndex
                      ? AppColors.ivory
                      : Colors.transparent,
                  width: 0.8,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomAction({required bool isLast}) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: AppColors.goldGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.brass.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _next,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isLast ? 'START PLAYING NOW' : 'CONTINUE',
                  style: const TextStyle(
                    fontFamily: 'RehnCondensed',
                    color: AppColors.ink,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  isLast
                      ? Icons.local_fire_department_rounded
                      : Icons.arrow_forward_rounded,
                  color: AppColors.ink,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().slideY(
          begin: 0.4,
          end: 0,
          duration: 350.ms,
          curve: Curves.easeOutBack,
        );
  }
}

class _LuxurySlideCard extends StatelessWidget {
  final _OnboardingSlide slide;
  final bool isActive;
  final bool compact;

  const _LuxurySlideCard({
    required this.slide,
    required this.isActive,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    if (!isActive) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        compact ? 16 : 24,
        20,
        compact ? 16 : 22,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E3A2D).withValues(alpha: 0.94),
            const Color(0xFF10281E).withValues(alpha: 0.96),
            const Color(0xFF091711).withValues(alpha: 0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.brassLight.withValues(alpha: 0.65),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: slide.glowColor.withValues(alpha: 0.22),
            blurRadius: 36,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Glowing Orb Icon Presentation
          _buildEmblem(compact ? 110.0 : 136.0),
          SizedBox(height: compact ? 16 : 24),
          // Kicker Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: slide.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: slide.accent.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Text(
              slide.kicker,
              style: TextStyle(
                color: slide.accent,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
                height: 1,
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 300.ms)
              .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
          SizedBox(height: compact ? 10 : 14),
          // Main Headline
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              slide.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'RehnCondensed',
                color: AppColors.ivory,
                fontSize: compact ? 40 : 48,
                fontWeight: FontWeight.w900,
                height: 0.95,
                letterSpacing: 1.2,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                  Shadow(
                    color: slide.glowColor.withValues(alpha: 0.4),
                    blurRadius: 18,
                  ),
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 350.ms)
              .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
          SizedBox(height: compact ? 10 : 14),
          // Description Body
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              slide.body,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: compact ? 14 : 16,
                fontWeight: FontWeight.w600,
                height: 1.35,
                letterSpacing: 0.2,
              ),
            ),
          ).animate().fadeIn(delay: 150.ms, duration: 350.ms),
          SizedBox(height: compact ? 12 : 18),
          // Highlight Feature Tag Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: Text(
              slide.featureTag,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.ivory,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ).animate().fadeIn(delay: 250.ms),
        ],
      ),
    );
  }

  Widget _buildEmblem(double size) {
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              slide.glowColor.withValues(alpha: 0.35),
              slide.glowColor.withValues(alpha: 0.1),
              Colors.transparent,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: slide.glowColor.withValues(alpha: 0.3),
              blurRadius: 36,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: size * 0.72,
            height: size * 0.72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.feltDark,
                  const Color(0xFF0B1F17),
                ],
              ),
              border: Border.all(
                color: slide.accent,
                width: 2.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                slide.icon,
                color: slide.accent,
                size: size * 0.38,
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(0.96, 0.96),
                end: const Offset(1.04, 1.04),
                duration: 2200.ms,
                curve: Curves.easeInOut,
              )
              .shimmer(
                duration: 2600.ms,
                color: Colors.white.withValues(alpha: 0.25),
              ),
        ),
      ),
    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack);
  }
}

class _OnboardingSlide {
  final IconData icon;
  final String kicker;
  final String title;
  final String body;
  final String featureTag;
  final Color accent;
  final Color glowColor;

  const _OnboardingSlide({
    required this.icon,
    required this.kicker,
    required this.title,
    required this.body,
    required this.featureTag,
    required this.accent,
    required this.glowColor,
  });
}
