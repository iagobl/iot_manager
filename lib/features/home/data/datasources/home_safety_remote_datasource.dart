import 'package:supabase_flutter/supabase_flutter.dart';

class HomeSafetyRemoteDataSource {
  final SupabaseClient _client = Supabase.instance.client;

  Future<Map<String, dynamic>?> getSafetySettings(String homeId) async {
    final response = await _client.from('home_safety_settings')
        .select('home_id, max_total_consumption_wh, updated_at')
        .eq('home_id', homeId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(response);
  }

  Future<void> upsertSafetySettings({
    required String homeId,
    double? maxTotalConsumptionWh,
  }) async {
    await _client.from('home_safety_settings').upsert({
        'home_id': homeId,
        'max_total_consumption_wh': maxTotalConsumptionWh,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'home_id',
    );
  }
}