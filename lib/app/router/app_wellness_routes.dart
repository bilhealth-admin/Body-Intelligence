part of 'app_router.dart';

List<RouteBase> _wellnessRoutes() => <RouteBase>[
  GoRoute(
    path: '/wellness-library',
    builder: (_, _) => const WellnessLibraryPage(),
  ),
  GoRoute(
    path: '/wellness/sleep',
    builder: (_, _) => const PremiumRouteGlassGate(
      feature: PremiumGateFeature.sleep,
      child: BilFeatureEntrySplashGate(
        kind: BilFeatureEntryKind.sleep,
        child: SleepTrackerPage(),
      ),
    ),
  ),
  GoRoute(
    path: '/wellness/workouts',
    builder: (_, state) => BilFeatureEntrySplashGate(
      kind: BilFeatureEntryKind.videos,
      child: BilWorkoutRoutinesPage(
        initialItemId: state.uri.queryParameters['item'],
      ),
    ),
  ),
  GoRoute(
    path: '/wellness/workouts/routines',
    builder: (_, state) => BilFeatureEntrySplashGate(
      kind: BilFeatureEntryKind.videos,
      child: BilWorkoutRoutinesPage(
        initialItemId: state.uri.queryParameters['item'],
      ),
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
    pageBuilder: (_, state) => NoTransitionPage(
      child: BilFeatureEntrySplashGate(
        kind: BilFeatureEntryKind.recipes,
        child: RecipeLibraryPage(
          initialRecipeId: state.uri.queryParameters['recipe'],
        ),
      ),
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
];
