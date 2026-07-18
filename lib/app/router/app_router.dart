import 'package:go_router/go_router.dart';

import '../../features/analytics/analytics_page.dart';
import '../../features/daily_log/daily_log_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/history/history_page.dart';
import '../../features/nutrition/food_page.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/startup/startup_page.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/startup',
    routes: [
      GoRoute(path: '/startup', builder: (_, _) => const StartupPage()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
      GoRoute(path: '/dashboard', builder: (_, _) => const DashboardPage()),
      GoRoute(path: '/daily-log', builder: (_, _) => const DailyLogPage()),
      GoRoute(path: '/nutrition', builder: (_, _) => const FoodPage()),
      GoRoute(path: '/history', builder: (_, _) => const HistoryPage()),
      GoRoute(path: '/analytics', builder: (_, _) => const AnalyticsPage()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
    ],
  );
}
