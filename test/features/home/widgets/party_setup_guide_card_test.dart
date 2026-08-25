import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/features/home/widgets/party_setup_guide_card.dart';

void main() {
  testWidgets('party setup guide fits compact phone allocations', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in const [Size(248, 80), Size(248, 180)]) {
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.2)),
          child: const MaterialApp(home: Scaffold(body: PartySetupGuideCard())),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'allocation $size');
    }
  });
}
