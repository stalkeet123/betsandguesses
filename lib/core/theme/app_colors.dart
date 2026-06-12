import 'package:flutter/material.dart';

/// Casino table palette for Tahmin.io.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF120F0B);
  static const Color surface = Color(0xFF241A12);
  static const Color surfaceLight = Color(0xFF3B2A1C);
  static const Color surfaceCard = Color(0xFF172A21);

  static const Color felt = Color(0xFF0F5132);
  static const Color feltDark = Color(0xFF073522);
  static const Color feltLight = Color(0xFF1F7A4E);
  static const Color mahogany = Color(0xFF4B1F14);
  static const Color mahoganyDark = Color(0xFF1B0B08);
  static const Color brass = Color(0xFFD7A84A);
  static const Color brassLight = Color(0xFFFFD77A);
  static const Color ivory = Color(0xFFF7E6C2);
  static const Color burgundy = Color(0xFF7B2636);
  static const Color ink = Color(0xFF130E0B);

  static const Color neonPurple = Color(0xFF9B6CFF);
  static const Color neonPink = Color(0xFFD94B74);
  static const Color neonCyan = Color(0xFF47C7C0);
  static const Color neonGreen = Color(0xFF61D394);
  static const Color neonRed = Color(0xFFFF6B5F);
  static const Color neonYellow = brassLight;
  static const Color neonOrange = Color(0xFFE58B37);
  static const Color neonBlue = Color(0xFF5B8DEF);

  static const Color primary = brass;
  static const Color secondary = burgundy;
  static const Color success = neonGreen;
  static const Color error = neonRed;
  static const Color warning = brassLight;
  static const Color info = neonCyan;

  static const Color textPrimary = ivory;
  static const Color textSecondary = Color(0xFFD2C0A3);
  static const Color textMuted = Color(0xFF927D61);

  static const Color chipGold = Color(0xFFFFC84D);
  static const Color chipSilver = Color(0xFFCFD4DA);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [brassLight, brass, Color(0xFF8C5C18)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [burgundy, Color(0xFFB94A55)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFE29A), chipGold, Color(0xFF9A621B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient boardGradient = LinearGradient(
    colors: [feltLight, felt, feltDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const Gradient tableGradient = RadialGradient(
    center: Alignment.topCenter,
    radius: 1.25,
    colors: [feltLight, felt, feltDark],
  );

  static Color getOddsColor(int odds) {
    switch (odds) {
      case 2:
        return brassLight;
      case 3:
        return neonCyan;
      case 4:
        return neonOrange;
      case 5:
        return burgundy;
      default:
        return brass;
    }
  }

  static BoxDecoration tableDecoration({double borderRadius = 28}) {
    return BoxDecoration(
      gradient: tableGradient,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: brass.withValues(alpha: 0.55), width: 2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.58),
          blurRadius: 34,
          offset: const Offset(0, 18),
        ),
        BoxShadow(
          color: feltLight.withValues(alpha: 0.14),
          blurRadius: 24,
          spreadRadius: -8,
        ),
      ],
    );
  }

  static BoxDecoration leatherPanel({double borderRadius = 16}) {
    return BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF3A2115), Color(0xFF1A0E09)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: brass.withValues(alpha: 0.28)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.32),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static BoxDecoration cardFelt({double borderRadius = 14, Color? color}) {
    return BoxDecoration(
      color: (color ?? feltDark).withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
    );
  }

  static BoxDecoration glassDecoration({
    Color? color,
    double borderRadius = 16,
    double opacity = 0.1,
  }) {
    return BoxDecoration(
      color: (color ?? ivory).withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: brass.withValues(alpha: 0.18), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.28),
          blurRadius: 20,
          spreadRadius: -6,
        ),
      ],
    );
  }

  static BoxDecoration neonGlowDecoration({
    required Color color,
    double borderRadius = 16,
    double glowIntensity = 0.3,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: color.withValues(alpha: 0.62), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: glowIntensity),
          blurRadius: 22,
          spreadRadius: -2,
        ),
      ],
    );
  }
}
