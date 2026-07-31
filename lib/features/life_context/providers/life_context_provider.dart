import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/repositories/decision_memory_repository.dart';
import '../../../data/repositories/life_context_repository.dart';
import '../../profile/providers/user_profile_provider.dart';

final lifeContextRepositoryProvider = Provider<LifeContextRepository>((ref) {
  return LifeContextRepository(ref.watch(databaseProvider));
});

final todayLifeContextProvider = StreamProvider<List<LifeContextEntry>>((ref) {
  return ref.watch(lifeContextRepositoryProvider).watchForDay(DateTime.now());
});

final insightLifeContextProvider = StreamProvider<List<LifeContextEntry>>((
  ref,
) {
  return ref.watch(lifeContextRepositoryProvider).watchAllForInsights();
});

final decisionMemoryRepositoryProvider = Provider<DecisionMemoryRepository>((
  ref,
) {
  return DecisionMemoryRepository(ref.watch(databaseProvider));
});

final decisionMemoriesProvider = StreamProvider<List<DecisionMemory>>((ref) {
  return ref.watch(decisionMemoryRepositoryProvider).watchAll();
});

final decisionMemoryEnabledProvider = StreamProvider<bool>((ref) {
  return ref
      .watch(preferencesRepositoryProvider)
      .watch('decisionMemoryEnabled')
      .map((value) => value != 'false');
});
