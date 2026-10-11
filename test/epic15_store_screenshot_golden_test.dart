import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/analytics/analytics_page.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_engine.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_page.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_page.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/connected_health/widgets/live_health_watch.dart';
import 'package:body_intelligence_log/features/daily_log/daily_log_page.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/dashboard/dashboard_page.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_provider.dart';
import 'package:body_intelligence_log/features/nutrition/food_page.dart';
import 'package:body_intelligence_log/features/nutrition_plans/presentation/nutrition_pathways_page.dart';
import 'package:body_intelligence_log/features/onboarding/onboarding_page.dart';
import 'package:body_intelligence_log/features/profile/premium_profile_page.dart';
import 'package:body_intelligence_log/features/settings/settings_page.dart';
import 'package:body_intelligence_log/features/wellness/presentation/wellness_library_page.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'visual_closure/visual_evidence_font.dart';

// Protected Food, More, and Progress store captures share a single
// server-verified Free member. Without that evidence, the UI correctly
// fails closed to Retry rather than showing the reviewed Premium preview.
// This affects only the screenshot fixture, never production entitlements.
final _visualVerifiedFree = SubscriptionState(
  plan: CommercePlan.free,
  entitlements: FreePlan.entitlements,
  authority: EntitlementAuthority.verifiedServer,
  lifecycle: SubscriptionLifecycle.inactive,
  isPurchasable: true,
  canRestorePurchases: true,
);

final class _StoreHealthGateway implements ConnectedHealthGateway {
  const _StoreHealthGateway();

  @override
  Future<ConnectedHealthSnapshot> load() async {
    final platformSource = defaultTargetPlatform == TargetPlatform.iOS
        ? 'Apple Health'
        : 'Health Connect';
    return ConnectedHealthSnapshot(
      status: ConnectedHealthStatus.permissionDenied,
      platformSource: platformSource,
      availableSources: [platformSource],
      signals: const [],
      importedCount: 0,
      lastSyncAt: null,
      failureCode: 'permission_denied',
    );
  }

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<ConnectedHealthSnapshot> requestPermissions() => load();

  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() => load();

  @override
  Future<ConnectedHealthSnapshot> revokePermissions() => load();

  @override
  Future<ConnectedHealthSnapshot> synchronize() => load();
}

final _storeWeeklyReport = const WeeklyReportEngine().build(
  asOf: DateTime.utc(2026, 8, 4),
  mealCount: 4,
  nutrition: const [
    WeeklyNutritionObservation(
      dayKey: '2026-08-01',
      calories: 1850,
      proteinG: 118,
      carbsG: 205,
      fatG: 62,
      sodiumMg: 2100,
      foodCategory: 'vegetable',
      foodName: 'Roasted vegetables',
    ),
    WeeklyNutritionObservation(
      dayKey: '2026-08-03',
      calories: 1720,
      proteinG: 126,
      carbsG: 188,
      fatG: 58,
      sodiumMg: 1900,
      foodCategory: 'protein',
      foodName: 'Grilled chicken',
    ),
    WeeklyNutritionObservation(
      dayKey: '2026-08-03',
      calories: 120,
      proteinG: 1,
      carbsG: 28,
      fatG: 0,
      sodiumMg: 4,
      foodCategory: 'fruit',
      foodName: 'Fresh berries',
    ),
    WeeklyNutritionObservation(
      dayKey: '2026-08-04',
      calories: 210,
      proteinG: 4,
      carbsG: 31,
      fatG: 8,
      sodiumMg: 160,
      foodCategory: 'snack',
      foodName: 'Yogurt snack',
    ),
  ],
  water: const [
    WeeklyWaterObservation(dayKey: '2026-08-01', amountMl: 2200),
    WeeklyWaterObservation(dayKey: '2026-08-03', amountMl: 2500),
  ],
  weights: [
    WeeklyWeightObservation(
      dayKey: '2026-08-01',
      observedAt: DateTime.utc(2026, 8, 1),
      weightKg: 93.4,
    ),
    WeeklyWeightObservation(
      dayKey: '2026-08-04',
      observedAt: DateTime.utc(2026, 8, 4),
      weightKg: 92.8,
    ),
  ],
  activity: const [
    WeeklyActivityObservation(
      dayKey: '2026-08-01',
      steps: 8420,
      exerciseNotes: 'Strength workout',
    ),
    WeeklyActivityObservation(dayKey: '2026-08-03', steps: 10120),
  ],
  allTimeMealCount: 4,
  allTimeWeightCount: 2,
  allTimeExerciseDays: 1,
  allTimeSteps: 18540,
  dailyCalorieGoal: 2100,
  loggingStreakDays: 4,
);

/// Limits renderer edge tolerance to the single onboarding store capture.
///
/// The 2048x1280 starfield is scaled to the iPhone 6.9 logical viewport and
/// Skia can include or omit the final filtered source row. That affects only
/// the clipped bottom glow (307 pixels / 0.08%) and not page geometry, copy,
/// controls, or content. Every other Epic 15 golden remains pixel-exact.
final class _OnboardingEdgeGoldenComparator extends LocalFileComparator {
  _OnboardingEdgeGoldenComparator(super.testFile);

  static const _precisionTolerance = 0.001;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    final passed = result.passed || result.diffPercent <= _precisionTolerance;
    if (passed) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

void main() {
  setUpAll(() async {
    // This suite intentionally owns several independent in-memory databases
    // while Flutter schedules its screenshot cases. They never share a
    // QueryExecutor, so Drift's process-wide duplicate-instance warning is
    // noise here rather than a corruption risk.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await loadVisualEvidenceFont();
  });
  tearDownAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
  });

  Future<AppDatabase> seededDatabase({bool trends = false}) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await UserProfileRepository(db).save(
      gender: 'male',
      age: 35,
      height: 181,
      currentWeight: 93.4,
      targetWeight: 85,
      activityLevel: 'light',
      exercises: true,
    );
    await PreferencesRepository(db).set('timezoneName', 'Egypt Daylight Time');
    if (trends) {
      final weights = WeightRepository(db);
      final now = DateTime(2026, 8, 5);
      for (var day = 28; day >= 0; day -= 4) {
        await weights.addWeight(
          96 - ((28 - day) * 0.09),
          date: now.subtract(Duration(days: day)),
        );
      }
    }
    return db;
  }

  Future<void> capture(
    WidgetTester tester, {
    required Widget page,
    required String name,
    required Size physicalSize,
    required Locale locale,
    Brightness brightness = Brightness.light,
    bool trends = false,
    Future<void> Function(WidgetTester tester)? afterPump,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final db = await seededDatabase(trends: trends);
    // Store screenshots show a returning user. First-use onboarding has its
    // own explicit widget tests, so it must not obscure Home references.
    if (page is DashboardPage) {
      await PreferencesRepository(
        db,
      ).set('experience.dashboard_food_guide.v1.local', 'dismissed');
    }
    tester.view.physicalSize = physicalSize;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final isArabic = locale.languageCode == 'ar';
    final theme = brightness == Brightness.dark
        ? BilFlagshipTheme.dark(isArabic: isArabic)
        : BilFlagshipTheme.light(isArabic: isArabic);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          dashboardClockProvider.overrideWithValue(
            () => DateTime(2026, 8, 5, 9, 41, 12),
          ),
          weeklyReportClockProvider.overrideWithValue(
            () => DateTime(2026, 8, 5, 9, 41, 12),
          ),
          weeklyReportProvider.overrideWith((ref) async => _storeWeeklyReport),
          analyticsClockProvider.overrideWithValue(
            () => DateTime(2026, 8, 30, 9, 41, 12),
          ),
          selectedLogDateProvider.overrideWith(
            (ref) => DateTime(2026, 8, 30, 9, 41, 12),
          ),
          premiumProfileClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 8, 30, 9, 41, 12),
          ),
          liveHealthNowProvider.overrideWithValue(
            () => DateTime(2026, 8, 5, 9, 41, 12),
          ),
          connectedHealthGatewayProvider.overrideWithValue(
            const _StoreHealthGateway(),
          ),
          if (page is DailyLogPage ||
              page is FoodPage ||
              page is SettingsPage ||
              page is AnalyticsPage) ...[
            verifiedEntitlementClockProvider.overrideWithValue(
              () => DateTime.utc(2026, 8, 30, 9, 41, 12),
            ),
            verifiedSubscriptionStateProvider.overrideWithValue(
              AsyncData(_visualVerifiedFree),
            ),
          ],
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: visualEvidenceTheme(
            theme,
            fontFamily: isArabic ? 'NotoArabicEvidence' : 'RobotoEvidence',
          ),
          builder: (context, child) => visualEvidenceTextSurface(
            child,
            fontFamily: isArabic ? 'NotoArabicEvidence' : 'RobotoEvidence',
          ),
          home: page,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await settleVisualAssetImages(tester);
    await tester.pumpAndSettle();
    if (afterPump != null) {
      await afterPump(tester);
      await settleVisualAssetImages(tester);
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    if (page is DashboardPage) {
      expect(
        find.byKey(const Key('dashboard-guide-skip')),
        findsNothing,
        reason: 'Returning member cannot be captured with first-use help.',
      );
    }
    try {
      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile('goldens/epic15_$name.png'),
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await db.close();
    }
  }

  // Each image runs as an independent strict Golden test. Previously the
  // first failure concealed subsequent captures in the same device group.
  void registerSnapshot({
    required String name,
    required Widget page,
    required Size physicalSize,
    required Locale locale,
    TargetPlatform? platform,
    Brightness brightness = Brightness.light,
    bool trends = false,
    bool onboardingEdge = false,
    Future<void> Function(WidgetTester tester)? afterPump,
  }) {
    testWidgets('store snapshot $name', (tester) async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      final previousComparator = goldenFileComparator;
      if (platform != null) {
        debugDefaultTargetPlatformOverride = platform;
      }
      try {
        if (onboardingEdge) {
          goldenFileComparator = _OnboardingEdgeGoldenComparator(
            Uri.file('test/epic15_store_screenshot_golden_test.dart'),
          );
        }
        await capture(
          tester,
          page: page,
          name: name,
          physicalSize: physicalSize,
          locale: locale,
          brightness: brightness,
          trends: trends,
          afterPump: afterPump,
        );
      } finally {
        goldenFileComparator = previousComparator;
        debugDefaultTargetPlatformOverride = previousPlatform;
      }
    });
  }

  registerSnapshot(
    name: 'iphone_69_en_00_onboarding',
    page: const OnboardingPage(),
    physicalSize: const Size(1290, 2796),
    locale: const Locale('en'),
    platform: TargetPlatform.iOS,
    onboardingEdge: true,
  );
  registerSnapshot(
    name: 'iphone_69_en_01_dashboard',
    page: const DashboardPage(),
    physicalSize: const Size(1290, 2796),
    locale: const Locale('en'),
    platform: TargetPlatform.iOS,
  );
  registerSnapshot(
    name: 'iphone_69_en_02_daily_log',
    page: const DailyLogPage(focusMealEntry: true),
    physicalSize: const Size(1290, 2796),
    locale: const Locale('en'),
    platform: TargetPlatform.iOS,
  );
  registerSnapshot(
    name: 'iphone_69_en_025_food_search',
    page: const FoodPage(),
    physicalSize: const Size(1290, 2796),
    locale: const Locale('en'),
    platform: TargetPlatform.iOS,
  );
  registerSnapshot(
    name: 'iphone_69_en_03_progress',
    page: const AnalyticsPage(),
    physicalSize: const Size(1290, 2796),
    locale: const Locale('en'),
    platform: TargetPlatform.iOS,
    trends: true,
  );
  registerSnapshot(
    name: 'iphone_69_en_04_plans',
    page: const BilStorePlansPage(connectToDeviceStore: false),
    physicalSize: const Size(1290, 2796),
    locale: const Locale('en'),
    platform: TargetPlatform.iOS,
  );
  registerSnapshot(
    name: 'iphone_69_en_05_connected_health',
    page: const ConnectedHealthPage(),
    physicalSize: const Size(1290, 2796),
    locale: const Locale('en'),
    platform: TargetPlatform.iOS,
  );
  registerSnapshot(
    name: 'iphone_69_en_06_privacy_settings',
    page: const SettingsPage(),
    physicalSize: const Size(1290, 2796),
    locale: const Locale('en'),
    platform: TargetPlatform.iOS,
    brightness: Brightness.dark,
  );
  registerSnapshot(
    name: 'iphone_69_en_07_weekly_report',
    page: const WeeklyReportPage(),
    physicalSize: const Size(1290, 2796),
    locale: const Locale('en'),
    platform: TargetPlatform.iOS,
    trends: true,
  );
  registerSnapshot(
    name: 'iphone_69_en_08_nutrition_pathways',
    page: const NutritionPathwaysPage(),
    physicalSize: const Size(1290, 2796),
    locale: const Locale('en'),
    platform: TargetPlatform.iOS,
  );
  registerSnapshot(
    name: 'iphone_69_ar_00_onboarding',
    page: const OnboardingPage(),
    physicalSize: const Size(1290, 2796),
    locale: const Locale('ar'),
    platform: TargetPlatform.iOS,
  );
  registerSnapshot(
    name: 'iphone_69_ar_01_dashboard',
    page: const DashboardPage(),
    physicalSize: const Size(1290, 2796),
    locale: const Locale('ar'),
    platform: TargetPlatform.iOS,
  );
  registerSnapshot(
    name: 'iphone_69_ar_02_daily_log',
    page: const DailyLogPage(focusMealEntry: true),
    physicalSize: const Size(1290, 2796),
    locale: const Locale('ar'),
    platform: TargetPlatform.iOS,
  );
  registerSnapshot(
    name: 'iphone_69_ar_025_food_search',
    page: const FoodPage(),
    physicalSize: const Size(1290, 2796),
    locale: const Locale('ar'),
    platform: TargetPlatform.iOS,
  );
  registerSnapshot(
    name: 'iphone_69_ar_03_progress_dark',
    page: const AnalyticsPage(),
    physicalSize: const Size(1290, 2796),
    locale: const Locale('ar'),
    platform: TargetPlatform.iOS,
    brightness: Brightness.dark,
    trends: true,
  );
  registerSnapshot(
    name: 'iphone_69_ar_04_plans',
    page: const BilStorePlansPage(connectToDeviceStore: false),
    physicalSize: const Size(1290, 2796),
    locale: const Locale('ar'),
    platform: TargetPlatform.iOS,
  );
  registerSnapshot(
    name: 'iphone_69_ar_05_weekly_report',
    page: const WeeklyReportPage(),
    physicalSize: const Size(1290, 2796),
    locale: const Locale('ar'),
    platform: TargetPlatform.iOS,
    trends: true,
  );
  registerSnapshot(
    name: 'iphone_69_ar_06_connected_health',
    page: const ConnectedHealthPage(),
    physicalSize: const Size(1290, 2796),
    locale: const Locale('ar'),
    platform: TargetPlatform.iOS,
  );
  registerSnapshot(
    name: 'iphone_69_ar_07_profile',
    page: const PremiumProfilePage(),
    physicalSize: const Size(1290, 2796),
    locale: const Locale('ar'),
    platform: TargetPlatform.iOS,
  );
  registerSnapshot(
    name: 'iphone_69_ar_08_privacy_settings_dark',
    page: const SettingsPage(),
    physicalSize: const Size(1290, 2796),
    locale: const Locale('ar'),
    platform: TargetPlatform.iOS,
    brightness: Brightness.dark,
  );
  registerSnapshot(
    name: 'android_phone_en_00_onboarding',
    page: const OnboardingPage(),
    physicalSize: const Size(1080, 1920),
    locale: const Locale('en'),
    platform: TargetPlatform.android,
    onboardingEdge: true,
  );
  registerSnapshot(
    name: 'android_phone_en_01_dashboard',
    page: const DashboardPage(),
    physicalSize: const Size(1080, 1920),
    locale: const Locale('en'),
    platform: TargetPlatform.android,
  );
  registerSnapshot(
    name: 'android_phone_en_02_daily_log',
    page: const DailyLogPage(focusMealEntry: true),
    physicalSize: const Size(1080, 1920),
    locale: const Locale('en'),
    platform: TargetPlatform.android,
  );
  registerSnapshot(
    name: 'android_phone_en_025_food_search',
    page: const FoodPage(),
    physicalSize: const Size(1080, 1920),
    locale: const Locale('en'),
    platform: TargetPlatform.android,
  );
  registerSnapshot(
    name: 'android_phone_en_03_progress',
    page: const AnalyticsPage(),
    physicalSize: const Size(1080, 1920),
    locale: const Locale('en'),
    platform: TargetPlatform.android,
    trends: true,
  );
  registerSnapshot(
    name: 'android_phone_en_04_plans',
    page: const BilStorePlansPage(connectToDeviceStore: false),
    physicalSize: const Size(1080, 1920),
    locale: const Locale('en'),
    platform: TargetPlatform.android,
  );
  registerSnapshot(
    name: 'android_phone_en_05_connected_health',
    page: const ConnectedHealthPage(),
    physicalSize: const Size(1080, 1920),
    locale: const Locale('en'),
    platform: TargetPlatform.android,
  );
  registerSnapshot(
    name: 'android_phone_en_06_privacy_settings',
    page: const SettingsPage(),
    physicalSize: const Size(1080, 1920),
    locale: const Locale('en'),
    platform: TargetPlatform.android,
    brightness: Brightness.dark,
  );
  registerSnapshot(
    name: 'android_phone_ar_00_onboarding',
    page: const OnboardingPage(),
    physicalSize: const Size(1080, 1920),
    locale: const Locale('ar'),
    platform: TargetPlatform.android,
  );
  registerSnapshot(
    name: 'android_phone_ar_01_dashboard',
    page: const DashboardPage(),
    physicalSize: const Size(1080, 1920),
    locale: const Locale('ar'),
    platform: TargetPlatform.android,
  );
  registerSnapshot(
    name: 'android_phone_ar_02_daily_log',
    page: const DailyLogPage(focusMealEntry: true),
    physicalSize: const Size(1080, 1920),
    locale: const Locale('ar'),
    platform: TargetPlatform.android,
  );
  registerSnapshot(
    name: 'android_phone_ar_025_food_search',
    page: const FoodPage(),
    physicalSize: const Size(1080, 1920),
    locale: const Locale('ar'),
    platform: TargetPlatform.android,
  );
  registerSnapshot(
    name: 'android_phone_ar_03_progress_dark',
    page: const AnalyticsPage(),
    physicalSize: const Size(1080, 1920),
    locale: const Locale('ar'),
    platform: TargetPlatform.android,
    brightness: Brightness.dark,
    trends: true,
  );
  registerSnapshot(
    name: 'android_phone_ar_04_plans',
    page: const BilStorePlansPage(connectToDeviceStore: false),
    physicalSize: const Size(1080, 1920),
    locale: const Locale('ar'),
    platform: TargetPlatform.android,
  );
  registerSnapshot(
    name: 'android_phone_ar_05_weekly_report',
    page: const WeeklyReportPage(),
    physicalSize: const Size(1080, 1920),
    locale: const Locale('ar'),
    platform: TargetPlatform.android,
    trends: true,
  );
  registerSnapshot(
    name: 'android_phone_ar_06_connected_health',
    page: const ConnectedHealthPage(),
    physicalSize: const Size(1080, 1920),
    locale: const Locale('ar'),
    platform: TargetPlatform.android,
  );
  registerSnapshot(
    name: 'iphone_69_fr_plans',
    page: const BilStorePlansPage(connectToDeviceStore: false),
    physicalSize: const Size(1290, 2796),
    locale: const Locale('fr'),
  );
  registerSnapshot(
    name: 'android_phone_fr_plans',
    page: const BilStorePlansPage(connectToDeviceStore: false),
    physicalSize: const Size(1080, 1920),
    locale: const Locale('fr'),
  );
  registerSnapshot(
    name: 'iphone_69_es_plans',
    page: const BilStorePlansPage(connectToDeviceStore: false),
    physicalSize: const Size(1290, 2796),
    locale: const Locale('es'),
  );
  registerSnapshot(
    name: 'android_phone_es_plans',
    page: const BilStorePlansPage(connectToDeviceStore: false),
    physicalSize: const Size(1080, 1920),
    locale: const Locale('es'),
  );
  registerSnapshot(
    name: 'iphone_69_tr_plans',
    page: const BilStorePlansPage(connectToDeviceStore: false),
    physicalSize: const Size(1290, 2796),
    locale: const Locale('tr'),
  );
  registerSnapshot(
    name: 'android_phone_tr_plans',
    page: const BilStorePlansPage(connectToDeviceStore: false),
    physicalSize: const Size(1080, 1920),
    locale: const Locale('tr'),
  );
  registerSnapshot(
    name: 'evidence_en_recipe_library',
    page: const WellnessLibraryPage(),
    physicalSize: const Size(1080, 1920),
    locale: const Locale('en'),
  );
  registerSnapshot(
    name: 'evidence_en_workout_library',
    page: const WellnessLibraryPage(),
    physicalSize: const Size(1080, 1920),
    locale: const Locale('en'),
    afterPump: (tester) async {
      await tester.drag(find.byType(PageView), const Offset(-900, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(-900, 0));
      await tester.pumpAndSettle();
    },
  );
}
