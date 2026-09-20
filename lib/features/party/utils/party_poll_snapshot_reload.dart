import 'dart:async';

import '../../../core/services/game_trace_service.dart';

/// Room-row fields are diagnostic hints, never Party gameplay state.
void handlePartyPollRoomRowChanged(
  Map<String, dynamic> record,
  void Function() scheduleSnapshotReload,
) {
  GameTraceService.instance.trace('party_phase_hint_received', {
    'source': 'postgres',
    if (record['current_round'] is num)
      'round': (record['current_round'] as num).toInt(),
    if (record['round_phase'] != null) 'phase': '${record['round_phase']}',
    if (record['state_version'] is num)
      'state_version': (record['state_version'] as num).toInt(),
  });
  scheduleSnapshotReload();
}

/// Coalesce invalidation hints into the existing snapshot recovery path.
Timer schedulePartyPollSnapshotReload({
  required Timer? pending,
  required void Function() reload,
}) {
  GameTraceService.instance.trace('party_resync_scheduled', {
    'source': 'party_snapshot',
    'delay_ms': 350,
  });
  pending?.cancel();
  return Timer(const Duration(milliseconds: 350), reload);
}
