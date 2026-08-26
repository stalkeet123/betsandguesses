import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/features/game/widgets/poker_chip.dart';
import 'package:witsgame/features/party/constants/party_poll_rules.dart';
import 'package:witsgame/features/party/widgets/party_poll_production_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
  const longQuestion =
      'Who would be most likely to become friends with a complete stranger in five minutes?';
  const failingProductionQuestion =
      'Who would be most likely to turn up to the wrong event?';
  const shortQuestion = 'Who is most likely to win?';
  const stressQuestion =
      'Who would turn a quiet weekend into an unforgettable adventure, invite everyone along, and still somehow have a brilliant story by sunrise?';
  const longestProductionQuestions = <String>[
    failingProductionQuestion,
    'Who would be most likely to become a conspiracy theorist about something completely harmless?',
    'Who would be most likely to convince the group to change all the plans at the last minute?',
    'Who would be most likely to spend an hour choosing what to watch and then watch nothing?',
    'Who would make the best reality-show contestant?',
  ];
  const phoneSizes = <Size>[
    Size(320, 568),
    Size(360, 640),
    Size(360, 800),
    Size(390, 844),
    Size(412, 915),
  ];
  Future<void> pumpPartyView(
    WidgetTester tester, {
    required Size size,
    required bool isReveal,
    String question = longQuestion,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: PartyPollProductionView(
              roundNumber: 2,
              maxRounds: 6,
              remaining: const Duration(seconds: 25),
              isReveal: isReveal,
              questionText: question,
              players: const [
                PartyPollViewPlayer(
                  id: 'emirl',
                  slotIndex: 0,
                  name: 'Emirl With A Long Name',
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
              bets: isReveal
                  ? const [
                      PartyPollViewBet(
                        id: 'own-5',
                        bettorPlayerId: 'emirl',
                        targetPlayerId: 'bb',
                        targetSlotIndex: 1,
                        chips: 5,
                        won: true,
                      ),
                      PartyPollViewBet(
                        id: 'other-10',
                        bettorPlayerId: 'evil',
                        targetPlayerId: 'bb',
                        targetSlotIndex: 1,
                        chips: 10,
                        won: true,
                      ),
                    ]
                  : const [],
              winningPlayerIds: isReveal ? const {'bb'} : const {},
              score: 40,
              betTotal: 0,
              betLimit: PartyPollRules.roundStakeLimit,
              availableChips: PartyPollRules.roundStakeLimit,
              selectedChipValue: isReveal ? null : 5,
              currentPlayerId: 'emirl',
              selectedBetId: null,
              emphasizeWinners: false,
              activeRevealSlotIndex: isReveal ? 1 : null,
              onChipSelected: (_) {},
              onBetSelected: (_) {},
              onBetRequested: (_, _, _, _) {},
              onBetMoveRequested: (_, _, _, _, _) {},
              onBetRemoveRequested: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));
  }

  void expectInside(Rect rect, Size viewport, {required String reason}) {
    expect(rect.left, greaterThanOrEqualTo(0), reason: reason);
    expect(rect.top, greaterThanOrEqualTo(0), reason: reason);
    expect(rect.right, lessThanOrEqualTo(viewport.width), reason: reason);
    expect(rect.bottom, lessThanOrEqualTo(viewport.height), reason: reason);
  }

  void expectSceneGeometry(
    WidgetTester tester,
    Size size, {
    required bool reveal,
  }) {
    final primary = tester.getRect(
      find.byKey(
        reveal
            ? const ValueKey('party-result-2')
            : const ValueKey('party-question-card'),
      ),
    );
    final picker = tester.getRect(
      find.byKey(const ValueKey('party-chip-picker')),
    );
    final leaderboard = tester.getRect(
      find.byKey(const ValueKey('party-leaderboard')),
    );
    final board = tester.getRect(find.byKey(const ValueKey('party-board-2')));
    final infoColumn = tester.getRect(
      find.byKey(const ValueKey('party-betting-info-column')),
    );
    final boardColumn = tester.getRect(
      find.byKey(const ValueKey('party-betting-board-column')),
    );

    expectInside(primary, size, reason: 'primary card at $size');
    expectInside(picker, size, reason: 'chip picker at $size');
    expectInside(leaderboard, size, reason: 'leaderboard at $size');
    expectInside(board, size, reason: 'board at $size');
    expectInside(infoColumn, size, reason: 'info column at $size');
    expectInside(boardColumn, size, reason: 'board column at $size');
    expect(
      (infoColumn.width - boardColumn.width).abs(),
      lessThanOrEqualTo(12.1),
    );
    expect(primary.bottom, lessThanOrEqualTo(picker.top + .01));
    expect(picker.bottom, lessThanOrEqualTo(leaderboard.top + .01));
    expect(primary.right, lessThanOrEqualTo(board.left + .01));
    expect(picker.right, lessThanOrEqualTo(board.left + .01));
    expect(leaderboard.right, lessThanOrEqualTo(board.left + .01));
  }

  testWidgets('betting scene is responsive on all supported phone sizes', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in phoneSizes) {
      await pumpPartyView(
        tester,
        size: size,
        isReveal: false,
        question: stressQuestion,
      );

      expect(tester.takeException(), isNull, reason: 'betting at $size');
      expect(find.text('TAP A BET AREA'), findsOneWidget);
      final selectorChips = find.descendant(
        of: find.byKey(const ValueKey('party-chip-picker')),
        matching: find.byType(PokerChip),
      );
      expect(selectorChips, findsNWidgets(3));
      final chipPicker = find.byKey(const ValueKey('party-chip-picker'));
      for (final value in PartyPollRules.chipValues) {
        expect(
          find.descendant(of: chipPicker, matching: find.text('$value')),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(of: chipPicker, matching: find.text('25')),
        findsNothing,
      );
      final chipRects = [
        for (var i = 0; i < 3; i++) tester.getRect(selectorChips.at(i)),
      ];
      for (var i = 0; i < chipRects.length - 1; i++) {
        expect(
          chipRects[i].right,
          lessThanOrEqualTo(chipRects[i + 1].left),
          reason: 'selector chip overlap at $size',
        );
      }
      expectSceneGeometry(tester, size, reveal: false);
      final questionCard = tester.getRect(
        find.byKey(const ValueKey('party-question-card')),
      );
      final questionFinder = find.text(stressQuestion);
      expect(
        find.ancestor(
          of: questionFinder,
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      final questionBounds = tester.getRect(questionFinder);
      expect(questionCard.contains(questionBounds.topLeft), isTrue);
      expect(questionCard.contains(questionBounds.bottomRight), isTrue);
      if (size == const Size(390, 844)) {
        final leaderboard = tester.getRect(
          find.byKey(const ValueKey('party-leaderboard')),
        );
        expect(leaderboard.height, lessThan(questionCard.height));
      }
    }
  });

  testWidgets('reveal scene stays inside every supported phone viewport', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in phoneSizes) {
      await pumpPartyView(tester, size: size, isReveal: true);

      expect(tester.takeException(), isNull, reason: 'reveal at $size');
      expect(find.text('RESULT'), findsWidgets);
      expect(find.text('LOCKING RESULT'), findsOneWidget);
      expectSceneGeometry(tester, size, reveal: true);
    }
  });

  testWidgets('320x568 remains stable at 1.2 text scale', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const size = Size(320, 568);

    await pumpPartyView(
      tester,
      size: size,
      isReveal: false,
      question: stressQuestion,
      textScale: 1.2,
    );

    expect(tester.takeException(), isNull);
    expectSceneGeometry(tester, size, reveal: false);
  });
  testWidgets('mobile question always fits fully without scrolling', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpPartyView(
      tester,
      size: const Size(320, 568),
      isReveal: false,
      question: stressQuestion,
    );

    final questionFinder = find.text(stressQuestion);
    final question = tester.widget<Text>(questionFinder);
    final fontSize = question.style?.fontSize;
    final card = tester.getRect(
      find.byKey(const ValueKey('party-question-card')),
    );
    final questionBounds = tester.getRect(questionFinder);

    expect(question.style?.fontFamily, 'RehnCondensed');
    expect(fontSize, lessThanOrEqualTo(34));
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(card.contains(questionBounds.topLeft), isTrue);
    expect(card.contains(questionBounds.bottomRight), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('longest production prompts fully fit at 320x568', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const size = Size(320, 568);

    for (final question in longestProductionQuestions) {
      await pumpPartyView(
        tester,
        size: size,
        isReveal: false,
        question: question,
      );

      final card = tester.getRect(
        find.byKey(const ValueKey('party-question-card')),
      );
      final questionFinder = find.text(question);
      final text = tester.getRect(questionFinder);
      expect(card.contains(text.topLeft), isTrue, reason: question);
      expect(card.contains(text.bottomRight), isTrue, reason: question);
      expect(
        find.ancestor(of: questionFinder, matching: find.byType(FittedBox)),
        findsNothing,
        reason:
            'production prompt should fit without emergency scaling: $question',
      );
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(tester.takeException(), isNull, reason: question);
    }
  });
  testWidgets('exact real-device question stays inside the paint-safe body', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in phoneSizes) {
      await pumpPartyView(
        tester,
        size: size,
        isReveal: false,
        question: failingProductionQuestion,
      );

      final questionFinder = find.byKey(const ValueKey('party-question-text'));
      final rendered = tester.widget<Text>(questionFinder);
      final safeArea = tester.getRect(
        find.byKey(const ValueKey('party-question-text-area')),
      );
      final textRect = tester.getRect(questionFinder);

      expect(find.text(failingProductionQuestion), findsOneWidget);
      expect(
        find.ancestor(
          of: questionFinder,
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      expect(rendered.style?.fontFamily, 'RehnCondensed');
      expect(rendered.maxLines, isNull);
      expect(rendered.softWrap, isTrue);
      expect(rendered.overflow, TextOverflow.visible);
      expect(rendered.style?.fontSize, lessThanOrEqualTo(34));
      final fitter = tester.getRect(
        find.byKey(const ValueKey('party-question-fitter')),
      );
      expect(textRect.left, greaterThanOrEqualTo(safeArea.left));
      expect(textRect.right, lessThanOrEqualTo(safeArea.right + 0.01));
      expect(textRect.top, greaterThanOrEqualTo(safeArea.top));
      expect(textRect.bottom, lessThanOrEqualTo(safeArea.bottom + 0.01));
      expect(textRect.top, greaterThan(fitter.top));
      expect(textRect.bottom, lessThan(fitter.bottom));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('short Party question stays larger than a long question', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const size = Size(320, 568);

    await pumpPartyView(
      tester,
      size: size,
      isReveal: false,
      question: shortQuestion,
    );
    final shortSize = tester
        .widget<Text>(find.byKey(const ValueKey('party-question-text')))
        .style!
        .fontSize!;

    await pumpPartyView(
      tester,
      size: size,
      isReveal: false,
      question: stressQuestion,
    );
    final longSize = tester
        .widget<Text>(find.byKey(const ValueKey('party-question-text')))
        .style!
        .fontSize!;

    expect(shortSize, greaterThan(longSize));
    expect(shortSize, lessThanOrEqualTo(34));
    expect(longSize, greaterThanOrEqualTo(8));
    expect(tester.takeException(), isNull);
  });
  testWidgets('player names and odds keep the slot centre clear on mobile', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpPartyView(tester, size: const Size(360, 800), isReveal: false);

    final board = tester.getRect(find.byKey(const ValueKey('party-board-2')));
    final playerName = tester.getRect(
      find.text('EMIRL WITH A LONG NAME').first,
    );
    final firstOdds = tester.getRect(find.text('2X').first);

    expect(playerName.left, greaterThanOrEqualTo(board.left));
    expect(playerName.top, lessThan(board.top + board.height / 3));
    expect(firstOdds.center.dx, greaterThan(board.center.dx));
    expect(firstOdds.bottom, lessThanOrEqualTo(board.top + board.height / 3));
    expect(tester.takeException(), isNull);
  });
}
