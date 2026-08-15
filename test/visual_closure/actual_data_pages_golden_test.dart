import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/analytics/analytics_page.dart';
import 'package:body_intelligence_log/features/daily_log/daily_log_page.dart';
import 'package:body_intelligence_log/features/daily_check_in/daily_check_in_page.dart';
import 'package:body_intelligence_log/features/dashboard/dashboard_page.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_provider.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/connected_health/widgets/live_health_watch.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/nutrition/food_page.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/food_barcode_scanner_page.dart';
import 'package:body_intelligence_log/features/profile/premium_profile_page.dart';
import 'package:body_intelligence_log/features/settings/settings_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'visual_evidence_font.dart';

final class _UnavailableHealthGateway implements ConnectedHealthGateway {
  const _UnavailableHealthGateway();

  @override
  Future<ConnectedHealthSnapshot> load() async =>
      const ConnectedHealthSnapshot.unavailable();

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

void main() {
  setUpAll(loadVisualEvidenceFont);

  Future<AppDatabase> database(
    WidgetTester tester, {
    bool profile = false,
  }) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    if (profile) {
      await UserProfileRepository(db).save(
        gender: 'male',
        age: 35,
        height: 181,
        currentWeight: 93.4,
        targetWeight: 85,
        activityLevel: 'light',
        exercises: true,
      );
    }
    return db;
  }

  Future<void> capture(
    WidgetTester tester, {
    required Widget page,
    required AppDatabase db,
    required String name,
    bool seedEmptyCatalog = false,
    bool captureTopmostScaffold = false,
    bool captureOverlay = false,
    Future<void> Function(WidgetTester tester)? prepare,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          dashboardClockProvider.overrideWithValue(
            () => DateTime(2026, 8, 5, 9, 41, 12),
          ),
          connectedHealthGatewayProvider.overrideWithValue(
            const _UnavailableHealthGateway(),
          ),
          liveHealthNowProvider.overrideWithValue(
            () => DateTime(2026, 8, 5, 9, 41, 12),
          ),
          if (seedEmptyCatalog)
            seedCatalogProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: visualEvidenceTheme(BilFlagshipTheme.light()),
          builder: (context, child) => visualEvidenceTextSurface(child),
          home: page,
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (prepare != null) {
      await prepare(tester);
      await tester.pumpAndSettle();
    }
    await settleVisualAssetImages(tester);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      captureOverlay
          ? find.byType(Overlay).first
          : captureTopmostScaffold
          ? find.byType(Scaffold).last
          : find.byType(Scaffold).first,
      matchesGoldenFile('goldens/visual_closure_$name.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
  }

  testWidgets('food catalog production empty state capture', (tester) async {
    final db = await database(tester);
    await capture(
      tester,
      page: const FoodPage(),
      db: db,
      name: 'food_catalog_phone',
      seedEmptyCatalog: true,
    );
  });

  testWidgets('custom food production form capture', (tester) async {
    final db = await database(tester);
    await capture(
      tester,
      page: const FoodPage(),
      db: db,
      name: 'custom_food_phone',
      seedEmptyCatalog: true,
      captureOverlay: true,
      prepare: (tester) async {
        await tester.tap(find.text('Custom food').first);
      },
    );
  });

  testWidgets('dashboard production populated phone capture', (tester) async {
    final db = await database(tester, profile: true);
    await capture(
      tester,
      page: const DashboardPage(),
      db: db,
      name: 'dashboard_phone',
    );
  });

  testWidgets('daily log production empty day capture', (tester) async {
    final db = await database(tester);
    await capture(
      tester,
      page: const DailyLogPage(),
      db: db,
      name: 'daily_log_empty_phone',
    );
  });

  testWidgets('daily log meal-entry production capture', (tester) async {
    final db = await database(tester);
    await capture(
      tester,
      page: const DailyLogPage(focusMealEntry: true),
      db: db,
      name: 'daily_log_meal_entry_phone',
    );
  });

  testWidgets('daily log water-entry production capture', (tester) async {
    final db = await database(tester);
    await capture(
      tester,
      page: const DailyLogPage(initialAction: 'water'),
      db: db,
      name: 'daily_log_water_entry_phone',
      prepare: (tester) async {
        final waterSection = find.byKey(const Key('daily-log-water-section'));
        for (
          var attempt = 0;
          attempt < 4 && waterSection.evaluate().isEmpty;
          attempt++
        ) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -520),
          );
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(waterSection);
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('meal-photo truthful unavailable production capture', (
    tester,
  ) async {
    final db = await database(tester);
    await capture(
      tester,
      page: const DailyLogPage(initialAction: 'photo'),
      db: db,
      name: 'meal_photo_unavailable_phone',
      captureOverlay: true,
    );
  });

  testWidgets('barcode scanner truthful unavailable production capture', (
    tester,
  ) async {
    final db = await database(tester);
    await capture(
      tester,
      page: const FoodBarcodeScannerPage(scannerEnabled: false),
      db: db,
      name: 'barcode_unavailable_phone',
    );
  });

  testWidgets('analytics production empty state capture', (tester) async {
    final db = await database(tester);
    await capture(
      tester,
      page: const AnalyticsPage(),
      db: db,
      name: 'analytics_empty_phone',
    );
  });

  testWidgets('analytics production recorded trend capture', (tester) async {
    final db = await database(tester, profile: true);
    final weights = WeightRepository(db);
    final now = DateTime.now();
    for (var day = 28; day >= 0; day -= 4) {
      await weights.addWeight(
        96 - ((28 - day) * 0.09),
        date: now.subtract(Duration(days: day)),
      );
    }
    await capture(
      tester,
      page: const AnalyticsPage(),
      db: db,
      name: 'analytics_progress_phone',
    );
  });

  testWidgets('profile production populated state capture', (tester) async {
    final db = await database(tester, profile: true);
    await capture(
      tester,
      page: const PremiumProfilePage(),
      db: db,
      name: 'profile_phone',
    );
  });

  testWidgets('profile goals production lower section capture', (tester) async {
    final db = await database(tester, profile: true);
    await capture(
      tester,
      page: const PremiumProfilePage(),
      db: db,
      name: 'profile_goals_phone',
      prepare: (tester) async {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -620));
      },
    );
  });

  testWidgets('settings production phone capture', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = await database(tester, profile: true);
    await capture(
      tester,
      page: const SettingsPage(),
      db: db,
      name: 'settings_phone',
    );
  });

  testWidgets('daily check-in production phone capture', (tester) async {
    final db = await database(tester, profile: true);
    await capture(
      tester,
      page: const DailyCheckInPage(),
      db: db,
      name: 'daily_check_in_phone',
    );
  });
}
