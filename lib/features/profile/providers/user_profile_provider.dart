import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/repositories/user_profile_repository.dart';
import '../../../data/repositories/goal_repository.dart';
import '../../../data/repositories/preferences_repository.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return UserProfileRepository(database);
});

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return GoalRepository(ref.watch(databaseProvider));
});

final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  return PreferencesRepository(ref.watch(databaseProvider));
});

final userProfileProvider = StreamProvider<UserProfileData?>((ref) {
  final repository = ref.watch(userProfileRepositoryProvider);
  return repository.watchProfile();
});
