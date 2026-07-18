import 'package:go_router/go_router.dart';

import '../../features/analytics/analytics_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/daily_log/daily_log_page.dart';
import '../../features/daily_check_in/daily_check_in_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/history/history_page.dart';
import '../../features/life_context/life_context_page.dart';
import '../../features/life_context/decision_memory_page.dart';
import '../../features/nutrition/food_page.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/startup/startup_page.dart';
import 'responsive_app_shell.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/startup',
    routes: [
      GoRoute(path: '/startup', builder: (_, _) => const StartupPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
      GoRoute(
        path: '/daily-check-in',
        builder: (_, _) => const DailyCheckInPage(),
      ),
      GoRoute(path: '/context', builder: (_, _) => const LifeContextPage()),
      GoRoute(
        path: '/decision-memory',
        builder: (_, _) => const DecisionMemoryPage(),
      ),
      ShellRoute(
        builder: (_, _, child) => ResponsiveAppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, _) => const DashboardPage()),
          GoRoute(path: '/daily-log', builder: (_, _) => const DailyLogPage()),
          GoRoute(path: '/nutrition', builder: (_, _) => const FoodPage()),
          GoRoute(path: '/history', builder: (_, _) => const HistoryPage()),
          GoRoute(path: '/analytics', builder: (_, _) => const AnalyticsPage()),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
        ],
      ),
    ],
  );
}
