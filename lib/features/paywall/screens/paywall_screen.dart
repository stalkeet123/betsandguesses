import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/revenuecat_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/monetization_copy.dart';
import '../../../core/widgets/cached_asset_image.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioServiceProvider).startMainBgm();
      _loadRevenueCat();
    });
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
        : 'UNAVAILABLE';
  }

  Future<void> _purchase(String packageIdentifier) async {
    if (!_isPackagePurchasable(packageIdentifier) ||
        _busyPackageIdentifier != null ||
        _isRestoring) {
      return;
    }

    setState(() => _busyPackageIdentifier = packageIdentifier);

    await _ensureCanonicalRevenueCatIdentity();
    final service = ref.read(revenueCatServiceProvider);
    final result = await service.purchasePackage(packageIdentifier);
    ref.invalidate(premiumStatusProvider);

    if (!mounted) return;
    setState(() {
      _busyPackageIdentifier = null;
      _isPremium = result.isPremium;
    });

    if (result.cancelled) return;

    if (result.success) {
      if (result.isPremium) await _syncMonetizationNonFatally();
      _showSuccessDialog(
        'Purchase Successful!',
        'Premium access is now active.',
      );
    } else {
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
    final isPremium = _isPremium || (serverStatus?.isPremium ?? false);

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
                    Colors.black.withValues(alpha: 0.36),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final contentWidth = constraints.maxWidth
                    .clamp(320.0, 560.0)
                    .toDouble();
                final designHeight = constraints.maxHeight
                    .clamp(720.0, 900.0)
                    .toDouble();
                final horizontalPadding = contentWidth < 380 ? 14.0 : 20.0;

                return Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: contentWidth,
                      height: designHeight,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          8,
                          horizontalPadding,
                          14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTopBar(context),
                            const SizedBox(height: 4),
                            const SizedBox(
                              height: 100,
                              child: CachedAssetImage(
                                AppAssetPaths.logo,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildTitle(),
                            const SizedBox(height: 8),
                            _buildCurrentPlanStrip(
                              isPremium: isPremium,
                              freeHostGamesRemaining:
                                  serverStatus?.freeHostGamesRemaining,
                            ),
                            const SizedBox(height: 10),
                            _buildBenefitStrip(),
                            const SizedBox(height: 14),
                            Expanded(
                              child: _buildPlans(context, isPremium: isPremium),
                            ),
                            const SizedBox(height: 12),
                            _buildBottomBanner(),
                            const SizedBox(height: 10),
                            _buildFooter(),
                          ],
                        ),
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

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        SizedBox(
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
              side: const BorderSide(color: AppColors.brassLight, width: 1.5),
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildTitle() {
    return const Text(
      'KEEP THE PARTY GOING',
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'RehnCondensed',
        color: AppColors.ivory,
        fontSize: 19,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
        height: 1,
        shadows: [
          Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
    );
  }

  Widget _buildBenefitStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: _darkPanel(radius: 14),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _BenefitItem(
                icon: Icons.all_inclusive_rounded,
                title: 'UNLIMITED HOSTING',
                subtitle: 'Host more games',
              ),
            ),
            _verticalRule(),
            Expanded(
              child: _BenefitItem(
                icon: Icons.category_rounded,
                title: 'FULL CLASSIC LIBRARY',
                subtitle: 'More questions to play',
              ),
            ),
            _verticalRule(),
            Expanded(
              child: _BenefitItem(
                icon: Icons.groups_rounded,
                title: 'BIGGER LOBBIES',
                subtitle: 'Up to 10 Players',
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
  }) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
          style: TextStyle(
            color: isPremium
                ? AppColors.neonGreen
                : AppColors.ivory.withValues(alpha: 0.72),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildPlans(BuildContext context, {required bool isPremium}) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, _) {
        final cards = [
          _PlanCard(
            title: 'PARTY PASS',
            subtitle: '24 Hours',
            badge: 'MOST POPULAR',
            crownColor: AppColors.chipGold,
            glowValue: _glowController.value,
            background: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF5F2477), Color(0xFF271127), Color(0xFF14071C)],
            ),
            features: const [
              _PlanFeature(Icons.access_time_rounded, '24-hour access'),
              _PlanFeature(Icons.event_repeat_rounded, 'No auto renewal'),
              _PlanFeature(Icons.all_inclusive_rounded, 'Unlimited hosting'),
              _PlanFeature(Icons.groups_rounded, '10 Players • 12 Rounds'),
              _PlanFeature(
                Icons.category_rounded,
                'Full Classic library • Categories',
              ),
            ],
            price: _purchasePriceLabel(
              RevenueCatConstants.dailyPassPackageIdentifier,
            ),
            footer: '24 HOURS ACCESS',
            isLoading:
                _busyPackageIdentifier ==
                RevenueCatConstants.dailyPassPackageIdentifier,
            onTap:
                isPremium ||
                    !_isPackagePurchasable(
                      RevenueCatConstants.dailyPassPackageIdentifier,
                    )
                ? null
                : () =>
                      _purchase(RevenueCatConstants.dailyPassPackageIdentifier),
          ),
          _PlanCard(
            title: 'FULL ACCESS',
            subtitle: 'One-time purchase',
            crownColor: AppColors.neonGreen,
            features: const [
              _PlanFeature(Icons.workspace_premium_rounded, 'Lifetime access'),
              _PlanFeature(Icons.all_inclusive_rounded, 'Unlimited hosting'),
              _PlanFeature(Icons.groups_rounded, 'Up to 10 Players'),
              _PlanFeature(Icons.timer_outlined, 'Up to 12 Rounds'),
              _PlanFeature(
                Icons.category_rounded,
                'Full Classic library • Categories',
              ),
            ],
            price: _purchasePriceLabel(
              RevenueCatConstants.lifetimePackageIdentifier,
            ),
            footer: 'LIFETIME ACCESS',
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
                : () =>
                      _purchase(RevenueCatConstants.lifetimePackageIdentifier),
          ),
        ];

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              Expanded(child: cards[index]),
              if (index != cards.length - 1) const SizedBox(width: 14),
            ],
          ],
        );
      },
    );
  }

  Widget _buildBottomBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: _darkPanel(radius: 14).copyWith(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF17100F), Color(0xFF071C13), Color(0xFF101010)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.goldGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.brass.withValues(alpha: 0.38),
                  blurRadius: 18,
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: AppColors.ink,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'HOST MORE. PLAY BIGGER.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.brassLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Unlimited hosting, full Classic library & bigger games.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.ivory,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

  Widget _buildFooter() {
    return FittedBox(
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

  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: AppColors.brassLight, size: 30),
        const SizedBox(height: 7),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.brassLight,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.ivory,
            fontSize: 10,
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

class _PlanCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? badge;
  final Color crownColor;
  final Gradient? background;
  final List<_PlanFeature> features;
  final String? price;
  final String footer;
  final bool isGreenPrice;
  final bool isLoading;
  final double glowValue;
  final VoidCallback? onTap;

  const _PlanCard({
    required this.title,
    required this.subtitle,
    this.badge,
    this.crownColor = AppColors.brassLight,
    this.background,
    required this.features,
    required this.footer,
    this.price,
    this.isGreenPrice = false,
    this.isLoading = false,
    this.glowValue = 0.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isGlowing = glowValue > 0;
    final glow = isGlowing ? 0.26 + (glowValue * 0.46) : 0.0;

    // Badge height so both cards align at the same top level
    const badgeOverlap = 14.0;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          margin: const EdgeInsets.only(top: badgeOverlap),
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
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
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isGlowing
                  ? Color.lerp(
                      AppColors.brassLight,
                      Colors.white,
                      glowValue * 0.42,
                    )!
                  : AppColors.brassLight,
              width: badge == null ? 1.35 : 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.38),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
              if (badge != null)
                BoxShadow(
                  color: AppColors.brass.withValues(alpha: 0.3),
                  blurRadius: 20,
                ),
              if (isGlowing)
                BoxShadow(
                  color: AppColors.brassLight.withValues(alpha: glow),
                  blurRadius: 22 + (glowValue * 18),
                  spreadRadius: 1.5 + (glowValue * 2.8),
                ),
              if (isGlowing)
                BoxShadow(
                  color: AppColors.chipGold.withValues(
                    alpha: 0.22 + (glowValue * 0.26),
                  ),
                  blurRadius: 36 + (glowValue * 22),
                  spreadRadius: -2,
                ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                color: crownColor,
                size: 24,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'RehnCondensed',
                  color: badge == null ? AppColors.ivory : AppColors.brassLight,
                  fontSize: title.length > 8 ? 18 : 22,
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
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ivory,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 1,
                color: AppColors.brassLight.withValues(alpha: 0.26),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    for (var index = 0; index < features.length; index++) ...[
                      _FeatureRow(feature: features[index]),
                      if (index != features.length - 1)
                        const SizedBox(height: 7),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (price != null) ...[
                _PriceButton(
                  price: price!,
                  isGreen: isGreenPrice,
                  isLoading: isLoading,
                  onTap: onTap,
                ),
                const SizedBox(height: 8),
              ],
              _PlanFooter(label: footer),
            ],
          ),
        ),
        if (badge != null)
          Positioned(
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.ink.withValues(alpha: 0.28),
                ),
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
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 10,
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

class _FeatureRow extends StatelessWidget {
  final _PlanFeature feature;

  const _FeatureRow({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(feature.icon, color: AppColors.brassLight, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            feature.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.ivory,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _PriceButton extends StatelessWidget {
  final String price;
  final bool isGreen;
  final bool isLoading;
  final VoidCallback? onTap;

  const _PriceButton({
    required this.price,
    required this.isGreen,
    required this.isLoading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          backgroundColor: isGreen ? AppColors.feltLight : AppColors.brass,
          foregroundColor: isGreen ? AppColors.ivory : AppColors.ink,
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: AppColors.ivory.withValues(alpha: 0.56),
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
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isGreen ? AppColors.ivory : AppColors.ink,
                  ),
                ),
              )
            : FittedBox(
                child: Text(
                  price,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
      ),
    );
  }
}

class _PlanFooter extends StatelessWidget {
  final String label;

  const _PlanFooter({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.brassLight.withValues(alpha: 0.2)),
      ),
      child: FittedBox(
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontFamily: 'RehnCondensed',
            color: AppColors.brassLight,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            height: 1,
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
