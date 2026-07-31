import 'package:go_router/go_router.dart';

import '../../features/analytics/analytics_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/account_gateway_page.dart';
import '../../features/daily_log/daily_log_page.dart';
import '../../features/daily_check_in/daily_check_in_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/dashboard/domain/dashboard_decision_explanation.dart';
import '../../features/dashboard/presentation/dashboard_decision_explanation_page.dart';
import '../../features/history/history_page.dart';
import '../../features/experiments/experiments_page.dart';
import '../../features/challenges/challenges_page.dart';
import '../../features/connected_health/connected_health_page.dart';
import '../../features/life_context/life_context_page.dart';
import '../../features/life_context/decision_memory_page.dart';
import '../../features/nutrition/food_page.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/settings/location_settings_page.dart';
import '../../features/share_studio/share_studio_page.dart';
import '../../features/profile/plan_page.dart';
import '../../features/profile/profile_settings_page.dart';
import '../../features/startup/startup_page.dart';
import 'responsive_app_shell.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/startup',
    routes: [
      GoRoute(path: '/startup', builder: (_, _) => const StartupPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(
        path: '/account-gateway',
        builder: (_, _) => const AccountGatewayPage(),
      ),
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
      GoRoute(path: '/plan', builder: (_, _) => const PlanPage()),
      GoRoute(path: '/experiments', builder: (_, _) => const ExperimentsPage()),
      GoRoute(
        path: '/share-studio',
        builder: (_, _) => const ShareStudioPage(),
      ),
      GoRoute(path: '/challenges', builder: (_, _) => const ChallengesPage()),
      GoRoute(
        path: '/profile-settings',
        builder: (_, _) => const ProfileSettingsPage(),
      ),
      GoRoute(
        path: '/connected-health',
        builder: (_, _) => const ConnectedHealthPage(),
      ),
      GoRoute(
        path: '/location-settings',
        builder: (_, _) => const LocationSettingsPage(),
      ),
      GoRoute(
        path: '/settings/analytics',
        builder: (_, _) => const AnalyticsPage(showSettingsBack: true),
      ),
      ShellRoute(
        builder: (_, _, child) => ResponsiveAppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, _) => const DashboardPage()),
          GoRoute(
            path: '/dashboard/decision-explanation',
            builder: (_, state) => DashboardDecisionExplanationPage(
              explanation: state.extra is DashboardDecisionExplanation
                  ? state.extra! as DashboardDecisionExplanation
                  : null,
            ),
          ),
          GoRoute(
            path: '/daily-log',
            builder: (_, state) => DailyLogPage(
              initialMealType: state.uri.queryParameters['meal'],
              focusMealEntry: state.uri.queryParameters['focus'] == 'meal',
            ),
          ),
          GoRoute(path: '/nutrition', builder: (_, _) => const FoodPage()),
          GoRoute(path: '/history', builder: (_, _) => const HistoryPage()),
          GoRoute(path: '/analytics', builder: (_, _) => const AnalyticsPage()),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
        ],
      ),
    ],
  );
}
