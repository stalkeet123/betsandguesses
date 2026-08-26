import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/core/widgets/adaptive_question_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const failingQuestion =
      'Who would be most likely to turn up to the wrong event?';
  const longClassicQuestion =
      'What percentage of people would admit they changed their answer after hearing everyone else confidently disagree?';
  const phoneSizes = <Size>[
    Size(320, 568),
    Size(360, 640),
    Size(360, 800),
    Size(390, 844),
    Size(412, 915),
  ];

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

  Size classicBettingBodyFor(Size viewport) {
    final width = (((viewport.width - 8) / 2) - 48).clamp(96.0, 170.0);
    final height = (viewport.height * 0.14).clamp(72.0, 132.0);
    return Size(width, height);
  }

  Size classicGuessingBodyFor(Size viewport) => Size(
    (viewport.width - 76).clamp(220.0, 336.0),
    (viewport.height * 0.20).clamp(108.0, 176.0),
  );

  Future<Text> pumpClassicQuestion(
    WidgetTester tester, {
    required Size viewport,
    required Size body,
    required String text,
    required double maxFontSize,
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Container(
              key: const ValueKey('classic-question-body'),
              width: body.width,
              height: body.height,
              color: const Color(0xFFFFFBF1),
              child: AdaptiveQuestionText(
                text: text,
                color: const Color(0xFF123326),
                preferredMinFontSize: 20,
                maxFontSize: maxFontSize,
                safeAreaKey: const ValueKey('classic-question-safe-area'),
                textKey: const ValueKey('classic-question-text'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return tester.widget<Text>(
      find.byKey(const ValueKey('classic-question-text')),
    );
  }

  void expectCompleteClassicQuestion(WidgetTester tester, Text rendered) {
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(rendered.style?.fontFamily, 'RehnCondensed');
    expect(rendered.maxLines, isNull);
    expect(rendered.softWrap, isTrue);
    expect(rendered.overflow, TextOverflow.visible);

    final safeArea = tester.getRect(
      find.byKey(const ValueKey('classic-question-safe-area')),
    );
    final textRect = tester.getRect(
      find.byKey(const ValueKey('classic-question-text')),
    );
    final body = tester.getRect(
      find.byKey(const ValueKey('classic-question-body')),
    );
    expect(textRect.left, greaterThanOrEqualTo(safeArea.left));
    expect(textRect.right, lessThanOrEqualTo(safeArea.right + 0.01));
    expect(textRect.top, greaterThanOrEqualTo(safeArea.top));
    expect(textRect.bottom, lessThanOrEqualTo(safeArea.bottom + 0.01));
    expect(textRect.top, greaterThan(body.top));
    expect(textRect.bottom, lessThan(body.bottom));
    expect(tester.takeException(), isNull);
  }

  testWidgets('Classic betting constraints show the complete question', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final viewport in phoneSizes) {
      final rendered = await pumpClassicQuestion(
        tester,
        viewport: viewport,
        body: classicBettingBodyFor(viewport),
        text: failingQuestion,
        maxFontSize: 34,
      );
      expect(find.text(failingQuestion), findsOneWidget);
      expect(rendered.style?.fontSize, lessThanOrEqualTo(34));
      expectCompleteClassicQuestion(tester, rendered);
    }
  });

  testWidgets('Classic guessing constraints show a long complete question', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final viewport in phoneSizes) {
      final rendered = await pumpClassicQuestion(
        tester,
        viewport: viewport,
        body: classicGuessingBodyFor(viewport),
        text: longClassicQuestion,
        maxFontSize: 46,
      );
      expect(find.text(longClassicQuestion), findsOneWidget);
      expect(rendered.style?.fontSize, lessThanOrEqualTo(46));
      expectCompleteClassicQuestion(tester, rendered);
    }
  });

  test('Classic production question call sites use the shared fitter', () {
    final source = File(
      'lib/features/game/screens/game_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('class _AdaptiveQuestionText')));
    expect(source, isNot(contains('_AdaptiveQuestionText(')));
    expect(source, contains('classic-betting-question-fitter'));
    expect(source, contains('classic-guessing-question-fitter'));
    expect(source, contains('AdaptiveQuestionText('));

    final sharedSource = File(
      'lib/core/widgets/adaptive_question_text.dart',
    ).readAsStringSync();
    expect(sharedSource, isNot(contains('SingleChildScrollView')));
    expect(sharedSource, isNot(contains('TextOverflow.ellipsis')));
  });
}
