import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/database/date_keys.dart';
import '../../../data/repositories/weight_repository.dart';
import '../../../data/repositories/body_measurement_repository.dart';
import '../../profile/providers/user_profile_provider.dart';

final weightRepositoryProvider = Provider<WeightRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return WeightRepository(database);
});

final latestWeightProvider = StreamProvider<WeightEntry?>((ref) {
  final repository = ref.watch(weightRepositoryProvider);
  return repository.watchLatestWeight();
});

@visibleForTesting
double? resolveEffectiveCurrentWeight({
  required double? latestMeasurement,
  required double? profileFallback,
}) => latestMeasurement ?? profileFallback;

/// One read authority for any surface or engine that needs "current weight".
/// A real measurement outranks the onboarding/profile fallback.
final effectiveCurrentWeightProvider = Provider<double?>((ref) {
  final latest = ref.watch(latestWeightProvider).value?.weight;
  final profile = ref.watch(userProfileProvider).value;
  return resolveEffectiveCurrentWeight(
    latestMeasurement: latest,
    profileFallback: profile?.currentWeight,
  );
});

final weightHistoryProvider = StreamProvider<List<WeightEntry>>((ref) {
  final repository = ref.watch(weightRepositoryProvider);
  return repository.watchWeights();
});

final bodyMeasurementRepositoryProvider = Provider<BodyMeasurementRepository>((
  ref,
) {
  return BodyMeasurementRepository(ref.watch(databaseProvider));
});

final bodyMeasurementHistoryProvider =
    StreamProvider<List<BodyMeasurementEntry>>((ref) {
      return ref.watch(bodyMeasurementRepositoryProvider).watchHistory();
    });

final todayWeightProvider = StreamProvider<WeightEntry?>((ref) {
  return ref.watch(weightRepositoryProvider).watchForDay(DateTime.now());
});

final weightReminderSkippedTodayProvider = StreamProvider<bool>((ref) {
  final todayKey = dayKeyFor(DateTime.now());
  return ref
      .watch(preferencesRepositoryProvider)
      .watch('weightReminderSkippedDay')
      .map((value) => value == todayKey);
});

final dailyCheckInDueProvider = FutureProvider<bool>((ref) async {
  final today = DateTime.now();
  final entry = await ref.watch(weightRepositoryProvider).getForDay(today);
  if (entry != null) return false;
  final skipped = await ref
      .watch(preferencesRepositoryProvider)
      .get('weightReminderSkippedDay');
  return skipped != dayKeyFor(today);
});
