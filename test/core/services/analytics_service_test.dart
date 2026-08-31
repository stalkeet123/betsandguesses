import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/core/services/analytics_service.dart';

void main() {
  test('is disabled by default when explicitly configured for tests', () async {
    var calls = 0;
    final service = AnalyticsService.withRpc((functionName, {params}) async {
      calls++;
    }, enabled: false);

    await service.track(AnalyticsEventName.appOpen);

    expect(calls, 0);
  });

  test('sends only allowed event names and safe properties', () async {
    String? functionName;
    Map<String, dynamic>? sentParams;
    final service = AnalyticsService.withRpc((name, {params}) async {
      functionName = name;
      sentParams = params;
    }, enabled: true);

    await service.track(
      AnalyticsEventName.inviteLinkCopied,
      roomId: '00000000-0000-0000-0000-000000000001',
      properties: {
        'surface': 'app',
        'player_name': 'must not be sent',
        'error': 'must not be sent',
      },
    );

    expect(functionName, 'track_analytics_event_v1');
    expect(sentParams?['p_event_name'], 'invite_link_copied');
    expect(sentParams?['p_room_id'], '00000000-0000-0000-0000-000000000001');
    expect(sentParams?['p_properties'], {'surface': 'app'});
  });

  test('absorbs RPC failures', () async {
    final service = AnalyticsService.withRpc(
      (functionName, {params}) async => throw StateError('offline'),
      enabled: true,
    );

    await service.track(AnalyticsEventName.purchaseFailed);
  });

  test('has exactly the allowed client event names', () {
    expect(AnalyticsEventName.values.map((event) => event.value), [
      'app_open',
      'onboarding_completed',
      'invite_link_copied',
      'paywall_viewed',
      'purchase_started',
      'purchase_cancelled',
      'purchase_failed',
    ]);
  });
}
