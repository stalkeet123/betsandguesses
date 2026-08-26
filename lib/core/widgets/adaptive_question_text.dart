import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Renders a complete gameplay question at the largest paint-safe font size.
///
/// Measurement and rendering intentionally share the same typography contract.
/// The small inner safety inset keeps RehnCondensed glyph overhang away from the
/// physical card edge even when the paragraph metrics themselves exactly fit.
class AdaptiveQuestionText extends StatelessWidget {
  static const double defaultAbsoluteMinFontSize = 8;
  static const double _horizontalPaintInset = 3;
  static const double _minimumVerticalPaintSafety = 6;
  static const double _verticalPaintSafetyFactor = 0.10;
  static const double _lineHeight = 1.08;
  static const int _searchIterations = 12;
  static const double _verificationStep = 0.25;

  final String text;
  final Color color;
  final double maxFontSize;
  final double preferredMinFontSize;
  final double absoluteMinFontSize;
  final Key? textKey;
  final Key? safeAreaKey;

  const AdaptiveQuestionText({
    super.key,
    required this.text,
    required this.color,
    required this.maxFontSize,
    this.preferredMinFontSize = 16,
    this.absoluteMinFontSize = defaultAbsoluteMinFontSize,
    this.textKey,
    this.safeAreaKey,
  }) : assert(maxFontSize > 0),
       assert(preferredMinFontSize > 0),
       assert(absoluteMinFontSize > 0),
       assert(absoluteMinFontSize <= maxFontSize);

  TextStyle _style(double fontSize) => TextStyle(
    fontFamily: 'RehnCondensed',
    color: color,
    fontSize: fontSize,
    fontWeight: FontWeight.w900,
    height: _lineHeight,
    letterSpacing: 0,
  );

  StrutStyle _strut(double fontSize) => StrutStyle(
    fontFamily: 'RehnCondensed',
    fontSize: fontSize,
    fontWeight: FontWeight.w900,
    forceStrutHeight: true,
    height: _lineHeight,
  );

  double _verticalPaintSafety(double fontSize) => math.max(
    _minimumVerticalPaintSafety,
    fontSize * _verticalPaintSafetyFactor,
  );

  TextPainter _layout(double fontSize, double safeWidth) => TextPainter(
    text: TextSpan(text: text, style: _style(fontSize)),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
    strutStyle: _strut(fontSize),
    maxLines: null,
    textWidthBasis: TextWidthBasis.parent,
  )..layout(maxWidth: safeWidth);

  bool _fits({
    required double fontSize,
    required double maxWidth,
    required double maxHeight,
  }) {
    final safeWidth = maxWidth - (_horizontalPaintInset * 2);
    final safeHeight = maxHeight - _verticalPaintSafety(fontSize);
    if (safeWidth <= 0 || safeHeight <= 0) return false;

    final painter = _layout(fontSize, safeWidth);
    return !painter.didExceedMaxLines &&
        painter.width <= safeWidth + 0.01 &&
        painter.height <= safeHeight + 0.01;
  }

  double _largestFittingFontSize({
    required double maxWidth,
    required double maxHeight,
  }) {
    final preferred = preferredMinFontSize
        .clamp(absoluteMinFontSize, maxFontSize)
        .toDouble();
    final preferredFits = _fits(
      fontSize: preferred,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    var low = preferredFits ? preferred : absoluteMinFontSize;
    var high = preferredFits ? maxFontSize : preferred;

    for (var i = 0; i < _searchIterations; i++) {
      final candidate = (low + high) / 2;
      if (_fits(
        fontSize: candidate,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      )) {
        low = candidate;
      } else {
        high = candidate;
      }
    }

    var verified = low.clamp(absoluteMinFontSize, maxFontSize).toDouble();
    while (verified > absoluteMinFontSize &&
        !_fits(fontSize: verified, maxWidth: maxWidth, maxHeight: maxHeight)) {
      verified = math.max(absoluteMinFontSize, verified - _verificationStep);
    }
    return verified;
  }

  Text _textWidget(double fontSize, {Key? key}) => Text(
    text,
    key: key,
    textAlign: TextAlign.center,
    softWrap: true,
    maxLines: null,
    overflow: TextOverflow.visible,
    textScaler: TextScaler.noScaling,
    strutStyle: _strut(fontSize),
    textWidthBasis: TextWidthBasis.parent,
    style: _style(fontSize),
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
          return const SizedBox.shrink();
        }

        final absoluteMinimumFits = _fits(
          fontSize: absoluteMinFontSize,
          maxWidth: width,
          maxHeight: height,
        );
        final fontSize = absoluteMinimumFits
            ? _largestFittingFontSize(maxWidth: width, maxHeight: height)
            : absoluteMinFontSize;
        final verticalInset = _verticalPaintSafety(fontSize) / 2;

        final safeArea = Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _horizontalPaintInset,
            vertical: verticalInset,
          ),
          child: SizedBox.expand(
            key: safeAreaKey,
            child: Center(
              child: absoluteMinimumFits
                  ? _textWidget(fontSize, key: textKey)
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: math.max(
                          0.1,
                          width - (_horizontalPaintInset * 2),
                        ),
                        child: _textWidget(fontSize, key: textKey),
                      ),
                    ),
            ),
          ),
        );

        return ClipRect(child: safeArea);
      },
    );
  }
}
