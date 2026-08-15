import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../life_context/providers/life_context_provider.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../weight/providers/weight_provider.dart';
import 'dashboard_provider.dart';

class DashboardRetry {
  const DashboardRetry._();

  static void invalidate(WidgetRef ref) {
    ref.invalidate(userProfileProvider);
    ref.invalidate(weightHistoryProvider);
    ref.invalidate(todayMealsProvider);
    ref.invalidate(todayWaterProvider);
    ref.invalidate(allMealsProvider);
    ref.invalidate(allWaterProvider);
    ref.invalidate(weightReminderSkippedTodayProvider);
    ref.invalidate(todayLifeContextProvider);
    ref.invalidate(insightLifeContextProvider);
    ref.invalidate(decisionMemoriesProvider);
  }
}
