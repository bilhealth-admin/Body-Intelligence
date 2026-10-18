import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/first_meal_milestone.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/daily_log/daily_log_page.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/daily_log_summary_widgets.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/settings/nutrition_goal_schedule_page.dart';
import 'package:body_intelligence_log/features/settings/premium_meal_features_page.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../visual_closure/closure_surface_capture.dart';
import 'meal_platform_evidence_font.dart';

const _daily = NutritionGoalTarget(
  calories: 2000,
  carbsPercent: 45,
  proteinPercent: 20,
  fatPercent: 35,
);
const _lunch = NutritionGoalTarget(
  calories: 1000,
  carbsPercent: 44,
  proteinPercent: 20,
  fatPercent: 36,
);
const _breakfast = NutritionGoalTarget(
  calories: 400,
  carbsPercent: 50,
  proteinPercent: 20,
  fatPercent: 30,
);
final _date = DateTime(2026, 10, 8);

Future<void> _waitFor(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 100 && !ready(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(ready(), isTrue);
}

void main() {
  late AppDatabase db;
  late PreferencesRepository preferences;
  late NutritionGoalScheduleRepository goals;
  setUpAll(loadMealPlatformEvidenceFont);
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    preferences = PreferencesRepository(db);
    await preferences.set(mealMacroDisplayEnabledKey, 'true');
    // Existing recorded food, without resetting the first-food milestone.
    await preferences.set(firstMealCelebrationPreferenceKey, 'done');
    goals = NutritionGoalScheduleRepository(preferences);
    await goals.saveDay(_date.weekday, _daily);
    await goals.saveMeal('breakfast', _breakfast);
    final foodId = await db
        .into(db.foods)
        .insert(
          FoodsCompanion.insert(
            name: 'Synthetic meal acceptance food',
            arabicName: const Value('غذاء اختبار الوجبة'),
            calories: 200,
            protein: 7.5,
            carbs: 20,
            fats: 10,
            sodium: const Value(200),
            potassium: const Value(450),
            magnesium: const Value(125),
            servingSize: const Value(100),
            servingUnit: const Value('g'),
            isCustom: const Value(true),
            source: const Value('custom'),
            nutrientEvidenceMask: Value(
              NutrientEvidenceMask.fromValues(
                calories: 200,
                protein: 7.5,
                carbohydrates: 20,
                fat: 10,
                sodium: 200,
                potassium: 450,
                magnesium: 125,
              ),
            ),
          ),
        );
    final meals = MealRepository(db);
    for (final type in ['lunch', 'breakfast']) {
      final id = await meals.createMeal(date: _date, name: type, type: type);
      await meals.addMealItem(
        mealId: id,
        foodId: foodId,
        quantity: type == 'lunch' ? 200 : 100,
        quantityInGrams: true,
      );
    }
  });
  tearDown(() => db.close());

  for (final language in ['en', 'ar']) {
    for (final legacy in [false, true]) {
      testWidgets(
        'actual meal goal edit returns to same lunch and date $language legacy=$legacy',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final locale = Locale(language);
          final targetCalories = legacy ? 650 : 1000;
          if (legacy) {
            await tester.runAsync(
              () => preferences.set(mealCalorieGoalKey('lunch'), '650'),
            );
          } else {
            await tester.runAsync(() => goals.saveMeal('lunch', _lunch));
          }
          final capture = GlobalKey();
          final router = GoRouter(
            initialLocation: '/meal?meal=lunch&date=2026-10-08',
            routes: [
              GoRoute(
                path: '/meal',
                builder: (_, _) => const DailyLogPage(
                  initialMealType: 'lunch',
                  focusMealEntry: true,
                ),
              ),
              GoRoute(
                path: '/settings/nutrition-goal-schedule',
                builder: (_, state) => NutritionGoalSchedulePage(
                  initialMeal: state.uri.queryParameters['meal'],
                ),
              ),
              GoRoute(
                path: '/settings/nutrition-meal-calorie-goals',
                builder: (_, state) => MealCalorieGoalsPage(
                  initialMeal: state.uri.queryParameters['meal'],
                ),
              ),
            ],
          );
          addTearDown(router.dispose);
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(seconds: 1));
          });
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWithValue(db),
                preferencesRepositoryProvider.overrideWithValue(preferences),
                nutritionGoalScheduleRepositoryProvider.overrideWithValue(
                  goals,
                ),
                nutritionGoalScheduleProvider.overrideWith(
                  (ref) => goals.watch(),
                ),
                seedCatalogProvider.overrideWith((ref) async {}),
                foodsProvider.overrideWithValue(const AsyncData(<Food>[])),
                mealRepositoryProvider.overrideWithValue(MealRepository(db)),
                dailyWaterProvider.overrideWithValue(
                  const AsyncData(<WaterEntry>[]),
                ),
                selectedDailyLogProvider.overrideWithValue(
                  const AsyncData(null),
                ),
                diaryMealNamesProvider.overrideWithValue(
                  const AsyncData(<String?>[null, null, null, null]),
                ),
                selectedLogDateProvider.overrideWith((ref) => _date),
                userProfileProvider.overrideWithValue(const AsyncData(null)),
                for (final key in [
                  'diary.foodInsights',
                  'diary.showAllMeals',
                  'diary.showFoodTimestamps',
                  'diary.useNetCarbs',
                  'diary.alwaysShowWater',
                ])
                  dailyLogPreferenceProvider(
                    key,
                  ).overrideWithValue(AsyncData(key == 'diary.showAllMeals')),
                measurementSystemProvider.overrideWithValue(
                  const AsyncData(MeasurementSystem.metric),
                ),
                verifiedEntitlementClockProvider.overrideWithValue(
                  () => DateTime.utc(2026, 10, 12),
                ),
                verifiedSubscriptionStateProvider.overrideWithValue(
                  AsyncData(
                    SubscriptionState(
                      plan: CommercePlan.premium,
                      entitlements: const {
                        CommerceEntitlement.advancedIntelligence,
                      },
                      authority: EntitlementAuthority.verifiedServer,
                      isPurchasable: false,
                      canRestorePurchases: true,
                      currentPeriodEndsAt: DateTime.utc(2026, 11, 1),
                    ),
                  ),
                ),
              ],
              child: MaterialApp.router(
                routerConfig: router,
                locale: locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                theme: mealPlatformEvidenceTheme(
                  BilFlagshipTheme.light(isArabic: language == 'ar'),
                ),
                builder: (_, child) =>
                    RepaintBoundary(key: capture, child: child!),
              ),
            ),
          );
          final target = find.byKey(const Key('daily-meal-detail-goal'));
          await _waitFor(
            tester,
            () => find
                .descendant(
                  of: target,
                  matching: find.textContaining('$targetCalories'),
                )
                .evaluate()
                .isNotEmpty,
          );
          expect(
            find.descendant(of: target, matching: find.textContaining('2000')),
            findsNothing,
          );
          expect(
            find.descendant(of: target, matching: find.textContaining('400')),
            findsNothing,
          );
          final macroDials = find.byKey(const Key('daily-meal-detail-macros'));
          final fatDial = find.byKey(const Key('daily-meal-macro-fat'));
          expect(
            tester.getCenter(fatDial).dx,
            closeTo(
              tester.getCenter(find.byKey(const Key('daily-meal-goal-fat'))).dx,
              .1,
            ),
          );
          await _waitFor(
            tester,
            () => find
                .descendant(of: fatDial, matching: find.text('20 g'))
                .evaluate()
                .isNotEmpty,
          );
          expect(
            tester
                .widget<CircularProgressIndicator>(
                  find.descendant(
                    of: fatDial,
                    matching: find.byType(CircularProgressIndicator),
                  ),
                )
                .value,
            legacy ? 0 : .5,
          );
          final ring = tester.widget<DailyLogCalorieMacroRing>(
            find.byType(DailyLogCalorieMacroRing),
          );
          expect(ring.calories, 400);
          expect(ring.calorieGoal, targetCalories);
          final mineralGroup = find.byKey(
            const Key('daily-meal-detail-minerals'),
          );
          for (final value in ['400.0', '900.0', '250.0']) {
            expect(
              find.descendant(of: mineralGroup, matching: find.text(value)),
              findsOneWidget,
            );
          }
          for (final dayTotal in ['600.0', '1350.0', '375.0']) {
            expect(
              find.descendant(of: mineralGroup, matching: find.text(dayTotal)),
              findsNothing,
            );
          }
          if (!legacy) {
            expect(
              find.descendant(of: target, matching: find.textContaining('40')),
              findsOneWidget,
            );
            if (language == 'ar') {
              await captureClosureSurface(
                tester,
                find.byKey(capture),
                'meal-fat-half-20-of-40-ar',
              );
            }
          }
          expect(macroDials, findsOneWidget);
          expect(
            tester
                .getRect(find.byKey(const Key('daily-meal-detail-minerals')))
                .top,
            greaterThan(tester.getRect(macroDials).bottom),
          );
          expect(
            tester.getRect(target).top,
            greaterThan(
              tester
                  .getRect(find.byKey(const Key('daily-meal-detail-minerals')))
                  .bottom,
            ),
          );
          final mealElement = tester.element(find.byType(DailyLogPage));
          final container = ProviderScope.containerOf(mealElement);
          expect(container.read(selectedLogDateProvider), _date);
          final edit = find.byKey(const Key('daily-meal-edit-goal'));
          await Scrollable.ensureVisible(tester.element(edit), alignment: .5);
          await tester.pumpAndSettle();
          expect(edit.hitTestable(), findsOneWidget);
          expect(tester.getSize(edit).shortestSide, greaterThanOrEqualTo(48));
          final press = await tester.startGesture(tester.getCenter(edit));
          await tester.pump();
          expect(
            find.byKey(const Key('bil-glass-press-bubble')),
            findsOneWidget,
          );
          await press.up();
          await tester.pumpAndSettle();
          final settingsPage = legacy
              ? find.byType(MealCalorieGoalsPage)
              : find.byType(NutritionGoalSchedulePage);
          expect(settingsPage, findsOneWidget);
          final destination = GoRouterState.of(
            tester.element(settingsPage),
          ).uri;
          expect(destination.queryParameters['meal'], 'lunch');
          final route = legacy
              ? '/settings/nutrition-meal-calorie-goals'
              : '/settings/nutrition-goal-schedule';
          expect(destination.path, route);
          final tile = find.byKey(
            Key(
              legacy ? 'meal-calorie-goal-lunch' : 'nutrition-meal-goal-lunch',
            ),
          );
          await _waitFor(tester, () => tile.evaluate().isNotEmpty);
          await tester.ensureVisible(tile);
          await tester.pumpAndSettle();
          expect(tester.widget<ListTile>(tile).selected, isTrue);
          await tester.tap(tile);
          await tester.pumpAndSettle();
          final fields = find.byType(TextField);
          expect(fields, findsNWidgets(legacy ? 1 : 4));
          expect(
            NumberFormat.decimalPattern(
              locale.toLanguageTag(),
            ).parse(tester.widget<TextField>(fields.first).controller!.text),
            targetCalories,
          );
          if (legacy) {
            await tester.enterText(fields.first, '800');
          } else {
            for (final entry in ['600', '75', '30', '20'].indexed) {
              await tester.enterText(fields.at(entry.$1), entry.$2);
            }
          }
          await tester.tap(
            find
                .descendant(
                  of: find.bySubtype<AlertDialog>(),
                  matching: find.byType(FilledButton),
                )
                .last,
          );
          await tester.pumpAndSettle();
          final updated = legacy ? 800 : 600;
          await _waitFor(
            tester,
            () => find
                .descendant(
                  of: tile,
                  matching: find.textContaining(
                    legacy
                        ? '$updated'
                        : NumberFormat.decimalPattern(
                            locale.toLanguageTag(),
                          ).format(updated),
                  ),
                )
                .evaluate()
                .isNotEmpty,
          );
          final saved = await tester.runAsync(goals.read);
          expect(saved!.dayTargets[_date.weekday]!.calories, 2000);
          expect(saved.mealTargets['breakfast']!.calories, 400);
          if (!legacy) {
            expect(saved.mealTargets['lunch']!.calories, 600);
          } else {
            expect(
              await tester.runAsync(
                () => preferences.get(mealCalorieGoalKey('lunch')),
              ),
              '800.0',
            );
          }
          await tester.tap(find.byType(BackButton).last);
          await tester.pumpAndSettle();
          expect(
            router.routeInformationProvider.value.uri.toString(),
            '/meal?meal=lunch&date=2026-10-08',
          );
          expect(tester.element(find.byType(DailyLogPage)), same(mealElement));
          expect(container.read(selectedLogDateProvider), _date);
          await _waitFor(
            tester,
            () => find
                .descendant(
                  of: target,
                  matching: find.textContaining('$updated'),
                )
                .evaluate()
                .isNotEmpty,
          );
          expect(
            find.descendant(of: target, matching: find.textContaining('2000')),
            findsNothing,
          );
          if (!legacy && language == 'ar') {
            expect(
              find.descendant(of: fatDial, matching: find.text('20 g')),
              findsOneWidget,
            );
            expect(
              tester
                  .widget<CircularProgressIndicator>(
                    find.descendant(
                      of: fatDial,
                      matching: find.byType(CircularProgressIndicator),
                    ),
                  )
                  .value,
              1,
            );
            await Scrollable.ensureVisible(
              tester.element(
                find.byKey(const Key('daily-meal-detail-summary')),
              ),
              alignment: 0,
            );
            await tester.pumpAndSettle();
            await captureClosureSurface(
              tester,
              find.byKey(capture),
              'meal-goal-edit-return-lunch-ar',
            );
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        },
      );
    }
  }
}
