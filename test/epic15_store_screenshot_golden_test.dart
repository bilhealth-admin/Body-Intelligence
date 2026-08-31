import 'dart:typed_data';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/analytics/analytics_page.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_page.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_provider.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'visual_closure/visual_evidence_font.dart';

final class _StoreHealthGateway implements ConnectedHealthGateway {
  const _StoreHealthGateway();

  @override
  Future<ConnectedHealthSnapshot> load() async => const ConnectedHealthSnapshot(
    status: ConnectedHealthStatus.permissionDenied,
    platformSource: 'Health Connect',
    availableSources: ['Health Connect'],
    signals: [],
    importedCount: 0,
    lastSyncAt: null,
    failureCode: 'permission_denied',
  );

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
          analyticsClockProvider.overrideWithValue(
            () => DateTime(2026, 8, 30, 9, 41, 12),
          ),
          selectedLogDateProvider.overrideWith(
            (ref) => DateTime(2026, 8, 30, 9, 41, 12),
          ),
          premiumProfileClockProvider.overrideWithValue(
            () => DateTime(2026, 8, 30, 9, 41, 12),
          ),
          liveHealthNowProvider.overrideWithValue(
            () => DateTime(2026, 8, 5, 9, 41, 12),
          ),
          connectedHealthGatewayProvider.overrideWithValue(
            const _StoreHealthGateway(),
          ),
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
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/epic15_$name.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await db.close();
  }

  const devices = <(String, Size)>[
    ('iphone_69', Size(1290, 2796)),
    ('android_phone', Size(1080, 1920)),
  ];

  for (final device in devices) {
    testWidgets('${device.$1} English flagship store screenshots', (
      tester,
    ) async {
      const locale = Locale('en');
      final strictComparator = goldenFileComparator;
      goldenFileComparator = _OnboardingEdgeGoldenComparator(
        Uri.file('test/epic15_store_screenshot_golden_test.dart'),
      );
      try {
        await capture(
          tester,
          page: const OnboardingPage(),
          name: '${device.$1}_en_00_onboarding',
          physicalSize: device.$2,
          locale: locale,
        );
      } finally {
        goldenFileComparator = strictComparator;
      }
      await capture(
        tester,
        page: const DashboardPage(),
        name: '${device.$1}_en_01_dashboard',
        physicalSize: device.$2,
        locale: locale,
      );
      await capture(
        tester,
        page: const DailyLogPage(focusMealEntry: true),
        name: '${device.$1}_en_02_daily_log',
        physicalSize: device.$2,
        locale: locale,
      );
      await capture(
        tester,
        page: const FoodPage(),
        name: '${device.$1}_en_025_food_search',
        physicalSize: device.$2,
        locale: locale,
      );
      await capture(
        tester,
        page: const AnalyticsPage(),
        name: '${device.$1}_en_03_progress',
        physicalSize: device.$2,
        locale: locale,
        trends: true,
      );
      await capture(
        tester,
        page: const BilStorePlansPage(connectToDeviceStore: false),
        name: '${device.$1}_en_04_plans',
        physicalSize: device.$2,
        locale: locale,
      );
      await capture(
        tester,
        page: const ConnectedHealthPage(),
        name: '${device.$1}_en_05_connected_health',
        physicalSize: device.$2,
        locale: locale,
      );
      await capture(
        tester,
        page: const SettingsPage(),
        name: '${device.$1}_en_06_privacy_settings',
        physicalSize: device.$2,
        locale: locale,
        brightness: Brightness.dark,
      );
      if (device.$1 == 'iphone_69') {
        await capture(
          tester,
          page: const WeeklyReportPage(),
          name: '${device.$1}_en_07_weekly_report',
          physicalSize: device.$2,
          locale: locale,
          trends: true,
        );
        await capture(
          tester,
          page: const NutritionPathwaysPage(),
          name: '${device.$1}_en_08_nutrition_pathways',
          physicalSize: device.$2,
          locale: locale,
        );
      }
    });

    testWidgets('${device.$1} Arabic RTL store screenshots', (tester) async {
      const locale = Locale('ar');
      await capture(
        tester,
        page: const OnboardingPage(),
        name: '${device.$1}_ar_00_onboarding',
        physicalSize: device.$2,
        locale: locale,
      );
      await capture(
        tester,
        page: const DashboardPage(),
        name: '${device.$1}_ar_01_dashboard',
        physicalSize: device.$2,
        locale: locale,
      );
      await capture(
        tester,
        page: const DailyLogPage(focusMealEntry: true),
        name: '${device.$1}_ar_02_daily_log',
        physicalSize: device.$2,
        locale: locale,
      );
      await capture(
        tester,
        page: const FoodPage(),
        name: '${device.$1}_ar_025_food_search',
        physicalSize: device.$2,
        locale: locale,
      );
      await capture(
        tester,
        page: const AnalyticsPage(),
        name: '${device.$1}_ar_03_progress_dark',
        physicalSize: device.$2,
        locale: locale,
        brightness: Brightness.dark,
        trends: true,
      );
      await capture(
        tester,
        page: const BilStorePlansPage(connectToDeviceStore: false),
        name: '${device.$1}_ar_04_plans',
        physicalSize: device.$2,
        locale: locale,
      );
      await capture(
        tester,
        page: const WeeklyReportPage(),
        name: '${device.$1}_ar_05_weekly_report',
        physicalSize: device.$2,
        locale: locale,
        trends: true,
      );
      await capture(
        tester,
        page: const ConnectedHealthPage(),
        name: '${device.$1}_ar_06_connected_health',
        physicalSize: device.$2,
        locale: locale,
      );
      if (device.$1 == 'iphone_69') {
        await capture(
          tester,
          page: const PremiumProfilePage(),
          name: '${device.$1}_ar_07_profile',
          physicalSize: device.$2,
          locale: locale,
        );
        await capture(
          tester,
          page: const SettingsPage(),
          name: '${device.$1}_ar_08_privacy_settings_dark',
          physicalSize: device.$2,
          locale: locale,
          brightness: Brightness.dark,
        );
      }
    });
  }

  for (final languageCode in ['fr', 'es', 'tr']) {
    testWidgets('localized $languageCode store plan screenshots', (
      tester,
    ) async {
      await capture(
        tester,
        page: const BilStorePlansPage(connectToDeviceStore: false),
        name: 'iphone_69_${languageCode}_plans',
        physicalSize: const Size(1290, 2796),
        locale: Locale(languageCode),
      );
      await capture(
        tester,
        page: const BilStorePlansPage(connectToDeviceStore: false),
        name: 'android_phone_${languageCode}_plans',
        physicalSize: const Size(1080, 1920),
        locale: Locale(languageCode),
      );
    });
  }

  testWidgets('real recipe and workout library evidence captures', (
    tester,
  ) async {
    const size = Size(1080, 1920);
    const locale = Locale('en');
    await capture(
      tester,
      page: const WellnessLibraryPage(),
      name: 'evidence_en_recipe_library',
      physicalSize: size,
      locale: locale,
    );
    await capture(
      tester,
      page: const WellnessLibraryPage(),
      name: 'evidence_en_workout_library',
      physicalSize: size,
      locale: locale,
      afterPump: (tester) async {
        await tester.drag(find.byType(PageView), const Offset(-900, 0));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(PageView), const Offset(-900, 0));
        await tester.pumpAndSettle();
      },
    );
  });
}
