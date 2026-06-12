import 'dart:math';

/// Helper utilities for Tahmin.io
class Helpers {
  Helpers._();

  /// Generate a random room code (6 uppercase letters)
  static String generateRoomCode({int length = 6}) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I, O, 0, 1
    final rng = Random.secure();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  /// Format large numbers with dots (Turkish style)
  static String formatNumber(int number) {
    final str = number.abs().toString();
    final result = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        result.write('.');
      }
      result.write(str[i]);
    }
    return number < 0 ? '-${result.toString()}' : result.toString();
  }

  /// Color from hex string
  static int colorFromHex(String hex) {
    return int.parse(hex.replaceFirst('#', 'FF'), radix: 16);
  }
}
