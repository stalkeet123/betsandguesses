import 'dart:math';
import 'package:flutter/material.dart';

class PokerChip extends StatelessWidget {
  final String label;
  final Color color;
  final double size;
  final bool isScoreChip;

  const PokerChip({
    super.key,
    required this.label,
    required this.color,
    this.size = 34,
    this.isScoreChip = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = isScoreChip ? const Color(0xFF3B2609) : Colors.white;

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: size * 0.18,
              offset: Offset(0, size * 0.12),
            ),
            BoxShadow(
              color: color.withValues(alpha: 0.34),
              blurRadius: size * 0.24,
              spreadRadius: size * 0.02,
            ),
          ],
        ),
        child: CustomPaint(
          painter: _PokerChipPainter(color: color, isScoreChip: isScoreChip),
          child: Center(
            child: Container(
              width: size * 0.48,
              height: size * 0.48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isScoreChip
                    ? const Color(0xFFFFE8A6).withValues(alpha: 0.9)
                    : color.darken(0.18).withValues(alpha: 0.78),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isScoreChip ? 0.46 : 0.24),
                  width: max(1, size * 0.035),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: EdgeInsets.all(size * 0.07),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: labelColor,
                      fontWeight: FontWeight.w900,
                      fontSize: size * 0.28,
                      height: 1,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: isScoreChip ? 0.08 : 0.7),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PokerChipPainter extends CustomPainter {
  final Color color;
  final bool isScoreChip;

  const _PokerChipPainter({
    required this.color,
    required this.isScoreChip,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final base = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.38, -0.42),
        radius: 1.05,
        colors: isScoreChip
            ? const [
                Color(0xFFFFF4B8),
                Color(0xFFFFC84D),
                Color(0xFF9B641A),
              ]
            : [
                color.lighten(0.22),
                color,
                color.darken(0.46),
              ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, base);

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.19
      ..color = Colors.white.withValues(alpha: isScoreChip ? 0.78 : 0.86);

    const stripeCount = 8;
    for (var i = 0; i < stripeCount; i++) {
      final angle = (2 * pi / stripeCount) * i;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.82),
        angle - pi / 13,
        pi / 6.5,
        false,
        rim,
      );
    }

    final outerGroove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, radius * 0.04)
      ..color = Colors.black.withValues(alpha: 0.28);
    canvas.drawCircle(center, radius * 0.91, outerGroove);
    canvas.drawCircle(center, radius * 0.62, outerGroove);

    final highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, radius * 0.045)
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.6),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.88),
      3.72,
      1.35,
      false,
      highlight,
    );
  }

  @override
  bool shouldRepaint(covariant _PokerChipPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isScoreChip != isScoreChip;
  }
}

extension ColorUtils on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final f = 1 - amount;
    return Color.from(alpha: a, red: r * f, green: g * f, blue: b * f);
  }

  Color lighten([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    return Color.from(
      alpha: a,
      red: r + (1 - r) * amount,
      green: g + (1 - g) * amount,
      blue: b + (1 - b) * amount,
    );
  }
}
