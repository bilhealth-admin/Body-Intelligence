import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/repositories/daily_log_repository.dart';

final dailyLogRepositoryProvider = Provider<DailyLogRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return DailyLogRepository(database);
});

final latestDailyLogProvider = StreamProvider<DailyLog?>((ref) {
  final repository = ref.watch(dailyLogRepositoryProvider);
  return repository.watchLatest();
});