import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/meal_vision_usage_contract.dart';

final class MealVisionUsageRepository {
  const MealVisionUsageRepository(this._client);

  final SupabaseClient _client;

  Future<MealVisionUsageSnapshot> read() async {
    if (_client.auth.currentSession == null) {
      return const MealVisionUsageSnapshot.signedOut();
    }
    try {
      final raw = await _client.rpc('bil_get_ai_usage_status');
      if (raw is! Map) return const MealVisionUsageSnapshot.unavailable();
      final usage = MealVisionUsage.fromAiUsageStatus(
        raw.cast<String, Object?>(),
      );
      return MealVisionUsageSnapshot.available(usage);
    } catch (_) {
      return const MealVisionUsageSnapshot.unavailable();
    }
  }
}
