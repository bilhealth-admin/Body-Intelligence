import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/database_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../daily_log/providers/daily_log_provider.dart';
import '../../life_context/providers/life_context_provider.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../weight/providers/weight_provider.dart';
import '../domain/local_intelligence_runtime.dart';
import '../services/local_intelligence_composition_root.dart';

/// Canonical product-wide intelligence result.
///
/// Every health-intelligence surface watches this provider, ensuring Body Twin,
/// Truth Engine, One Best Action, safety, and coach output are calculated once
/// from the same local revision. The watched streams are invalidation signals;
/// Reality Runtime remains the only component that reads and interprets facts.
final productIntelligenceOutputProvider =
    FutureProvider.autoDispose<ProductIntelligenceOutput>((ref) async {
      ref.watch(userProfileProvider);
      ref.watch(weightHistoryProvider);
      ref.watch(allMealsProvider);
      ref.watch(allWaterProvider);
      ref.watch(insightLifeContextProvider);
      ref.watch(decisionMemoriesProvider);
      ref.watch(latestDailyLogProvider);

      final database = ref.watch(databaseProvider);
      final runtime = const BilLocalIntelligenceCompositionRoot().create(
        database: database,
      );
      return runtime.run(asOf: DateTime.now());
    });
