import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/features/spotlight/screens/debug_spotlight_prototype_screen.dart';

void main() {
  Future<void> pumpPrototype(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: DebugSpotlightPrototypeScreen()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('walks through the complete prototype flow', (tester) async {
    await pumpPrototype(tester);

    expect(find.text("Maya's turn"), findsOneWidget);
    expect(
      find.byKey(const ValueKey('spotlight-secret-answer')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    Future<void> next() async {
      await tester.tap(find.byKey(const ValueKey('spotlight-next-stage')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await next();
    expect(find.text('How well do you know her?'), findsOneWidget);

    await next();
    expect(find.text('Who knows you best?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('trust-pick-1')));
    await tester.pumpAndSettle();

    await next();
    expect(find.text('Back the best guess'), findsOneWidget);

    await next();
    expect(find.text('83'), findsOneWidget);
    expect(find.text('Maya trusted Jordan — nailed it! +3'), findsOneWidget);
  });
}
