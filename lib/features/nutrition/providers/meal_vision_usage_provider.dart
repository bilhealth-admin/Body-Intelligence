import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/meal_vision_usage_repository.dart';
import '../services/meal_vision_usage_contract.dart';

final mealVisionUsageRepositoryProvider = Provider<MealVisionUsageRepository?>((
  ref,
) {
  try {
    return MealVisionUsageRepository(Supabase.instance.client);
  } catch (_) {
    return null;
  }
});

final mealVisionUsageProvider =
    FutureProvider.autoDispose<MealVisionUsageSnapshot>((ref) async {
      final repository = ref.watch(mealVisionUsageRepositoryProvider);
      return repository?.read() ?? const MealVisionUsageSnapshot.unavailable();
    });
