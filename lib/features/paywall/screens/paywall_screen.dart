import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/revenuecat_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/monetization_copy.dart';
import '../../../core/widgets/cached_asset_image.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  final bool enableStartupWork;
  final String entryPoint;

  const PaywallScreen({
    super.key,
    this.enableStartupWork = true,
    this.entryPoint = 'unknown',
  });

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  late final AnimationController _glowController;
  Map<String, String> _packagePrices = const {};
  bool _purchaseDataLoaded = false;
  String? _busyPackageIdentifier;
  bool _isRestoring = false;
  bool _isPremium = false;
  bool _didTrackPaywallView = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);
    if (widget.enableStartupWork) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(audioServiceProvider).startMainBgm();
        _loadRevenueCat();
        _trackPaywallViewed();
      });
    }
  }

  void _trackPaywallViewed() {
    if (_didTrackPaywallView) return;
    _didTrackPaywallView = true;
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .track(
            AnalyticsEventName.paywallViewed,
            properties: {'entry_point': widget.entryPoint},
          ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPushNext() {
    _glowController.stop();
  }

  @override
  void didPopNext() {
    _glowController.repeat(reverse: true);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _ensureCanonicalRevenueCatIdentity() async {
    final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (uid == null || uid.isEmpty)
      throw StateError('Authenticated user required');
    await ref.read(revenueCatServiceProvider).initialize(appUserId: uid);
  }

  Future<void> _syncMonetizationNonFatally() async {
    try {
      await ref.read(monetizationServiceProvider).syncRevenueCatEntitlement();
    } catch (error) {
      debugPrint('Monetization sync failed: $error');
    } finally {
      ref.invalidate(monetizationStatusProvider);
      ref.invalidate(effectivePremiumStatusProvider);
    }
  }

  Future<void> _loadRevenueCat() async {
    final service = ref.read(revenueCatServiceProvider);

    try {
      await _ensureCanonicalRevenueCatIdentity();
      final prices = await service.packagePrices();
      final isPremium = await service.isPremium();

      if (!mounted) return;
      setState(() {
        _packagePrices = prices;
        _isPremium = isPremium;
        _purchaseDataLoaded = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _purchaseDataLoaded = true);
      _showSnack('Could not load purchases: $error');
    }
  }

  bool _isPackagePurchasable(String packageIdentifier) {
    final price = _packagePrices[packageIdentifier];
    return _purchaseDataLoaded && price != null && price.trim().isNotEmpty;
  }

  String _purchasePriceLabel(String packageIdentifier) {
    if (!_purchaseDataLoaded) return 'LOADING…';
    return _isPackagePurchasable(packageIdentifier)
        ? _packagePrices[packageIdentifier]!
        : 'CURRENTLY UNAVAILABLE';
  }

  String _purchaseCtaLabel(String action, String packageIdentifier) {
    final price = _purchasePriceLabel(packageIdentifier);
    if (price == 'LOADING…' || price == 'CURRENTLY UNAVAILABLE') {
      return price;
    }
    return '$action • $price';
  }

  Future<void> _purchase(String packageIdentifier) async {
    if (!_isPackagePurchasable(packageIdentifier) ||
        _busyPackageIdentifier != null ||
        _isRestoring) {
      return;
    }

    setState(() => _busyPackageIdentifier = packageIdentifier);

    unawaited(
      ref
          .read(analyticsServiceProvider)
          .track(
            AnalyticsEventName.purchaseStarted,
            properties: {'package_identifier': packageIdentifier},
          ),
    );

    await _ensureCanonicalRevenueCatIdentity();
    final service = ref.read(revenueCatServiceProvider);
    final result = await service.purchasePackage(packageIdentifier);
    ref.invalidate(premiumStatusProvider);
    ref.invalidate(effectivePremiumStatusProvider);

    if (!mounted) return;
    setState(() {
      _busyPackageIdentifier = null;
      _isPremium = result.isPremium;
    });

    if (result.cancelled) {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .track(
              AnalyticsEventName.purchaseCancelled,
              properties: {'package_identifier': packageIdentifier},
            ),
      );
      return;
    }

    if (result.success) {
      if (result.isPremium) await _syncMonetizationNonFatally();
      _showSuccessDialog(
        'Purchase Successful!',
        'Premium access is now active.',
      );
    } else {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .track(
              AnalyticsEventName.purchaseFailed,
              properties: {'package_identifier': packageIdentifier},
            ),
      );
      _showErrorDialog(
        'Purchase Failed',
        result.message ?? 'Unable to complete purchase.',
      );
    }
  }

  Future<void> _restorePurchases() async {
    if (_busyPackageIdentifier != null || _isRestoring) return;

    setState(() => _isRestoring = true);

    await _ensureCanonicalRevenueCatIdentity();
    final service = ref.read(revenueCatServiceProvider);
    final result = await service.restorePurchases();
    ref.invalidate(premiumStatusProvider);
    ref.invalidate(effectivePremiumStatusProvider);

    if (!mounted) return;
    setState(() {
      _isRestoring = false;
      _isPremium = result.isPremium;
    });

    if (result.success) {
      if (result.isPremium) await _syncMonetizationNonFatally();
      _showSuccessDialog(
        'Purchases Restored!',
        'Your premium access has been restored.',
      );
    } else {
      _showErrorDialog(
        'Restore Failed',
        result.message ?? 'No active purchase found.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final serverStatus = ref.watch(monetizationStatusProvider).asData?.value;
    final effectivePremium = ref.watch(effectivePremiumStatusProvider);
    final isPremium =
        effectivePremium.asData?.value ??
        (serverStatus == null
            ? _isPremium
            : resolveEffectivePremiumStatus(
                revenueCatPremium: _isPremium,
                serverStatus: serverStatus,
              ));

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
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.18,
                  colors: [
                    AppColors.feltLight.withValues(alpha: 0.16),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.42),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final veryShort = constraints.maxHeight < 590;
                final short = constraints.maxHeight < 720;
                final horizontalPadding = constraints.maxWidth <= 340
                    ? 12.0
                    : constraints.maxWidth < 390
                    ? 16.0
                    : 20.0;
                final verticalPadding = veryShort ? 6.0 : 10.0;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        verticalPadding,
                        horizontalPadding,
                        veryShort ? 8 : 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildCompactHeader(context, compact: veryShort),
                          SizedBox(height: veryShort ? 1 : 4),
                          _buildTitle(compact: veryShort),
                          const Spacer(flex: 1),
                          SizedBox(height: veryShort ? 3 : 6),
                          _buildCurrentPlanStrip(
                            isPremium: isPremium,
                            freeHostGamesRemaining:
                                serverStatus?.freeHostGamesRemaining,
                            compact: veryShort,
                          ),
                          const Spacer(flex: 1),
                          SizedBox(height: veryShort ? 4 : 7),
                          _buildBenefitStrip(compact: veryShort),
                          const Spacer(flex: 2),
                          SizedBox(height: veryShort ? 5 : 9),
                          _buildPlans(
                            context,
                            isPremium: isPremium,
                            compact: veryShort || short,
                          ),
                          const Spacer(flex: 3),
                          SizedBox(height: veryShort ? 5 : 8),
                          _buildFooter(compact: veryShort),
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

  Widget _buildCompactHeader(BuildContext context, {required bool compact}) {
    return SizedBox(
      height: compact ? 52 : 68,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: compact ? 49 : 63,
            child: const CachedAssetImage(
              AppAssetPaths.logo,
              fit: BoxFit.contain,
              cacheWidth: 420,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    context.goNamed('home');
                  }
                },
                icon: const Center(child: Icon(Icons.close_rounded, size: 22)),
                color: AppColors.ivory,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.feltDark.withValues(alpha: 0.84),
                  side: const BorderSide(
                    color: AppColors.brassLight,
                    width: 1.5,
                  ),
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle({required bool compact}) {
    return Text(
      'KEEP THE PARTY GOING',
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'RehnCondensed',
        color: AppColors.ivory,
        fontSize: compact ? 18 : 21,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
        height: 1,
        shadows: const [
          Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
    );
  }

  Widget _buildBenefitStrip({required bool compact}) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: compact ? 5 : 7),
      decoration: _darkPanel(radius: 14),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _BenefitItem(
                icon: Icons.all_inclusive_rounded,
                title: 'UNLIMITED HOSTING',
                subtitle: 'Host more games',
                compact: compact,
              ),
            ),
            _verticalRule(),
            Expanded(
              child: _BenefitItem(
                icon: Icons.groups_rounded,
                title: 'BIGGER LOBBIES',
                subtitle: 'Up to 10 Players',
                compact: compact,
              ),
            ),
            _verticalRule(),
            Expanded(
              child: _BenefitItem(
                icon: Icons.timer_outlined,
                title: 'MORE ROUNDS',
                subtitle: 'Up to 12 Rounds',
                compact: compact,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPlanStrip({
    required bool isPremium,
    required int? freeHostGamesRemaining,
    required bool compact,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: compact ? 5 : 6,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.brassLight.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            paywallCurrentPlanText(
              isPremium: isPremium,
              freeHostGamesRemaining: freeHostGamesRemaining,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isPremium
                  ? AppColors.neonGreen
                  : AppColors.ivory.withValues(alpha: 0.72),
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlans(
    BuildContext context, {
    required bool isPremium,
    required bool compact,
  }) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PlanCard(
              variant: _PlanCardVariant.primary,
              title: 'PARTY PASS',
              subtitle: 'Premium access for the next 24 hours.',
              badge: 'MOST POPULAR',
              crownColor: AppColors.chipGold,
              glowValue: _glowController.value,
              compact: compact,
              background: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF642A79),
                  Color(0xFF301337),
                  Color(0xFF17091E),
                ],
              ),
              features: const [
                _PlanFeature(Icons.all_inclusive_rounded, 'Unlimited hosting'),
                _PlanFeature(Icons.groups_rounded, 'Up to 10 players'),
                _PlanFeature(Icons.timer_outlined, 'Up to 12 rounds'),
                _PlanFeature(Icons.category_rounded, 'Classic categories'),
              ],
              priceLabel: _purchaseCtaLabel(
                'GET PARTY PASS',
                RevenueCatConstants.dailyPassPackageIdentifier,
              ),
              isPurchasable: _isPackagePurchasable(
                RevenueCatConstants.dailyPassPackageIdentifier,
              ),
              isLoading:
                  _busyPackageIdentifier ==
                  RevenueCatConstants.dailyPassPackageIdentifier,
              onTap:
                  isPremium ||
                      !_isPackagePurchasable(
                        RevenueCatConstants.dailyPassPackageIdentifier,
                      )
                  ? null
                  : () => _purchase(
                      RevenueCatConstants.dailyPassPackageIdentifier,
                    ),
            ),
            SizedBox(height: compact ? 8 : 12),
            _PlanCard(
              variant: _PlanCardVariant.secondary,
              title: 'FULL ACCESS',
              subtitle: 'Lifetime • One-time purchase',
              crownColor: AppColors.neonGreen,
              compact: compact,
              background: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF123E31),
                  Color(0xFF0B281F),
                  Color(0xFF071A15),
                ],
              ),
              features: const [
                _PlanFeature(
                  Icons.all_inclusive_rounded,
                  'Unlimited hosting • 10 players',
                ),
                _PlanFeature(
                  Icons.category_rounded,
                  '12 rounds • Classic categories',
                ),
              ],
              priceLabel: _purchaseCtaLabel(
                'FULL ACCESS',
                RevenueCatConstants.lifetimePackageIdentifier,
              ),
              isPurchasable: _isPackagePurchasable(
                RevenueCatConstants.lifetimePackageIdentifier,
              ),
              isGreenPrice: true,
              isLoading:
                  _busyPackageIdentifier ==
                  RevenueCatConstants.lifetimePackageIdentifier,
              onTap:
                  isPremium ||
                      !_isPackagePurchasable(
                        RevenueCatConstants.lifetimePackageIdentifier,
                      )
                  ? null
                  : () => _purchase(
                      RevenueCatConstants.lifetimePackageIdentifier,
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _launchURL(String urlString) async {
    final url = Uri.parse(urlString);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showSnack('Could not open link.');
    }
  }

  Widget _buildFooter({required bool compact}) {
    return SizedBox(
      height: compact ? 26 : 30,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _FooterChip(
              icon: _isRestoring
                  ? Icons.hourglass_top_rounded
                  : Icons.restore_rounded,
              label: _isRestoring ? 'RESTORING' : 'RESTORE PURCHASES',
              onTap: _restorePurchases,
            ),
            const SizedBox(width: 20),
            _FooterChip(
              icon: Icons.description_rounded,
              label: 'TERMS OF USE',
              onTap: () => _launchURL(
                'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
              ),
            ),
            const SizedBox(width: 20),
            _FooterChip(
              icon: Icons.privacy_tip_rounded,
              label: 'PRIVACY POLICY',
              onTap: () =>
                  _launchURL('https://bets-and-guesses.com/privacy.html'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verticalRule() {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: AppColors.brassLight.withValues(alpha: 0.22),
    );
  }

  BoxDecoration _darkPanel({required double radius}) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.feltDark.withValues(alpha: 0.94),
          AppColors.felt.withValues(alpha: 0.68),
          AppColors.feltDark.withValues(alpha: 0.96),
        ],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: AppColors.brassLight.withValues(alpha: 0.34),
        width: 1.3,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.36),
          blurRadius: 18,
          offset: const Offset(0, 9),
        ),
      ],
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.feltDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.neonGreen, width: 2),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.neonGreen,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ivory,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(color: AppColors.ivory, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // pop dialog
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop(); // pop paywall
                } else {
                  context.goNamed('home'); // go home
                }
              },
              child: const Text(
                'LET\'S GO!',
                style: TextStyle(
                  color: AppColors.neonGreen,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.feltDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.redAccent, width: 2),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ivory,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(color: AppColors.ivory, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool compact;

  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: AppColors.brassLight, size: compact ? 22 : 28),
        SizedBox(height: compact ? 4 : 6),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.brassLight,
            fontSize: compact ? 9 : 11,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        SizedBox(height: compact ? 3 : 5),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.ivory,
            fontSize: compact ? 8 : 10,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _PlanFeature {
  final IconData icon;
  final String label;

  const _PlanFeature(this.icon, this.label);
}

enum _PlanCardVariant { primary, secondary }

class _PlanCard extends StatelessWidget {
  final _PlanCardVariant variant;
  final String title;
  final String subtitle;
  final String? badge;
  final Color crownColor;
  final Gradient? background;
  final List<_PlanFeature> features;
  final String priceLabel;
  final bool isPurchasable;
  final bool isGreenPrice;
  final bool isLoading;
  final double glowValue;
  final VoidCallback? onTap;
  final bool compact;

  const _PlanCard({
    required this.variant,
    required this.title,
    required this.subtitle,
    this.badge,
    this.crownColor = AppColors.brassLight,
    this.background,
    required this.features,
    required this.priceLabel,
    required this.isPurchasable,
    this.isGreenPrice = false,
    this.isLoading = false,
    this.glowValue = 0.0,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == _PlanCardVariant.primary;
    final badgeOverlap = compact ? 10.0 : 14.0;
    final glow = 0.26 + (glowValue * 0.46);
    final card = Container(
      key: ValueKey(isPrimary ? 'paywall-party-pass' : 'paywall-full-access'),
      alignment: Alignment.topCenter,
      padding: EdgeInsets.fromLTRB(
        compact ? 11 : 16,
        isPrimary ? badgeOverlap + (compact ? 12 : 16) : (compact ? 8 : 10),
        compact ? 11 : 16,
        isPrimary ? (compact ? 9 : 13) : (compact ? 8 : 10),
      ),
      decoration: BoxDecoration(
        gradient:
            background ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.feltDark.withValues(alpha: 0.98),
                AppColors.felt.withValues(alpha: 0.72),
                AppColors.feltDark.withValues(alpha: 0.98),
              ],
            ),
        borderRadius: BorderRadius.circular(compact ? 14 : 18),
        border: Border.all(
          color: isPrimary
              ? Color.lerp(
                  AppColors.brassLight,
                  Colors.white,
                  glowValue * 0.42,
                )!
              : AppColors.neonGreen.withValues(alpha: 0.7),
          width: isPrimary ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          if (isPrimary)
            BoxShadow(
              color: AppColors.brassLight.withValues(alpha: glow),
              blurRadius: 22 + (glowValue * 18),
              spreadRadius: 1.5 + (glowValue * 2.8),
            ),
        ],
      ),
      child: isPrimary
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PlanHeading(
                  title: title,
                  subtitle: subtitle,
                  crownColor: crownColor,
                  isPrimary: true,
                  compact: compact,
                ),
                SizedBox(height: compact ? 6 : 9),
                Container(
                  height: 1,
                  color: AppColors.brassLight.withValues(alpha: 0.26),
                ),
                SizedBox(height: compact ? 7 : 10),
                for (var index = 0; index < features.length; index++) ...[
                  _FeatureRow(feature: features[index], compact: compact),
                  if (index != features.length - 1)
                    SizedBox(height: compact ? 6 : 9),
                ],
                SizedBox(height: compact ? 9 : 13),
                _PriceButton(
                  label: priceLabel,
                  isGreen: isGreenPrice,
                  isPurchasable: isPurchasable,
                  isLoading: isLoading,
                  onTap: onTap,
                  compact: compact,
                ),
                SizedBox(height: compact ? 5 : 7),
                Text(
                  'No auto renewal',
                  textAlign: TextAlign.center,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    color: AppColors.ivory.withValues(alpha: 0.68),
                    fontSize: compact ? 9 : 10,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ],
            )
          : _SecondaryPlanContent(
              title: title,
              subtitle: subtitle,
              crownColor: crownColor,
              features: features,
              priceLabel: priceLabel,
              isPurchasable: isPurchasable,
              isLoading: isLoading,
              isGreenPrice: isGreenPrice,
              onTap: onTap,
              compact: compact,
            ),
    );

    if (!isPrimary) return card;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: EdgeInsets.only(top: badgeOverlap),
          child: card,
        ),
        Positioned(
          top: 0,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 11 : 18,
              vertical: compact ? 5 : 7,
            ),
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.ink.withValues(alpha: 0.28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              badge!,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: AppColors.ink,
                fontSize: compact ? 8 : 10,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SecondaryPlanContent extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color crownColor;
  final List<_PlanFeature> features;
  final String priceLabel;
  final bool isPurchasable;
  final bool isLoading;
  final bool isGreenPrice;
  final VoidCallback? onTap;
  final bool compact;

  const _SecondaryPlanContent({
    required this.title,
    required this.subtitle,
    required this.crownColor,
    required this.features,
    required this.priceLabel,
    required this.isPurchasable,
    required this.isLoading,
    required this.isGreenPrice,
    this.onTap,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              color: crownColor,
              size: compact ? 18 : 23,
            ),
            SizedBox(width: compact ? 6 : 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: 'RehnCondensed',
                  color: AppColors.ivory,
                  fontSize: compact ? 22 : 27,
                  fontWeight: FontWeight.w900,
                  height: 0.95,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 4 : 6),
        Text(
          subtitle,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: AppColors.neonGreen,
            fontSize: compact ? 9 : 11,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        SizedBox(height: compact ? 6 : 8),
        Text(
          features.map((feature) => feature.label).join('\n'),
          maxLines: 2,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: AppColors.ivory.withValues(alpha: 0.8),
            fontSize: compact ? 9 : 11,
            fontWeight: FontWeight.w700,
            height: 1.18,
          ),
        ),
        SizedBox(height: compact ? 8 : 11),
        _PriceButton(
          label: priceLabel,
          isGreen: isGreenPrice,
          isPurchasable: isPurchasable,
          isLoading: isLoading,
          onTap: onTap,
          compact: compact,
        ),
      ],
    );
  }
}

class _PlanHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color crownColor;
  final bool isPrimary;
  final bool compact;

  const _PlanHeading({
    required this.title,
    required this.subtitle,
    required this.crownColor,
    required this.isPrimary,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              color: crownColor,
              size: compact ? 18 : 23,
            ),
            SizedBox(width: compact ? 6 : 8),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: 'RehnCondensed',
                  color: isPrimary ? AppColors.brassLight : AppColors.ivory,
                  fontSize: compact ? 22 : 27,
                  fontWeight: FontWeight.w900,
                  height: 0.95,
                  shadows: const [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            if (isPrimary) ...[
              SizedBox(width: compact ? 6 : 8),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 7 : 9,
                  vertical: compact ? 4 : 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.26),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.brassLight.withValues(alpha: 0.52),
                  ),
                ),
                child: Text(
                  '24 HOURS',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    color: AppColors.brassLight,
                    fontSize: compact ? 8 : 9,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: compact ? 4 : 6),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: AppColors.ivory.withValues(alpha: 0.76),
            fontSize: compact ? 10 : 12,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final _PlanFeature feature;
  final bool compact;

  const _FeatureRow({required this.feature, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          feature.icon,
          color: AppColors.brassLight,
          size: compact ? 12 : 16,
        ),
        SizedBox(width: compact ? 4 : 8),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              feature.label,
              maxLines: 1,
              style: TextStyle(
                color: AppColors.ivory,
                fontSize: compact ? 10 : 12,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PriceButton extends StatelessWidget {
  final String label;
  final bool isGreen;
  final bool isPurchasable;
  final bool isLoading;
  final VoidCallback? onTap;
  final bool compact;

  const _PriceButton({
    required this.label,
    required this.isGreen,
    required this.isPurchasable,
    required this.isLoading,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final unavailable = !isLoading && !isPurchasable;
    final backgroundColor = unavailable
        ? (isGreen ? const Color(0xFF0B2A20) : const Color(0xFF2B172E))
        : isGreen
        ? AppColors.feltLight
        : AppColors.brass;
    final foregroundColor = unavailable
        ? AppColors.ivory.withValues(alpha: 0.5)
        : isGreen
        ? AppColors.ivory
        : AppColors.ink;

    return SizedBox(
      width: double.infinity,
      height: compact ? 30 : 38,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor,
          disabledForegroundColor: foregroundColor,
          elevation: unavailable ? 0 : null,
          textStyle: TextStyle(
            fontSize: compact ? 14 : 17,
            fontWeight: FontWeight.w900,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: unavailable
                  ? AppColors.brassLight.withValues(alpha: 0.2)
                  : AppColors.ivory.withValues(alpha: 0.56),
              width: 1,
            ),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                ),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 14 : 17,
                  ),
                ),
              ),
      ),
    );
  }
}

class _FooterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _FooterChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: AppColors.ivory.withValues(alpha: 0.72),
              size: 17,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.ivory.withValues(alpha: 0.72),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
