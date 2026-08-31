import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const routeFamilies = <String, String>{
    '/startup': 'startup',
    '/login': 'auth',
    '/reviewer-login': 'auth',
    '/auth-callback': 'auth',
    '/reset-password': 'auth',
    '/register': 'auth',
    '/verify-email': 'auth',
    '/account-gateway': 'auth',
    '/account-data-conflict': 'auth',
    '/onboarding': 'onboarding',
    '/daily-check-in': 'capture',
    '/context': 'intelligence',
    '/decision-memory': 'intelligence',
    '/plan': 'intelligence',
    '/experiments': 'intelligence',
    '/share-studio': 'profile',
    '/challenges': 'wellness',
    '/profile-summary': 'profile',
    '/profile-settings': 'profile',
    '/advanced-body-measurements': 'profile',
    '/connected-health': 'connected-health',
    '/connected-health/steps': 'connected-health',
    '/connected-health/heart': 'connected-health',
    '/connected-health/capabilities': 'connected-health',
    '/plans': 'commerce',
    '/premium-logging-intro': 'commerce',
    '/nutrition-plans': 'nutrition-plans',
    '/nutrition-plans/:pathwayId': 'nutrition-plans',
    '/weekly-report': 'reports',
    '/analytics/nutrition': 'progress',
    '/community': 'community',
    '/community/people': 'community',
    '/community/notifications': 'community',
    '/community/connections': 'community',
    '/community/food-review': 'community',
    '/community/profile': 'community',
    '/community/safety': 'community',
    '/community/chat/:userId': 'community',
    '/community/messages': 'community',
    '/community/messages/new': 'community',
    '/food-libraries': 'nutrition',
    '/meal-image-guide': 'nutrition',
    '/notification-settings': 'notifications',
    '/advertising-privacy': 'privacy',
    '/legal/privacy': 'privacy',
    '/legal/terms': 'privacy',
    '/legal/health-disclaimer': 'privacy',
    '/help': 'settings',
    '/wellness-library': 'wellness',
    '/wellness/learn': 'wellness',
    '/wellness/sleep': 'wellness',
    '/wellness/workouts': 'wellness',
    '/wellness/workouts/routines': 'wellness',
    '/wellness/workouts/log': 'wellness',
    '/wellness/fasting': 'wellness',
    '/wellness/recipes': 'wellness',
    '/nutrition/recipes/import': 'nutrition',
    '/meal-planner': 'nutrition',
    '/wellness/content-packs': 'wellness',
    '/location-settings': 'settings',
    '/trust-support': 'support',
    '/help/faq': 'settings',
    '/help/delete-account': 'settings',
    '/settings/analytics': 'settings',
    '/settings/diary': 'settings',
    '/settings/diary/search-tab': 'settings',
    '/settings/diary/sharing': 'settings',
    '/settings/diary/meal-names': 'settings',
    '/settings/email': 'settings',
    '/settings/account-email': 'settings',
    '/settings/account-password': 'settings',
    '/settings/account-connections/facebook': 'settings',
    '/settings/account-connections/google': 'settings',
    '/settings/units': 'settings',
    '/settings/appearance': 'settings',
    '/goals': 'profile',
    '/settings/nutrition-goals': 'settings',
    '/settings/nutrition-goal-schedule': 'settings',
    '/settings/nutrition-meal-calorie-goals': 'settings',
    '/settings/diary/macro-display': 'settings',
    '/settings/exercise-calories': 'settings',
    '/settings/preferences': 'settings',
    '/settings/language': 'settings',
    '/settings/sharing-privacy': 'privacy',
    '/settings/local-export': 'settings',
    '/dashboard': 'dashboard',
    '/dashboard/decision-explanation': 'dashboard',
    '/daily-log': 'diary',
    '/daily-log/body-context': 'diary',
    '/daily-log/water': 'diary',
    '/intelligence-center': 'intelligence',
    '/settings/ai-coach': 'intelligence',
    '/admin/ai-coach': 'intelligence',
    '/nutrition': 'nutrition',
    '/foods': 'nutrition',
    '/history': 'progress',
    '/weight-history': 'progress',
    '/analytics': 'progress',
    '/settings': 'settings',
    '/dashboard/preferences': 'dashboard',
  };

  const familyEvidence = <String, List<String>>{
    'startup': [
      'test/startup_state_test.dart',
      'test/premium_splash_experience_test.dart',
    ],
    'auth': ['test/auth_boundary_test.dart', 'test/account_gateway_test.dart'],
    'onboarding': [
      'test/features/onboarding/onboarding_visual_golden_test.dart',
      'test/onboarding_recovery_test.dart',
    ],
    'capture': [
      'test/features/daily_check_in/weight_progress_photo_contract_test.dart',
    ],
    'intelligence': [
      'test/features/dashboard/presentation/dashboard_decision_explanation_page_test.dart',
      'test/features/admin/ai_coach_global_reset_test.dart',
    ],
    'profile': [
      'test/premium_profile_page_contract_test.dart',
      'test/profile_experience_contract_test.dart',
    ],
    'wellness': [
      'lib/features/wellness/presentation/wellness_library_page.dart',
    ],
    'connected-health': [
      'test/connected_health/connected_health_contract_test.dart',
    ],
    'commerce': ['test/features/commerce/commerce_paywall_widget_test.dart'],
    'nutrition-plans': [
      'test/features/nutrition/nutrition_pathways_contract_test.dart',
    ],
    'reports': [
      'test/features/global_platform/world_class_reports_system_test.dart',
    ],
    'community': [
      'lib/features/community/presentation/community_hub_page.dart',
    ],
    'nutrition': [
      'test/features/nutrition/daily_search_closure_contract_test.dart',
    ],
    'notifications': [
      'lib/features/notifications/presentation/notification_settings_page.dart',
    ],
    'privacy': ['test/launch_readiness/epic16_ad_privacy_contract_test.dart'],
    'settings': [
      'test/app_settings_test.dart',
      'test/location_settings_contract_test.dart',
    ],
    'support': ['lib/features/settings/trust_support_page.dart'],
    'dashboard': [
      'test/premium_dashboard_benchmark_test.dart',
      'test/dashboard_loading_skeleton_test.dart',
    ],
    'diary': [
      'test/daily_log_layout_contract_test.dart',
      'test/daily_log_recovery_test.dart',
    ],
    'progress': [
      'test/analytics_recovery_test.dart',
      'test/weight_history_test.dart',
    ],
  };

  test(
    'every active application route is classified with existing evidence',
    () {
      final router = File('lib/app/router/app_router.dart').readAsStringSync();
      final discovered = RegExp(
        r"path:\s*'([^']+)'",
      ).allMatches(router).map((match) => match.group(1)!).toSet();

      expect(routeFamilies.keys.toSet(), discovered);
      for (final entry in routeFamilies.entries) {
        final evidence = familyEvidence[entry.value];
        expect(
          evidence,
          isNotNull,
          reason: '${entry.key} has no evidence family',
        );
        for (final path in evidence!) {
          expect(
            File(path).existsSync(),
            isTrue,
            reason: '${entry.key}: $path',
          );
        }
      }
    },
  );

  test('state and visual review axes have executable evidence', () {
    const stateEvidence = <String, String>{
      'loading': 'test/dashboard_loading_skeleton_test.dart',
      'empty': 'test/actionable_empty_state_test.dart',
      'error': 'test/daily_log_recovery_test.dart',
      'disabled': 'test/epic3_visual_matrix_golden_test.dart',
      'offline':
          'test/features/cloud_platform/offline_first_cloud_platform_test.dart',
    };
    for (final entry in stateEvidence.entries) {
      expect(File(entry.value).existsSync(), isTrue, reason: entry.key);
    }

    for (final size in ['compact', 'large']) {
      for (final locale in ['en', 'ar']) {
        for (final theme in ['light', 'dark']) {
          expect(
            File(
              'test/goldens/epic3_${size}_${locale}_$theme.png',
            ).existsSync(),
            isTrue,
            reason: '$size/$locale/$theme',
          );
        }
      }
    }
  });
}
