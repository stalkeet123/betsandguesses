import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/features/party/widgets/party_poll_production_view.dart';

void main() {
  const question = 'Who would make the most reality-tv contestant?';

  Future<void> pumpPartyView(
    WidgetTester tester, {
    required Size size,
    int? selectedChipValue,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PartyPollProductionView(
            roundNumber: 2,
            maxRounds: 6,
            remaining: const Duration(seconds: 25),
            isReveal: false,
            questionText: question,
            players: const [
              PartyPollViewPlayer(
                id: 'emirl',
                slotIndex: 0,
                name: 'Emirl',
                score: 40,
              ),
              PartyPollViewPlayer(
                id: 'bb',
                slotIndex: 1,
                name: 'BB',
                score: -30,
              ),
              PartyPollViewPlayer(
                id: 'evil',
                slotIndex: 2,
                name: 'Evil',
                score: -40,
              ),
            ],
            bets: const [],
            winningPlayerIds: const {},
            score: 40,
            betTotal: 0,
            betLimit: 40,
            availableChips: 40,
            selectedChipValue: selectedChipValue,
            currentPlayerId: 'emirl',
            selectedBetId: null,
            emphasizeWinners: false,
            activeRevealSlotIndex: null,
            onChipSelected: (_) {},
            onBetSelected: (_) {},
            onBetRequested: (_, _, _, _) {},
            onBetMoveRequested: (_, _, _, _, _) {},
            onBetRemoveRequested: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'long poll question uses its measured line height on a small phone',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpPartyView(tester, size: const Size(390, 844));

      expect(tester.takeException(), isNull);
      final questionText = tester.widget<Text>(find.text(question));
      final questionCard = tester.getRect(
        find.byKey(const ValueKey('party-question-2')),
      );
      final textRect = tester.getRect(find.text(question));

      expect(questionText.strutStyle?.fontSize, questionText.style?.fontSize);
      expect(textRect.height, lessThan(questionCard.height));
    },
  );

  testWidgets('party left rail stays usable on narrow phones', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in const [Size(320, 568), Size(328, 690)]) {
      await pumpPartyView(tester, size: size, selectedChipValue: 5);

      expect(tester.takeException(), isNull, reason: 'viewport $size');
      expect(find.text('PLACE CHIP'), findsOneWidget);
      final questionCard = tester.getRect(
        find.byKey(const ValueKey('party-question-2')),
      );
      final leaderboard = tester.getRect(
        find.byKey(const ValueKey('party-leaderboard-2')),
      );
      expect(
        questionCard.height,
        greaterThan(leaderboard.height),
        reason: 'viewport $size',
      );
    }
  });
}
