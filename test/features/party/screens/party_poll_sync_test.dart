import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/features/party/providers/party_poll_session_provider.dart';
import 'package:witsgame/features/party/utils/party_poll_snapshot_reload.dart';

import '../support/party_poll_fixture.dart';

void main() {
  testWidgets(
    'room-row hints debounce reload without applying gameplay fields',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final accepted = partyPollFixture();
      container.read(partyPollSessionProvider.notifier).setSnapshot(accepted);
      final before = container.read(partyPollSessionProvider);
      Timer? pending;
      addTearDown(() => pending?.cancel());
      var scheduled = 0;
      var reloads = 0;
      void schedule() {
        scheduled++;
        pending = schedulePartyPollSnapshotReload(
          pending: pending,
          reload: () => reloads++,
        );
      }

      final hint = <String, dynamic>{
        'current_round': 99,
        'round_phase': 'reveal',
        'state_version': 999,
      };
      handlePartyPollRoomRowChanged(hint, schedule);
      expect(scheduled, 1);
      expect(reloads, 0);
      expect(container.read(partyPollSessionProvider), same(before));
      await tester.pump(const Duration(milliseconds: 200));
      handlePartyPollRoomRowChanged(hint, schedule);
      expect(scheduled, 2);
      await tester.pump(const Duration(milliseconds: 349));
      expect(reloads, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(reloads, 1);
      expect(container.read(partyPollSessionProvider).snapshot, same(accepted));

      // A hint with no gameplay columns (e.g. updated_at) still invalidates.
      handlePartyPollRoomRowChanged({'updated_at': 'changed'}, schedule);
      await tester.pump(const Duration(milliseconds: 350));
      expect(reloads, 2);
      expect(container.read(partyPollSessionProvider), same(before));

      handlePartyPollRoomRowChanged(hint, schedule);
      pending?.cancel();
      await tester.pump(const Duration(milliseconds: 350));
      expect(reloads, 2);
    },
  );
}
