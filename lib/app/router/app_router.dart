import 'package:go_router/go_router.dart';

import '../analytics/bil_launch_deep_link.dart';
import '../environment/app_environment.dart';
import '../../features/analytics/analytics_page.dart';
import '../../features/analytics/nutrition_analytics_page.dart';
import '../../features/ads/advertising_privacy_page.dart';
import '../../features/admin/presentation/ai_coach_admin_page.dart';
import '../../features/analytics/weekly_report_page.dart';
import '../../features/settings/language_settings_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/register_page.dart';
import '../../features/auth/verify_email_page.dart';
import '../../features/auth/account_gateway_page.dart';
import '../../features/auth/account_data_conflict_page.dart';
import '../../features/auth/auth_callback_page.dart';
import '../../features/auth/reset_password_page.dart';
import '../../features/daily_log/daily_log_page.dart';
import '../../features/daily_log/daily_body_context_page.dart';
import '../../features/daily_log/daily_water_page.dart';
import '../../features/daily_check_in/daily_check_in_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/dashboard/domain/dashboard_decision_explanation.dart';
import '../../features/dashboard/presentation/dashboard_decision_explanation_page.dart';
import '../../features/dashboard/presentation/dashboard_preferences_page.dart';
import '../../features/history/history_page.dart';
import '../../features/history/progress_page.dart';
import '../../features/intelligence_center/presentation/intelligence_center_page.dart';
import '../../features/intelligence_center/presentation/ai_coach_settings_page.dart';
import '../../features/experiments/experiments_page.dart';
import '../../features/challenges/challenges_page.dart';
import '../../features/connected_health/connected_health_page.dart';
import '../../features/connected_health/partner_capabilities_page.dart';
import '../../features/connected_health/steps_settings_page.dart';
import '../../features/connected_health/connected_health_signal_detail_page.dart';
import '../../features/exercise_calorie_controls/presentation/exercise_calorie_settings_page.dart';
import '../../features/commerce/presentation/bil_store_plans_page.dart';
import '../../features/commerce/presentation/premium_route_glass_gate.dart';
import '../../features/commerce/presentation/premium_logging_intro_page.dart';
import '../../features/community/presentation/community_hub_page.dart';
import '../../features/community/presentation/community_people_page.dart';
import '../../features/community/presentation/community_connections_page.dart';
import '../../features/community/presentation/community_food_review_page.dart';
import '../../features/community/presentation/community_profile_page.dart';
import '../../features/community/presentation/community_safety_page.dart';
import '../../features/community/presentation/community_messages_page.dart';
import '../../features/community/presentation/community_notifications_page.dart';
import '../../features/life_context/life_context_page.dart';
import '../../features/life_context/decision_memory_page.dart';
import '../../features/nutrition/food_page.dart';
import '../../features/nutrition/presentation/catalog_packs_page.dart';
import '../../features/nutrition/presentation/meal_image_guide_page.dart';
import '../../features/nutrition/presentation/meals_recipes_foods_page.dart';
import '../../features/recipe_import/presentation/trusted_recipe_import_page.dart';
import '../../features/nutrition_plans/presentation/nutrition_pathways_page.dart';
import '../../features/nutrition_plans/presentation/diet_plan_editor_page.dart';
import '../../features/nutrition_plans/presentation/nutrition_pathway_access_gate.dart';
import '../../features/meal_planner/presentation/meal_planner_page.dart';
import '../../features/notifications/presentation/notification_settings_page.dart';
import '../../features/notifications/domain/community_deep_link.dart';
import '../../features/wellness/presentation/wellness_library_page.dart';
import '../../features/wellness/presentation/wellness_learn_page.dart';
import '../../features/wellness/presentation/wellness_content_packs_page.dart';
import '../../features/wellness/presentation/bil_workout_routines_page.dart';
import '../../features/wellness/presentation/wellness_tools_pages.dart';
import '../../features/wellness/presentation/recipe_library_page.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/settings/location_settings_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/settings/trust_support_page.dart';
import '../../features/settings/help_center_page.dart';
import '../../features/settings/account_deletion_page.dart';
import '../../features/settings/account_email_page.dart';
import '../../features/settings/account_password_page.dart';
import '../../features/settings/account_connection_settings_page.dart';
import '../../features/settings/legal_document_page.dart';
import '../../features/settings/reference_preferences_pages.dart';
import '../../features/settings/reference_settings_home_page.dart';
import '../../features/settings/reference_goals_page.dart';
import '../../features/settings/nutrition_goal_schedule_page.dart';
import '../../features/settings/premium_meal_features_page.dart';
import '../../features/settings/sharing_privacy_settings_page.dart';
import '../../features/settings/local_export_range_page.dart';
import '../../features/share_studio/share_studio_page.dart';
import '../../features/profile/plan_page.dart';
import '../../features/profile/plan_navigation_contract.dart';
import '../../features/profile/premium_profile_page.dart';
import '../../features/profile/profile_settings_page.dart';
import '../../features/profile/profile_summary_page.dart';
import '../../features/startup/startup_page.dart';
import 'invalid_route_page.dart';
import 'responsive_app_shell.dart';

String? _safeDailyReturnPath(String? value) =>
    const {'/dashboard', '/daily-log'}.contains(value) ? value : null;

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/startup',
    errorBuilder: (_, _) => const InvalidRoutePage(),
    redirect: (_, state) {
      if (state.uri.scheme == 'bil' && state.uri.host == 'auth-callback') {
        if (!AppEnvironment.cloudConfigured) return '/login';
        final isPasswordRecovery =
            state.uri.pathSegments.length == 1 &&
            state.uri.pathSegments.single == 'reset-password';
        return isPasswordRecovery ? '/reset-password' : '/auth-callback';
      }
      final launchLink = BilLaunchDeepLink.parse(state.uri);
      if (launchLink != null) return launchLink.route;
      final deepLinkRoute = CommunityDeepLink.routeFor(state.uri);
      if (deepLinkRoute == null) return null;
      if (deepLinkRoute.startsWith('/community') &&
          !AppEnvironment.communityConfigured) {
        return '/settings';
      }
      return deepLinkRoute;
    },
    routes: [
      GoRoute(path: '/startup', builder: (_, _) => const StartupPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(
        path: '/reviewer-login',
        builder: (_, _) => const StoreReviewerLoginPage(),
      ),
      GoRoute(
        path: '/auth-callback',
        builder: (_, state) => AuthCallbackPage(
          initiallyFailed: state.uri.queryParameters['failed'] == '1',
        ),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, _) => const ResetPasswordPage(),
      ),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(
        path: '/verify-email',
        builder: (_, state) => VerifyEmailPage(
          email: state.extra is String ? state.extra! as String : '',
        ),
      ),
      GoRoute(
        path: '/account-gateway',
        builder: (_, _) => const AccountGatewayPage(),
      ),
      GoRoute(
        path: '/account-data-conflict',
        builder: (_, _) => const AccountDataConflictPage(),
      ),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
      GoRoute(
        path: '/daily-check-in',
        builder: (_, _) => const DailyCheckInPage(),
      ),
      GoRoute(path: '/context', builder: (_, _) => const LifeContextPage()),
      GoRoute(
        path: '/decision-memory',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.decisionMemory,
          child: DecisionMemoryPage(),
        ),
      ),
      GoRoute(
        path: '/plan',
        builder: (_, state) => PremiumRouteGlassGate(
          feature: PremiumGateFeature.personalPlan,
          child: PlanPage(
            pathwayId: state.uri.queryParameters['pathway'],
            origin: PlanPageOrigin.fromQuery(
              state.uri.queryParameters['origin'],
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/experiments',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.experiments,
          child: ExperimentsPage(),
        ),
      ),
      GoRoute(
        path: '/share-studio',
        builder: (_, _) => const ShareStudioPage(),
      ),
      GoRoute(path: '/challenges', builder: (_, _) => const ChallengesPage()),
      GoRoute(
        path: '/profile-summary',
        builder: (_, _) => const ProfileSummaryPage(),
      ),
      GoRoute(
        path: '/profile-settings',
        builder: (_, _) => const PremiumProfilePage(),
      ),
      GoRoute(
        path: '/advanced-body-measurements',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.bodyMeasurements,
          child: ProfileSettingsPage(),
        ),
      ),
      GoRoute(
        path: '/connected-health',
        builder: (_, _) => const ConnectedHealthPage(),
      ),
      GoRoute(
        path: '/connected-health/steps',
        builder: (_, _) => const StepsSettingsPage(),
      ),
      GoRoute(
        path: '/connected-health/heart',
        builder: (_, _) => const ConnectedHealthSignalDetailPage(
          keys: ['heartRate', 'restingHeartRate'],
          title: 'Heart rate',
          unitFallback: 'bpm',
        ),
      ),
      GoRoute(
        path: '/connected-health/capabilities',
        builder: (_, _) => const PartnerCapabilitiesPage(),
      ),
      GoRoute(
        path: '/plans',
        builder: (_, state) =>
            BilStorePlansPage(initialFocus: state.uri.queryParameters['focus']),
      ),
      GoRoute(
        path: '/premium-logging-intro',
        builder: (_, _) => const PremiumLoggingIntroPage(),
      ),
      GoRoute(
        path: '/nutrition-plans',
        builder: (_, _) => const NutritionPathwaysPage(),
      ),
      GoRoute(
        path: '/nutrition-plans/:pathwayId',
        builder: (_, state) {
          final pathwayId = state.pathParameters['pathwayId']!;
          return NutritionPathwayAccessGate(
            pathwayId: pathwayId,
            child: DietPlanEditorPage(pathwayId: pathwayId),
          );
        },
      ),
      GoRoute(
        path: '/weekly-report',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.weeklyReport,
          child: WeeklyReportPage(),
        ),
      ),
      GoRoute(
        path: '/analytics/nutrition',
        builder: (_, state) => PremiumRouteGlassGate(
          feature: PremiumGateFeature.nutritionAnalytics,
          child: NutritionAnalyticsPage(
            initialTab: switch (state.uri.queryParameters['tab']) {
              'nutrients' => 1,
              'macros' => 2,
              _ => 0,
            },
          ),
        ),
      ),
      GoRoute(
        path: '/community',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.community,
          child: CommunityHubPage(),
        ),
      ),
      GoRoute(
        path: '/community/people',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.community,
          child: CommunityPeoplePage(),
        ),
      ),
      GoRoute(
        path: '/community/notifications',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.community,
          child: CommunityNotificationsPage(),
        ),
      ),
      GoRoute(
        path: '/community/connections',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.community,
          child: CommunityConnectionsPage(),
        ),
      ),
      GoRoute(
        path: '/community/food-review',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.community,
          child: CommunityFoodReviewPage(),
        ),
      ),
      GoRoute(
        path: '/community/profile',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.community,
          child: CommunityProfilePage(),
        ),
      ),
      GoRoute(
        path: '/community/safety',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.community,
          child: CommunitySafetyPage(),
        ),
      ),
      GoRoute(
        path: '/community/chat/:userId',
        builder: (_, state) => PremiumRouteGlassGate(
          feature: PremiumGateFeature.community,
          child: CommunityChatPage(
            userId: state.pathParameters['userId']!,
            displayName: state.extra is String
                ? state.extra! as String
                : state.uri.queryParameters['name'] ?? 'BIL',
          ),
        ),
      ),
      GoRoute(
        path: '/community/messages',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.community,
          child: CommunityMessagesPage(),
        ),
      ),
      GoRoute(
        path: '/community/messages/new',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.community,
          child: NewCommunityMessagePage(),
        ),
      ),
      GoRoute(
        path: '/food-libraries',
        builder: (_, _) => const CatalogPacksPage(),
      ),
      GoRoute(
        path: '/meal-image-guide',
        builder: (_, state) => MealImageGuidePage(
          initialPage:
              int.tryParse(state.uri.queryParameters['step'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/notification-settings',
        builder: (_, _) => const NotificationSettingsPage(),
      ),
      GoRoute(
        path: '/advertising-privacy',
        builder: (_, _) => const AdvertisingPrivacyPage(),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (_, _) =>
            const LegalDocumentPage(document: BilLegalDocument.privacy),
      ),
      GoRoute(
        path: '/legal/terms',
        builder: (_, _) =>
            const LegalDocumentPage(document: BilLegalDocument.terms),
      ),
      GoRoute(
        path: '/legal/health-disclaimer',
        builder: (_, _) => const LegalDocumentPage(
          document: BilLegalDocument.healthDisclaimer,
        ),
      ),
      GoRoute(
        path: '/wellness-library',
        builder: (_, _) => const WellnessLibraryPage(),
      ),
      GoRoute(
        path: '/wellness/learn',
        builder: (_, _) => const WellnessLearnPage(),
      ),
      GoRoute(
        path: '/wellness/sleep',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.sleep,
          child: SleepTrackerPage(),
        ),
      ),
      GoRoute(
        path: '/wellness/workouts',
        builder: (_, state) => BilWorkoutRoutinesPage(
          initialItemId: state.uri.queryParameters['item'],
        ),
      ),
      GoRoute(
        path: '/wellness/workouts/routines',
        builder: (_, state) => BilWorkoutRoutinesPage(
          initialItemId: state.uri.queryParameters['item'],
        ),
      ),
      GoRoute(
        path: '/wellness/workouts/log',
        builder: (_, state) => WorkoutLibraryPage(
          initialCategory: state.uri.queryParameters['category'],
        ),
      ),
      GoRoute(
        path: '/wellness/fasting',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.fasting,
          child: FastingTimerPage(),
        ),
      ),
      GoRoute(
        path: '/wellness/recipes',
        builder: (_, state) => RecipeLibraryPage(
          initialRecipeId: state.uri.queryParameters['recipe'],
        ),
      ),
      GoRoute(
        path: '/nutrition/recipes/import',
        builder: (_, state) => PremiumRouteGlassGate(
          feature: PremiumGateFeature.recipeImport,
          child: TrustedRecipeImportPage(
            recipeId: state.uri.queryParameters['recipeId'],
          ),
        ),
      ),
      GoRoute(
        path: '/meal-planner',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.mealPlanner,
          child: MealPlannerPage(),
        ),
      ),
      GoRoute(
        path: '/wellness/content-packs',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.contentPacks,
          child: WellnessContentPacksPage(),
        ),
      ),
      GoRoute(
        path: '/location-settings',
        builder: (_, _) => const LocationSettingsPage(),
      ),
      GoRoute(
        path: '/trust-support',
        builder: (_, _) => const TrustSupportPage(),
      ),
      GoRoute(path: '/help', builder: (_, _) => const HelpCenterPage()),
      GoRoute(path: '/help/faq', builder: (_, _) => const HelpFaqPage()),
      GoRoute(
        path: '/help/delete-account',
        builder: (_, _) => const AccountDeletionPage(),
      ),
      GoRoute(
        path: '/settings/analytics',
        builder: (_, _) => const AnalyticsPage(showSettingsBack: true),
      ),
      GoRoute(
        path: '/settings/diary',
        builder: (_, _) => const ReferenceDiarySettingsPage(),
      ),
      GoRoute(
        path: '/settings/diary/search-tab',
        builder: (_, _) => const ReferenceDiarySearchTabPage(),
      ),
      GoRoute(
        path: '/settings/diary/sharing',
        builder: (_, _) => const ReferenceDiarySharingPage(),
      ),
      GoRoute(
        path: '/settings/diary/meal-names',
        builder: (_, _) => const ReferenceMealNamesPage(),
      ),
      GoRoute(
        path: '/settings/email',
        builder: (_, _) => const ReferenceEmailSettingsPage(),
      ),
      GoRoute(
        path: '/settings/account-email',
        builder: (_, _) => const AccountEmailPage(),
      ),
      GoRoute(
        path: '/settings/account-password',
        builder: (_, _) => const AccountPasswordPage(),
      ),
      if (AppEnvironment.facebookLoginEnabled)
        GoRoute(
          path: '/settings/account-connections/facebook',
          builder: (_, _) => const AccountConnectionSettingsPage(
            provider: AccountConnectionProvider.facebook,
          ),
        ),
      GoRoute(
        path: '/settings/account-connections/google',
        builder: (_, _) => const AccountConnectionSettingsPage(
          provider: AccountConnectionProvider.google,
        ),
      ),
      GoRoute(
        path: '/settings/units',
        builder: (_, _) => const ReferenceUnitPreferencesPage(),
      ),
      GoRoute(
        path: '/settings/appearance',
        builder: (_, _) => const ReferenceAppearancePage(),
      ),
      GoRoute(path: '/goals', builder: (_, _) => const ReferenceGoalsPage()),
      GoRoute(
        path: '/settings/nutrition-goals',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.personalPlan,
          child: ReferenceNutritionGoalsPage(),
        ),
      ),
      GoRoute(
        path: '/settings/nutrition-goal-schedule',
        builder: (_, _) => const NutritionGoalSchedulePage(),
      ),
      GoRoute(
        path: '/settings/nutrition-meal-calorie-goals',
        builder: (_, _) => const MealCalorieGoalsPage(),
      ),
      GoRoute(
        path: '/settings/diary/macro-display',
        builder: (_, _) => const MealMacroDisplayPage(),
      ),
      GoRoute(
        path: '/settings/exercise-calories',
        builder: (_, _) => const VerifiedPremiumFeatureGate(
          title: 'Exercise calories',
          child: ExerciseCalorieSettingsPage(),
        ),
      ),
      GoRoute(
        path: '/settings/preferences',
        builder: (_, _) => const ReferenceSettingsHomePage(),
      ),
      GoRoute(
        path: '/settings/language',
        builder: (_, _) => const LanguageSettingsPage(),
      ),
      GoRoute(
        path: '/settings/sharing-privacy',
        builder: (_, _) => const SharingPrivacySettingsPage(),
      ),
      GoRoute(
        path: '/settings/local-export',
        builder: (_, state) {
          DateTime? parse(String key) =>
              DateTime.tryParse(state.uri.queryParameters[key] ?? '');
          return LocalExportRangePage(
            initialFrom: parse('from'),
            initialTo: parse('to'),
          );
        },
      ),
      GoRoute(
        path: '/admin/ai-coach',
        builder: (_, _) => const AiCoachAdminPage(),
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
              initialAction: state.uri.queryParameters['action'],
              returnPath: _safeDailyReturnPath(
                state.uri.queryParameters['from'],
              ),
            ),
          ),
          GoRoute(
            path: '/daily-log/body-context',
            builder: (_, state) => DailyBodyContextPage(
              returnPath: _safeDailyReturnPath(
                state.uri.queryParameters['from'],
              ),
            ),
          ),
          GoRoute(
            path: '/daily-log/water',
            builder: (_, state) => DailyWaterPage(
              returnPath: _safeDailyReturnPath(
                state.uri.queryParameters['from'],
              ),
            ),
          ),
          GoRoute(
            path: '/intelligence-center',
            builder: (_, state) => PremiumRouteGlassGate(
              feature: PremiumGateFeature.aiCoach,
              child: IntelligenceCenterPage(
                startWithVisionCapture:
                    state.uri.queryParameters['vision'] == 'capture',
                initialBarcode: state.uri.queryParameters['barcode'],
              ),
            ),
          ),
          GoRoute(
            path: '/settings/ai-coach',
            builder: (_, _) => const AiCoachSettingsPage(),
          ),
          GoRoute(
            path: '/nutrition',
            builder: (_, _) => const MealsRecipesFoodsPage(),
          ),
          GoRoute(path: '/foods', builder: (_, _) => const FoodPage()),
          GoRoute(path: '/history', builder: (_, _) => const ProgressPage()),
          GoRoute(
            path: '/weight-history',
            builder: (_, _) => const HistoryPage(),
          ),
          GoRoute(path: '/analytics', builder: (_, _) => const AnalyticsPage()),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
        ],
      ),
      GoRoute(
        path: '/dashboard/preferences',
        builder: (_, _) => const DashboardPreferencesPage(),
      ),
    ],
  );
}
