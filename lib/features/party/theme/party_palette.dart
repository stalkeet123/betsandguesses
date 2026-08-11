import 'package:flutter/material.dart';

/// A social extension of the Classic felt-and-brass world.
///
/// Party stays warmer and looser in its accents, but the green base keeps it
/// unmistakably part of Bets & Guesses rather than a separate dark-mode app.
abstract final class PartyPalette {
  static const night = Color(0xFF153A31);
  static const nightDeep = Color(0xFF08251F);
  static const midnight = Color(0xFF1E4B3E);
  static const surface = Color(0xFF235746);
  static const surfaceRaised = Color(0xFF2D6751);
  static const surfaceWarm = Color(0xFF5A453A);

  static const orange = Color(0xFFD9784B);
  static const orangeSoft = Color(0xFFF2B67C);
  static const terracotta = Color(0xFFB96049);
  static const plum = Color(0xFF795C6B);
  static const sage = Color(0xFF85AA77);
  static const cream = Color(0xFFFFF5E5);
  static const creamMuted = Color(0xFFDECDB4);
  static const blueMuted = Color(0xFFB7CDBD);

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2D5C47), night, Color(0xFF102D28)],
    stops: [0, 0.56, 1],
  );
}
