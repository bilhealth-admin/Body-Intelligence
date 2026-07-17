import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/repositories/weight_repository.dart';

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