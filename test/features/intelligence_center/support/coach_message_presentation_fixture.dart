import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_scope.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_message_presentation.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';

const presentationFixtureOwner = 'synthetic-message-owner';
final presentationFixtureOwnerKey = LocalDatabaseScope.keyForOwner(
  presentationFixtureOwner,
);
final presentationFixtureDay = DateTime(2026, 10, 9);
final presentationFixtureClock = DateTime.utc(2026, 10, 9, 12);

/// Preventive fixture hardening: constructor and first native read share one
/// real async zone. The 3 page/10 capture cases have not proved an app defect.
Future<AppDatabase> openMessagePresentationDatabase(
  WidgetTester tester, {
  String? localOwnerId = presentationFixtureOwner,
}) async {
  final opened = await tester.runAsync(() async {
    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: localOwnerId,
    );
    debugPrint('BIL_MESSAGE_SQLITE stage=constructed real_async=true');
    try {
      final rows = await database
          .customSelect('SELECT 1 AS opened')
          .get()
          .timeout(const Duration(seconds: 15));
      if (rows.length != 1 || rows.single.read<int>('opened') != 1) {
        throw StateError('Native SQLite presentation fixture readback failed');
      }
      debugPrint('BIL_MESSAGE_SQLITE stage=opened readback=1');
      return database;
    } catch (error, stack) {
      try {
        await database.close().timeout(const Duration(seconds: 5));
      } catch (closeError) {
        debugPrint(
          'BIL_MESSAGE_SQLITE stage=cleanup_failed '
          'type=${closeError.runtimeType}',
        );
      }
      Error.throwWithStackTrace(error, stack);
    }
  });
  if (opened == null) {
    throw StateError(
      'Native presentation SQLite setup failed; see async exception',
    );
  }
  return opened;
}

CoachVisualMetric fixtureMetric(
  String id,
  double? value, {
  int known = 1,
  int missing = 0,
  bool estimated = false,
}) => CoachVisualMetric.localRead(
  id: id,
  knownSubtotal: value,
  knownItems: value == null ? 0 : known,
  missingItems: value == null ? 1 : missing,
  estimated: estimated,
);
CoachVisualNutritionColumn fixtureColumn({
  String day = '2026-10-09',
  String meal = 'lunch',
}) => CoachVisualNutritionColumn(
  title: meal,
  dayKey: day,
  mealType: meal,
  capturedAtUtc: presentationFixtureClock,
  sourceKinds: const ['reference'],
  metrics: [
    fixtureMetric('calories', 130),
    fixtureMetric('protein', 11),
    fixtureMetric('carbohydrates', 18),
    fixtureMetric('fat', 3),
    fixtureMetric('fiber', 2),
    fixtureMetric('netCarbohydrates', 16),
    fixtureMetric('sodium', 60),
    fixtureMetric('potassium', 0),
    fixtureMetric('magnesium', null),
    fixtureMetric('vitaminA', null),
  ],
);
CoachMessagePresentation fixtureVisual({
  String? owner,
  CoachVisualKind kind = CoachVisualKind.nutrition,
  List<CoachVisualNutritionColumn>? columns,
}) => CoachMessagePresentation.localRead(
  ownerKey: owner ?? presentationFixtureOwnerKey,
  capturedAtUtc: presentationFixtureClock,
  kind: kind,
  title: 'Synthetic local evidence',
  fromDay: '2026-10-09',
  throughDay: '2026-10-09',
  columns: columns ?? [fixtureColumn()],
);
CoachMessagePresentation fixtureWeight() => CoachMessagePresentation.localRead(
  ownerKey: presentationFixtureOwnerKey,
  capturedAtUtc: DateTime.utc(2026, 10, 31, 12),
  kind: CoachVisualKind.weight,
  title: 'Weight',
  fromDay: '2026-10-01',
  throughDay: '2026-10-31',
  weightPoints: [
    CoachVisualWeightPoint(
      recordedAtUtc: DateTime.utc(2026, 10, 1, 9),
      dayKey: '2026-10-01',
      kg: 81.4,
      context: '',
    ),
    CoachVisualWeightPoint(
      recordedAtUtc: DateTime.utc(2026, 10, 2, 9),
      dayKey: '2026-10-02',
      kg: 81.7,
      context: '',
    ),
    CoachVisualWeightPoint(
      recordedAtUtc: DateTime.utc(2026, 10, 31, 9),
      dayKey: '2026-10-31',
      kg: 81.5,
      context: '',
    ),
  ],
);

Future<void> seedMessageFood(
  AppDatabase database, {
  String operation = 'message-food-1',
  String meal = 'lunch',
  bool unknownProtein = false,
  bool unknownCalories = false,
  bool estimated = false,
}) async {
  final source = CoachFoodSourceEvidence(
    kind: CoachFoodSourceKind.reference,
    ref: 'qa:synthetic:message-food',
    revision: operation,
  );
  final portion = CoachFoodPortion(
    food: CoachFoodSnapshot(
      identity: operation,
      name: 'Synthetic fixture food',
      preparedState: 'QA',
      basisGrams: 100,
      source: source,
      nutrients: CoachFoodNutrients({
        for (final n in FoodNutrient.values) n: null,
        FoodNutrient.calories: unknownCalories ? null : 130,
        FoodNutrient.protein: unknownProtein ? null : 11,
        FoodNutrient.carbohydrates: 18,
        FoodNutrient.fat: 3,
        FoodNutrient.fiber: 2,
        FoodNutrient.sodium: 60,
        FoodNutrient.potassium: 0,
      }),
    ),
    quantity: CoachFoodQuantity(
      grams: 75,
      evidence: CoachFoodQuantityEvidence(
        kind: estimated
            ? CoachFoodQuantityKind.estimated
            : CoachFoodQuantityKind.measured,
        description: 'Synthetic QA quantity evidence',
      ),
    ),
  );
  await MealRepository(database).commitCoachMeal(
    command: CoachMealCommand.foods(
      operationId: operation,
      date: presentationFixtureDay,
      mealType: meal,
      review: CoachFoodReview([portion]),
    ),
    scope: CoachMealOwnerScope(
      ownerId: presentationFixtureOwner,
      isCurrent: () => true,
    ),
  );
}
