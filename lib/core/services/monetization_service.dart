import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/monetization_status.dart';

class MonetizationService {
  final SupabaseClient client;
  MonetizationService(this.client);

  Future<MonetizationStatus> getStatus() async => MonetizationStatus.fromJson(
    Map<String, dynamic>.from(await client.rpc('get_monetization_status_v1')),
  );

  Future<MonetizationStatus> syncRevenueCatEntitlement() async {
    final r = await client.functions.invoke('sync-revenuecat-entitlement');
    if (r.data is! Map) throw StateError('Invalid monetization response');
    return MonetizationStatus.fromJson(Map<String, dynamic>.from(r.data));
  }

  Future<MonetizationStatus> setDebugPremiumOverride(bool? value) async {
    final response = await client.rpc(
      'set_debug_premium_override_v1',
      params: {'p_override': value},
    );
    return _parseStatusResponse(response, 'set_debug_premium_override_v1');
  }

  Future<MonetizationStatus> setDebugFreeHostGamesUsed(int used) async {
    if (used < 0 || used > 3) {
      throw RangeError.range(used, 0, 3, 'used');
    }
    final response = await client.rpc(
      'set_debug_free_host_games_used_v1',
      params: {'p_used': used},
    );
    return _parseStatusResponse(response, 'set_debug_free_host_games_used_v1');
  }

  MonetizationStatus _parseStatusResponse(Object? response, String rpcName) {
    if (response is! Map) {
      throw StateError('$rpcName returned an invalid monetization response');
    }
    return MonetizationStatus.fromJson(Map<String, dynamic>.from(response));
  }
}
