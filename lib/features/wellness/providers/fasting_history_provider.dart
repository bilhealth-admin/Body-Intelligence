import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../commerce/providers/commerce_providers.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../data/fasting_history_repository.dart';

/// Provider identity fences delivered A -> B -> A, even if a database is reused.
final fastingHistoryOwnerVisitProvider = Provider<Object>((ref) {
  ref.watch(preferencesRepositoryProvider);
  ref.watch(verifiedEntitlementOwnerVisitProvider);
  return Object();
});

final fastingHistoryRepositoryProvider = Provider<FastingHistoryRepository>((
  ref,
) {
  ref.watch(fastingHistoryOwnerVisitProvider);
  return FastingHistoryRepository(ref.watch(preferencesRepositoryProvider));
});

final fastingHistorySnapshotProvider = StreamProvider<FastingHistorySnapshot>((
  ref,
) {
  return ref.watch(fastingHistoryRepositoryProvider).watch();
});
