import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AnalyticsEventName {
  appOpen('app_open'),
  onboardingCompleted('onboarding_completed'),
  inviteLinkCopied('invite_link_copied'),
  paywallViewed('paywall_viewed'),
  purchaseStarted('purchase_started'),
  purchaseCancelled('purchase_cancelled'),
  purchaseFailed('purchase_failed');

  const AnalyticsEventName(this.value);

  final String value;
}

typedef AnalyticsRpc =
    Future<dynamic> Function(
      String functionName, {
      Map<String, dynamic>? params,
    });

class AnalyticsService {
  AnalyticsService(SupabaseClient client, {bool? enabled})
    : this.withRpc(client.rpc, enabled: enabled);

  @visibleForTesting
  AnalyticsService.withRpc(this._rpc, {bool? enabled})
    : _enabled = enabled ?? kReleaseMode;

  final AnalyticsRpc _rpc;
  final bool _enabled;

  static const _allowedPropertyKeys = {
    'surface',
    'method',
    'entry_point',
    'package_identifier',
  };

  Future<void> track(
    AnalyticsEventName event, {
    String? roomId,
    Map<String, dynamic> properties = const {},
  }) async {
    if (!_enabled) return;

    final safeProperties = <String, dynamic>{
      for (final entry in properties.entries)
        if (_allowedPropertyKeys.contains(entry.key) &&
            (entry.value is String ||
                entry.value is num ||
                entry.value is bool))
          entry.key: entry.value,
    };

    try {
      await _rpc(
        'track_analytics_event_v1',
        params: {
          'p_event_name': event.value,
          'p_room_id': roomId,
          'p_properties': safeProperties,
        },
      );
    } catch (error, stackTrace) {
      debugPrint('Analytics event ${event.value} failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
