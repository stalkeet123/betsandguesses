import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

class WebPromoBanner extends StatelessWidget {
  const WebPromoBanner({super.key});

  Future<void> _launchStore() async {
    final url = Uri.parse('https://stalkeet.com'); // Placeholder for store URL
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _launchStore,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2C2C2C), Color(0xFF141414)],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: AppColors.brassLight.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.apple,
                color: AppColors.brassLight,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'DOWNLOAD ON APP STORE',
                style: GoogleFonts.outfit(
                  color: AppColors.ivory,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
