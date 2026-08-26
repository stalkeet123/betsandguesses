import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/core/widgets/adaptive_question_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const failingQuestion =
      'Who would be most likely to turn up to the wrong event?';
  const longQuestion =
      'Who would be most likely to become friends with a complete stranger in five minutes and still remember every detail of the story?';
  const shortQuestion = 'Who is most likely to win?';

  setUpAll(() async {
    final bytes = File(
      'assets/Rehn Condensed W03 ExtraBold.ttf',
    ).readAsBytesSync();
    final data = ByteData.view(
      bytes.buffer,
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    await (FontLoader('RehnCondensed')..addFont(Future.value(data))).load();
  });

  Future<Text> pumpQuestion(
    WidgetTester tester, {
    required String text,
    required Size size,
    double maxFontSize = 34,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: const ValueKey('question-paint-boundary'),
              child: ColoredBox(
                color: Colors.white,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: AdaptiveQuestionText(
                    key: const ValueKey('question-fitter'),
                    text: text,
                    color: Colors.black,
                    maxFontSize: maxFontSize,
                    preferredMinFontSize: 20,
                    safeAreaKey: const ValueKey('question-safe-area'),
                    textKey: const ValueKey('question-text'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return tester.widget<Text>(find.byKey(const ValueKey('question-text')));
  }

  testWidgets('uses one complete naturally wrapped paint-safe paragraph', (
    tester,
  ) async {
    final rendered = await pumpQuestion(
      tester,
      text: failingQuestion,
      size: const Size(108, 76),
    );

    expect(find.text(failingQuestion), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(rendered.style?.fontFamily, 'RehnCondensed');
    expect(rendered.style?.fontWeight, FontWeight.w900);
    expect(rendered.textAlign, TextAlign.center);
    expect(rendered.softWrap, isTrue);
    expect(rendered.maxLines, isNull);
    expect(rendered.overflow, TextOverflow.visible);
    expect(rendered.style?.fontSize, lessThanOrEqualTo(34));

    final safeArea = tester.getRect(
      find.byKey(const ValueKey('question-safe-area')),
    );
    final paragraph = tester.getRect(
      find.byKey(const ValueKey('question-text')),
    );
    final fitter = tester.getRect(
      find.byKey(const ValueKey('question-fitter')),
    );
    expect(paragraph.left, greaterThanOrEqualTo(safeArea.left));
    expect(paragraph.right, lessThanOrEqualTo(safeArea.right + 0.01));
    expect(paragraph.top, greaterThanOrEqualTo(safeArea.top));
    expect(paragraph.bottom, lessThanOrEqualTo(safeArea.bottom + 0.01));
    expect(paragraph.top, greaterThan(fitter.top));
    expect(paragraph.bottom, lessThan(fitter.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('chooses a larger safe font for a shorter question', (
    tester,
  ) async {
    final shortText = await pumpQuestion(
      tester,
      text: shortQuestion,
      size: const Size(108, 76),
    );
    final shortSize = shortText.style!.fontSize!;

    final longText = await pumpQuestion(
      tester,
      text: longQuestion,
      size: const Size(108, 76),
    );
    final longSize = longText.style!.fontSize!;

    expect(shortSize, greaterThan(longSize));
    expect(shortSize, lessThanOrEqualTo(34));
    expect(longSize, greaterThanOrEqualTo(8));
  });

  testWidgets('keeps wrapped emergency fallback and never scrolls', (
    tester,
  ) async {
    final rendered = await pumpQuestion(
      tester,
      text: List.filled(12, longQuestion).join(' '),
      size: const Size(64, 24),
    );

    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byType(FittedBox), findsOneWidget);
    expect(rendered.softWrap, isTrue);
    expect(rendered.maxLines, isNull);
    expect(rendered.overflow, TextOverflow.visible);
    expect(tester.takeException(), isNull);
  });

  testWidgets('painted glyphs leave a clean outer boundary', (tester) async {
    await pumpQuestion(
      tester,
      text: failingQuestion,
      size: const Size(108, 76),
    );

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('question-paint-boundary')),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    addTearDown(image.dispose);
    expect(bytes, isNotNull);

    final pixels = bytes!.buffer.asUint8List();
    bool isWhite(int x, int y) {
      final offset = ((y * image.width) + x) * 4;
      return pixels[offset] >= 250 &&
          pixels[offset + 1] >= 250 &&
          pixels[offset + 2] >= 250 &&
          pixels[offset + 3] == 255;
    }

    final dirtyBoundaryPixels = <String>[];
    for (var x = 0; x < image.width; x++) {
      if (!isWhite(x, 0)) dirtyBoundaryPixels.add('top:$x');
      if (!isWhite(x, image.height - 1)) {
        dirtyBoundaryPixels.add('bottom:$x');
      }
    }
    for (var y = 0; y < image.height; y++) {
      if (!isWhite(0, y)) dirtyBoundaryPixels.add('left:$y');
      if (!isWhite(image.width - 1, y)) {
        dirtyBoundaryPixels.add('right:$y');
      }
    }
    expect(dirtyBoundaryPixels, isEmpty);
  });
}
