import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/features/game/screens/debug_scene_editor_screen.dart';

void main() {
  Future<void> pumpEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(const MaterialApp(home: DebugSceneEditorScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('question editor safely cancels and applies', (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.byTooltip('Question'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Question'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'How many unread messages are on Alex\'s phone?',
    );
    await tester.tap(find.text('APPLY'));
    await tester.pumpAndSettle();

    expect(
      find.text('How many unread messages are on Alex\'s phone?'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('bet boundaries update every board range', (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.byTooltip('Bet ranges'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(4));
    for (final entry in const [10, 20, 40, 80].indexed) {
      await tester.enterText(fields.at(entry.$1), '${entry.$2}');
    }
    await tester.tap(find.text('APPLY'));
    await tester.pumpAndSettle();

    expect(find.text('BETWEEN\n40 & 80\n(INCLUSIVE)'), findsOneWidget);
    expect(find.text('BETWEEN\n10 & 20\n(INCLUSIVE)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chip editor handles the keyboard and safely adds a chip', (
    tester,
  ) async {
    await pumpEditor(tester);
    tester.view.physicalSize = const Size(800, 400);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add chip'));
    await tester.pumpAndSettle();
    expect(find.text('ADD CHIP'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('chip-value-field')),
      '250',
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('APPLY'));
    await tester.tap(find.text('APPLY'));
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();

    expect(find.text('250'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
