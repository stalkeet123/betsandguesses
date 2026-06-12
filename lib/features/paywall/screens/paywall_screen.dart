import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/revenuecat_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_asset_image.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  Map<String, String> _packagePrices = const {};
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
      _loadRevenueCat();
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _loadRevenueCat() async {
    final service = ref.read(revenueCatServiceProvider);

    try {
      await service.initialize();
      final prices = await service.packagePrices();
      final isPremium = await service.isPremium();

      if (!mounted) return;
      setState(() {
        _packagePrices = prices;
        _isPremium = isPremium;
      });
    } catch (error) {
      if (!mounted) return;
      _showSnack('Could not load purchases: $error');
    }
  }

  Future<void> _purchase(String packageIdentifier) async {
    if (_busyPackageIdentifier != null || _isRestoring) return;

    setState(() => _busyPackageIdentifier = packageIdentifier);

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
      _showSnack('Premium unlocked.');
    } else {
      _showSnack(result.message ?? 'Purchase failed.');
    }
  }

  Future<void> _restorePurchases() async {
    if (_busyPackageIdentifier != null || _isRestoring) return;

    setState(() => _isRestoring = true);

    final service = ref.read(revenueCatServiceProvider);
    final result = await service.restorePurchases();
    ref.invalidate(premiumStatusProvider);

    if (!mounted) return;
    setState(() {
      _isRestoring = false;
      _isPremium = result.isPremium;
    });

    if (result.success) {
      _showSnack('Purchases restored.');
    } else {
      _showSnack(result.message ?? 'No active purchase found.');
    }
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
                    .clamp(760.0, 900.0)
                    .toDouble();
                final horizontalPadding = contentWidth < 380 ? 10.0 : 16.0;

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
                          12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTopBar(context),
                            const SizedBox(height: 2),
                            const SizedBox(
                              height: 132,
                              child: CachedAssetImage(
                                AppAssetPaths.logo,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildTitle(),
                            const SizedBox(height: 7),
                            _buildCurrentPlanStrip(),
                            const SizedBox(height: 10),
                            _buildBenefitStrip(),
                            const SizedBox(height: 14),
                            Expanded(child: _buildPlans(context)),
                            const SizedBox(height: 12),
                            _buildBottomBanner(),
                            const SizedBox(height: 11),
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
          width: 42,
          height: 42,
          child: IconButton(
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.goNamed('home');
              }
            },
            icon: const Icon(Icons.close_rounded, size: 28),
            color: AppColors.ivory,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.feltDark.withValues(alpha: 0.84),
              side: const BorderSide(color: AppColors.brassLight, width: 1.5),
              shape: const CircleBorder(),
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildTitle() {
    return const Text(
      'UNLOCK THE ULTIMATE PARTY EXPERIENCE',
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'RehnCondensed',
        color: AppColors.ivory,
        fontSize: 21,
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
      height: 86,
      decoration: _darkPanel(radius: 18),
      child: Row(
        children: [
          Expanded(
            child: _BenefitItem(
              icon: Icons.groups_rounded,
              title: 'BIGGER LOBBIES',
              subtitle: 'Up to 10 players',
            ),
          ),
          _verticalRule(),
          Expanded(
            child: _BenefitItem(
              icon: Icons.all_inclusive_rounded,
              title: 'UNLIMITED GAMES',
              subtitle: 'No daily limits',
            ),
          ),
          _verticalRule(),
          Expanded(
            child: _BenefitItem(
              icon: Icons.block_rounded,
              title: 'NO ADS',
              subtitle: 'Pure fun',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanStrip() {
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
          _isPremium ? 'PREMIUM ACTIVE' : 'CURRENT PLAN: FREE',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _isPremium
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

  Widget _buildPlans(BuildContext context) {
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
              _PlanFeature(Icons.groups_2_rounded, 'Unlimited lobbies'),
              _PlanFeature(Icons.groups_rounded, 'Up to 10 players'),
              _PlanFeature(Icons.alarm_rounded, '8-12 rounds'),
              _PlanFeature(Icons.block_rounded, 'No ads'),
              _PlanFeature(Icons.event_repeat_rounded, 'No auto renewal'),
              _PlanFeature(Icons.layers_rounded, 'All question packs'),
              _PlanFeature(Icons.star_rounded, 'Premium themes'),
            ],
            price: '₺59,99',
            displayPrice:
                _packagePrices[RevenueCatConstants.dailyPassPackageIdentifier],
            footer: '24 HOURS ACCESS',
            isLoading:
                _busyPackageIdentifier ==
                RevenueCatConstants.dailyPassPackageIdentifier,
            onTap: _isPremium
                ? null
                : () =>
                      _purchase(RevenueCatConstants.dailyPassPackageIdentifier),
          ),
          _PlanCard(
            title: 'FULL ACCESS',
            subtitle: 'One-time purchase',
            crownColor: AppColors.neonGreen,
            features: const [
              _PlanFeature(Icons.all_inclusive_rounded, 'Unlimited everything'),
              _PlanFeature(Icons.groups_rounded, 'Up to 10 players'),
              _PlanFeature(Icons.alarm_add_rounded, 'Custom rounds'),
              _PlanFeature(Icons.block_rounded, 'No ads'),
              _PlanFeature(Icons.layers_rounded, 'All question packs'),
              _PlanFeature(Icons.auto_awesome_rounded, 'Premium themes'),
              _PlanFeature(Icons.edit_rounded, 'Create questions'),
            ],
            price: '₺199,99',
            displayPrice:
                _packagePrices[RevenueCatConstants.lifetimePackageIdentifier],
            footer: 'LIFETIME ACCESS',
            isGreenPrice: true,
            isLoading:
                _busyPackageIdentifier ==
                RevenueCatConstants.lifetimePackageIdentifier,
            onTap: _isPremium
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
              if (index != cards.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _buildBottomBanner() {
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _darkPanel(radius: 18).copyWith(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF17100F), Color(0xFF071C13), Color(0xFF101010)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 50,
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
              size: 40,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'MORE FUN. MORE QUESTIONS.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.brassLight,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Perfect for game nights, parties & events!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.ivory,
                    fontSize: 13,
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
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showSnack('Could not open link: $urlString');
      }
    } catch (e) {
      _showSnack('Error opening link: $e');
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
            onTap: () => _launchURL('https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'),
          ),
          const SizedBox(width: 20),
          _FooterChip(
            icon: Icons.privacy_tip_rounded,
            label: 'PRIVACY POLICY',
            onTap: () => _launchURL('https://stalkeet123.github.io/betsandguesses/privacy.html'),
          ),
        ],
      ),
    );
  }

  Widget _verticalRule() {
    return Container(
      width: 1,
      height: 58,
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
  final String? displayPrice;
  final String footer;
  final bool isGreenPrice;
  final bool isLoading;
  final double glowValue;
  final VoidCallback? onTap;

  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.features,
    required this.footer,
    this.badge,
    this.crownColor = AppColors.brassLight,
    this.background,
    this.price,
    this.displayPrice,
    this.isGreenPrice = false,
    this.isLoading = false,
    this.glowValue = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isGlowing = glowValue > 0;
    final glow = isGlowing ? 0.26 + (glowValue * 0.46) : 0.0;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          margin: EdgeInsets.only(top: badge == null ? 14 : 24),
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
                size: 34,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'RehnCondensed',
                  color: badge == null ? AppColors.ivory : AppColors.brassLight,
                  fontSize: title.length > 8 ? 22 : 27,
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
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ivory,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 1,
                color: AppColors.brassLight.withValues(alpha: 0.26),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Column(
                  children: [
                    for (var index = 0; index < features.length; index++) ...[
                      _FeatureRow(feature: features[index]),
                      if (index != features.length - 1)
                        const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
              if (price != null) ...[
                _PriceButton(
                  price: displayPrice ?? price!,
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
                  fontSize: 12,
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
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            feature.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.ivory,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.1,
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
      height: 42,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: isGreen ? AppColors.feltLight : AppColors.brass,
          foregroundColor: isGreen ? AppColors.ivory : AppColors.ink,
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
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
                  style: const TextStyle(fontFamily: 'RehnCondensed'),
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
      height: 36,
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
            fontSize: 12,
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
