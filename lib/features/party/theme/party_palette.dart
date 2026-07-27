import 'package:flutter/material.dart';

abstract final class PartyPalette {
  static const night = Color(0xFF09131E);
  static const nightDeep = Color(0xFF050C13);
  static const midnight = Color(0xFF102335);
  static const surface = Color(0xFF152B3D);
  static const surfaceRaised = Color(0xFF1C3547);
  static const surfaceWarm = Color(0xFF2C3540);

  static const orange = Color(0xFFE58A4C);
  static const orangeSoft = Color(0xFFF0AB78);
  static const terracotta = Color(0xFFB9674B);
  static const plum = Color(0xFF68404D);
  static const sage = Color(0xFF52736F);
  static const cream = Color(0xFFF4E8D6);
  static const creamMuted = Color(0xFFC9BEAE);
  static const blueMuted = Color(0xFF8EA3B2);

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [midnight, night, nightDeep],
    stops: [0, 0.55, 1],
  );
}
