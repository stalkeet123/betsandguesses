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
}
