import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/features/party/widgets/party_poll_production_view.dart';

void main() {
  const question = 'Who would make the most reality-tv contestant?';

  testWidgets(
    'long poll question uses its measured line height on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
                  score: 0,
                ),
                PartyPollViewPlayer(
                  id: 'bb',
                  slotIndex: 1,
                  name: 'BB',
                  score: 0,
                ),
                PartyPollViewPlayer(
                  id: 'evil',
                  slotIndex: 2,
                  name: 'Evil',
                  score: 0,
                ),
              ],
              bets: const [],
              winningPlayerIds: const {},
              score: 0,
              betTotal: 0,
              betLimit: 40,
              availableChips: 40,
              selectedChipValue: null,
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
}
