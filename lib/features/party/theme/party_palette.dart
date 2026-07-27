import 'package:flutter/material.dart';

/// Warm, modern house-party palette.
///
/// These colors stay rich enough for the existing chip contrast without
/// reading as a casino table or a generic dark-mode application.
abstract final class PartyPalette {
  static const night = Color(0xFF24344B);
  static const nightDeep = Color(0xFF182437);
  static const midnight = Color(0xFF314863);
  static const surface = Color(0xFF3B526A);
  static const surfaceRaised = Color(0xFF4A6277);
  static const surfaceWarm = Color(0xFF665454);

  static const orange = Color(0xFFF0A061);
  static const orangeSoft = Color(0xFFFFC58F);
  static const terracotta = Color(0xFFD77C65);
  static const plum = Color(0xFF80677D);
  static const sage = Color(0xFF739993);
  static const cream = Color(0xFFFFF3E2);
  static const creamMuted = Color(0xFFE0D2BF);
  static const blueMuted = Color(0xFFB9C8D1);

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3A506A), night, Color(0xFF302F43)],
    stops: [0, 0.56, 1],
  );
}
