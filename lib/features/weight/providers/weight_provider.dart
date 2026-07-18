import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/database/date_keys.dart';
import '../../../data/repositories/weight_repository.dart';
import '../../profile/providers/user_profile_provider.dart';

final weightRepositoryProvider = Provider<WeightRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return WeightRepository(database);
});

final latestWeightProvider = StreamProvider<WeightEntry?>((ref) {
  final repository = ref.watch(weightRepositoryProvider);
  return repository.watchLatestWeight();
});

final weightHistoryProvider = StreamProvider<List<WeightEntry>>((ref) {
  final repository = ref.watch(weightRepositoryProvider);
  return repository.watchWeights();
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
