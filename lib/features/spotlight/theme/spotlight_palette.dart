import 'package:flutter/material.dart';

/// A modern party palette scoped to the Spotlight prototype.
///
/// Keeping these colors out of [AppColors] is intentional: the classic game
/// keeps its casino identity until the new direction has been play-tested.
class SpotlightPalette {
  SpotlightPalette._();

  static const ink = Color(0xFF10111A);
  static const inkSoft = Color(0xFF171927);
  static const panel = Color(0xFF202235);
  static const panelRaised = Color(0xFF292C43);

  static const cream = Color(0xFFFFF6EA);
  static const textSoft = Color(0xFFC7C5D3);
  static const textMuted = Color(0xFF8D8B9D);

  static const violet = Color(0xFF9B7BFF);
  static const violetDeep = Color(0xFF6F4BDF);
  static const coral = Color(0xFFFF6F61);
  static const mint = Color(0xFF70E1C1);
  static const lemon = Color(0xFFFFD66B);

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF171423), ink, Color(0xFF101822)],
  );

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, Color(0xFFFF6F91)],
  );

  static BoxDecoration panelDecoration({
    Color color = panel,
    double radius = 24,
    Color? accent,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: (accent ?? cream).withValues(alpha: accent == null ? 0.09 : 0.5),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.24),
          blurRadius: 28,
          offset: const Offset(0, 16),
          spreadRadius: -12,
        ),
      ],
    );
  }
}
