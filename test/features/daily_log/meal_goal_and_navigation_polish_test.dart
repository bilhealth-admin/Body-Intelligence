import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/daily_log_summary_widgets.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'daily_log_nutrition_fixtures.dart';
import 'meal_platform_evidence_font.dart';
import '../../visual_closure/closure_surface_capture.dart';

const initialGoal = NutritionGoalTarget(
  calories: 1000,
  carbsPercent: 45,
  proteinPercent: 20,
  fatPercent: 35,
);
const nextGoal = NutritionGoalTarget(
  calories: 600,
  carbsPercent: 50,
  proteinPercent: 20,
  fatPercent: 30,
);
ThemeData theme(String language, bool dark) => mealPlatformEvidenceTheme(
  dark
      ? BilFlagshipTheme.dark(isArabic: language == 'ar')
      : BilFlagshipTheme.light(isArabic: language == 'ar'),
);
void main() {
  setUpAll(loadMealPlatformEvidenceFont);
  for (final language in ['en', 'ar']) {
    for (final dark in [false, true]) {
      for (final width in [320.0, 390.0, 430.0]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            'compact meal minerals and goals $language dark=$dark $width $scale',
            (tester) async {
              final boundary = GlobalKey();
              var edits = 0;
              await pumpDiaryEvidence(
                tester,
                DailyMealDetailSummary(
                  calorieGoal: 2000,
                  meal: null,
                  mealGoal: initialGoal,
                  onEditMealGoal: () => edits++,
                ),
                language: language,
                width: width,
                scale: scale,
                theme: theme(language, dark),
                repaintKey: boundary,
              );
              final minerals = find.byKey(
                const Key('daily-meal-detail-minerals'),
              );
              final targets = find.byKey(const Key('daily-meal-detail-goal'));
              final macroDials = find.byKey(
                const Key('daily-meal-detail-macros'),
              );
              expect(macroDials, findsOneWidget);
              for (final name in ['carbs', 'fat', 'protein']) {
                final indicator = find.descendant(
                  of: find.byKey(Key('daily-meal-macro-$name')),
                  matching: find.byType(CircularProgressIndicator),
                );
                expect(
                  tester.getSize(indicator).shortestSide,
                  greaterThanOrEqualTo(78),
                );
              }
              final metricSizes = tester
                  .widgetList<NutrientMetric>(
                    find.descendant(
                      of: minerals,
                      matching: find.byType(NutrientMetric),
                    ),
                  )
                  .map((widget) => tester.getSize(find.byWidget(widget)))
                  .toList();
              for (final size in metricSizes) {
                expect(size.height, closeTo(metricSizes.first.height, .01));
                expect(size.width, closeTo(metricSizes.first.width, .01));
              }
              expect(find.text('/ 1000'), findsNothing);
              expect(
                find.descendant(of: minerals, matching: find.text('—')),
                findsNWidgets(3),
              );
              expect(
                find.descendant(
                  of: minerals,
                  matching: find.text('Unavailable'),
                ),
                findsNothing,
              );
              expect(
                tester.getRect(minerals).top,
                greaterThan(tester.getRect(macroDials).bottom),
              );
              expect(
                tester.getRect(targets).top,
                greaterThan(tester.getRect(minerals).bottom),
              );
              expect(
                find.descendant(
                  of: targets,
                  matching: find.textContaining('1000'),
                ),
                findsOneWidget,
              );
              final edit = find.byKey(const Key('daily-meal-edit-goal'));
              await tester.ensureVisible(edit);
              await tester.pumpAndSettle();
              expect(edit.hitTestable(), findsOneWidget);
              expect(
                tester.getSize(edit).shortestSide,
                greaterThanOrEqualTo(48),
              );
              await tester.tap(edit);
              await tester.pump();
              expect(edits, 1);
              expect(
                find.descendant(
                  of: targets,
                  matching: find.textContaining('112.5'),
                ),
                findsOneWidget,
              );
              expect(
                find.descendant(
                  of: targets,
                  matching: find.textContaining('38.9'),
                ),
                findsOneWidget,
              );
              if (language == 'ar' && !dark && width == 390 && scale == 1) {
                await captureClosureSurface(
                  tester,
                  find.byKey(boundary),
                  'meal-goals-ar',
                );
              }
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }
  testWidgets(
    'known zero is not the missing dash; partial evidence remains unknown',
    (tester) async {
      await pumpDiaryEvidence(
        tester,
        DailyMealDetailSummary(
          meal: diaryMeal([
            modernDiaryItem(
              values: const {
                FoodNutrient.calories: 100,
                FoodNutrient.sodium: 0,
                FoodNutrient.potassium: 50,
                FoodNutrient.magnesium: null,
              },
            ),
          ]),
        ),
        theme: theme('en', false),
      );
      final minerals = find.byKey(const Key('daily-meal-detail-minerals'));
      expect(
        find.descendant(of: minerals, matching: find.text('0.0')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: minerals, matching: find.text('50.0')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: minerals, matching: find.text('—')),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'missing meal target does not relabel the daily goal as a meal goal',
    (tester) async {
      await pumpDiaryEvidence(
        tester,
        const DailyMealDetailSummary(
          meal: null,
          calorieGoal: 2000,
          carbsGoal: 250,
          proteinGoal: 100,
          fatGoal: 70,
        ),
        theme: theme('en', false),
      );
      final targets = find.byKey(const Key('daily-meal-detail-goal'));
      expect(
        find.descendant(of: targets, matching: find.textContaining('2000')),
        findsNothing,
      );
      expect(
        find.descendant(of: targets, matching: find.textContaining('250')),
        findsNothing,
      );
      expect(
        find.descendant(of: targets, matching: find.text('—')),
        findsNWidgets(3),
      );
    },
  );
  group('SQLite meal goal', () {
    late AppDatabase database;
    late NutritionGoalScheduleRepository repository;
    setUp(() async {
      // Bind Drift's executor and stream scheduling outside WidgetTester fake time.
      database = AppDatabase.forTesting(NativeDatabase.memory());
      await database.customSelect('SELECT 1').get();
      repository = NutritionGoalScheduleRepository(
        PreferencesRepository(database),
      );
    });
    tearDown(() => database.close());
    testWidgets(
      'real external SQLite goal save updates the displayed meal target',
      (tester) async {
        await tester.runAsync(
          () => repository.saveMeal('breakfast', initialGoal),
        );
        await pumpDiaryEvidence(
          tester,
          ProviderScope(
            overrides: [
              nutritionGoalScheduleRepositoryProvider.overrideWithValue(
                repository,
              ),
              nutritionGoalScheduleProvider.overrideWith(
                (ref) => repository.watch(),
              ),
            ],
            child: Consumer(
              builder: (context, ref, _) => DailyMealDetailSummary(
                meal: null,
                calorieGoal: 2000,
                mealGoal: ref
                    .watch(nutritionGoalScheduleProvider)
                    .value
                    ?.mealTargets['breakfast'],
              ),
            ),
          ),
          theme: theme('en', false),
        );
        for (
          var i = 0;
          i < 50 && find.textContaining('1000').evaluate().isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        final targets = find.byKey(const Key('daily-meal-detail-goal'));
        expect(
          find.descendant(of: targets, matching: find.textContaining('1000')),
          findsOneWidget,
        );
        await tester.runAsync(() => repository.saveMeal('breakfast', nextGoal));
        for (
          var i = 0;
          i < 50 && find.textContaining('600').evaluate().isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        expect(
          find.descendant(of: targets, matching: find.textContaining('600')),
          findsOneWidget,
        );
        expect(find.textContaining('1000'), findsNothing);
        final saved = await tester.runAsync(repository.read);
        expect(saved!.mealTargets['breakfast']!.calories, 600);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      },
    );
  });
  for (final language in ['en', 'ar']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Today back edge and separated day arrows $language $scale', (
        tester,
      ) async {
        var back = 0, previous = 0, next = 0;
        final paintKey = GlobalKey();
        await pumpDiaryEvidence(
          tester,
          DiaryDateNavigator(
            date: DateUtils.dateOnly(DateTime.now()),
            arabic: language == 'ar',
            todayHeader: true,
            onBack: () => back++,
            onPrevious: () => previous++,
            onNext: () => next++,
            onPick: () {},
          ),
          language: language,
          width: 320,
          scale: scale,
          theme: theme(language, false),
          repaintKey: paintKey,
        );
        final title = find.text(language == 'ar' ? 'اليوم' : 'Today');
        expect(title, findsOneWidget);
        final style = tester.widget<Text>(title).style!;
        expect(style.fontWeight, FontWeight.w800);
        expect(
          style.color,
          Theme.of(tester.element(title)).colorScheme.onSurface,
        );
        await captureClosureSurface(
          tester,
          find.byKey(paintKey),
          'today-title-$language-${scale.round()}x',
        );
        final b = find.byKey(const Key('daily-log-back'));
        final p = find.byKey(const Key('daily-log-previous'));
        final n = find.byKey(const Key('daily-log-next'));
        final rect = tester.getRect(
          find.byKey(const Key('daily-log-date-bar')),
        );
        final br = tester.getRect(b);
        expect(
          language == 'ar'
              ? (rect.right - br.right).abs()
              : (br.left - rect.left).abs(),
          lessThan(1),
        );
        expect(
          (tester.getCenter(p).dx - tester.getCenter(n).dx).abs(),
          greaterThanOrEqualTo(64),
        );
        for (final button in [b, p, n]) {
          expect(button.hitTestable(), findsOneWidget);
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          await tester.tap(button);
          await tester.pump();
        }
        expect([back, previous, next], [1, 1, 1]);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
