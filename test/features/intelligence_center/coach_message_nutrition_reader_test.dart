import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_message_nutrition_reader.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_meal_read_parser.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_message_presentation.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/coach_message_presentation_fixture.dart';

void main() {
  late AppDatabase db;
  late CoachMessageNutritionReader reader;
  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: presentationFixtureOwner,
    );
    reader = CoachMessageNutritionReader(
      db,
      clock: () => presentationFixtureClock,
    );
  });
  tearDown(() => db.close());
  CoachMealReadRequest request(String meal) => CoachMealReadRequest([
    CoachMealReadColumnRequest(presentationFixtureDay, meal),
  ]);
  CoachVisualMetric metric(CoachMessagePresentation visual, String id) =>
      visual.columns.single.metrics.singleWhere((x) => x.id == id);

  test(
    'real SQLite meal read preserves all 19 nutrients plus defined net and no writes',
    () async {
      await seedMessageFood(db);
      final before = await db.select(db.mealItems).get();
      final visual = (await reader.readMeals(
        request('lunch'),
        checkAccess: () {},
      ))!;
      expect(visual.columns.single.metrics, hasLength(20));
      expect(metric(visual, 'calories').completeValue, 97.5);
      expect(metric(visual, 'protein').completeValue, 8.25);
      expect(metric(visual, 'fiber').completeValue, 1.5);
      expect(metric(visual, 'netCarbohydrates').completeValue, 12);
      expect(metric(visual, 'potassium').completeValue, 0);
      expect(metric(visual, 'magnesium').knownSubtotal, isNull);
      expect(
        (await db.select(db.mealItems).get()).map((x) => x.toJson()).toList(),
        before.map((x) => x.toJson()).toList(),
      );
    },
  );
  test(
    'meal and open day retain known subtotal with partial protein and calories',
    () async {
      await seedMessageFood(db);
      await seedMessageFood(
        db,
        operation: 'partial-food',
        unknownProtein: true,
        unknownCalories: true,
        estimated: true,
      );
      for (final visual in [
        (await reader.readMeals(request('lunch'), checkAccess: () {}))!,
        await reader.readDay(presentationFixtureDay, checkAccess: () {}),
      ]) {
        for (final id in ['protein', 'calories']) {
          final value = metric(visual, id);
          expect(value.knownSubtotal, id == 'protein' ? 8.25 : 97.5);
          expect(value.knownItems, 1);
          expect(value.missingItems, 1);
          expect(value.completeValue, isNull);
          expect(value.coverage, CoachVisualCoverage.partial);
        }
        expect(metric(visual, 'fiber').estimated, isTrue);
      }
    },
  );
  test(
    'closed canonical unknown does not silently fall back to known food details',
    () async {
      await seedMessageFood(db);
      final daily = DailyLogRepository(db);
      await daily.startDay(presentationFixtureDay);
      await daily.closeDay(presentationFixtureDay);
      await (db.update(db.dailyLogs)
            ..where((x) => x.dayKey.equals('2026-10-09')))
          .write(const DailyLogsCompanion(calories: Value(null)));
      final visual = await reader.readDay(
        presentationFixtureDay,
        checkAccess: () {},
      );
      expect(metric(visual, 'calories').knownSubtotal, isNull);
      expect(
        metric(visual, 'calories').coverage,
        CoachVisualCoverage.unavailable,
      );
      expect(visual.columns.single.sourceKinds, contains('saved_day_ledger'));
    },
  );
  test(
    'changing catalog cannot recalculate a historical item or deleted meal',
    () async {
      await seedMessageFood(db);
      await db
          .update(db.foods)
          .write(const FoodsCompanion(calories: Value(99999)));
      final visual = (await reader.readMeals(
        request('lunch'),
        checkAccess: () {},
      ))!;
      expect(metric(visual, 'calories').completeValue, 97.5);
      await db
          .update(db.meals)
          .write(MealsCompanion(deletedAt: Value(presentationFixtureClock)));
      final deleted = (await reader.readMeals(
        request('lunch'),
        checkAccess: () {},
      ))!;
      expect(metric(deleted, 'calories').knownSubtotal, isNull);
      expect(await db.select(db.mealItems).get(), hasLength(1));
    },
  );
  test(
    'two real meals compare without duplication or altered record identities',
    () async {
      await seedMessageFood(db);
      await seedMessageFood(db, operation: 'dinner', meal: 'dinner');
      final before = await db.select(db.mealItems).get();
      final visual = (await reader.readMeals(
        CoachMealReadRequest([
          CoachMealReadColumnRequest(presentationFixtureDay, 'lunch'),
          CoachMealReadColumnRequest(presentationFixtureDay, 'dinner'),
        ]),
        checkAccess: () {},
      ))!;
      expect(visual.kind, CoachVisualKind.comparison);
      expect(visual.columns.map((x) => x.mealType), ['lunch', 'dinner']);
      expect(
        coachVisualMetricDifference(
          visual.columns.first.metrics.first,
          visual.columns.last.metrics.first,
        ),
        0,
      );
      expect(
        (await db.select(db.mealItems).get()).map((x) => x.uuid),
        before.map((x) => x.uuid),
      );
    },
  );
  test(
    'a cancelled owner visit during real SQLite awaits yields no facts or writes',
    () async {
      await seedMessageFood(db);
      var checks = 0, retired = false;
      void check() {
        checks++;
        if (checks == 4) retired = true;
        if (retired) throw StateError('cancelled owner visit');
      }

      await expectLater(
        reader.readMeals(request('lunch'), checkAccess: check),
        throwsStateError,
      );
      expect(checks, greaterThanOrEqualTo(4));
      expect(await db.select(db.mealItems).get(), hasLength(1));
    },
  );
  test(
    'meal parser supports AR EN Persian digits dates and explicit comparisons',
    () {
      const parser = CoachMealReadParser();
      for (final text in [
        'show lunch nutrition on 2026-10-09',
        'اعرض الغداء بتاريخ ٢٠٢٦-١٠-٠٩',
        'show lunch on ۲۰۲۶-۱۰-۰۹',
      ]) {
        final parsed = parser.parse(
          text,
          referenceLocal: presentationFixtureDay,
        );
        expect(parsed.state, CoachMealReadIntentState.ready);
        expect(parsed.request!.columns.single.mealType, 'lunch');
      }
      final compared = parser.parse(
        'قارن الغداء اليوم مع العشاء أمس',
        referenceLocal: presentationFixtureDay,
      );
      expect(compared.request!.compare, isTrue);
      expect(compared.request!.columns.last.day, DateTime(2026, 10, 8));
      expect(
        parser
            .parse('log lunch 75 g', referenceLocal: presentationFixtureDay)
            .state,
        CoachMealReadIntentState.ignored,
      );
      expect(
        parser
            .parse(
              'compare lunch with lunch',
              referenceLocal: presentationFixtureDay,
            )
            .state,
        CoachMealReadIntentState.clarification,
      );
    },
  );
}
