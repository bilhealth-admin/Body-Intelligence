import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_scope.dart';
import 'package:body_intelligence_log/data/database/meal_food_evidence.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_nutrition_snapshot_codec.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/local_data_account_boundary.dart';
import 'package:body_intelligence_log/features/nutrition/domain/gemini_vision_estimate.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
final _day = DateTime(2026, 11, 18);

GeminiVisionEstimate _estimate({String unit = 'g', bool sparse = false}) =>
    GeminiVisionEstimate(
      requestId: 'quantity-edit',
      index: 0,
      name: 'Synthetic photo meal',
      modelRevision: 'gemini-test',
      promptRevision: 'photo-test',
      basis: GeminiEstimateBasis(
        quantity: unit == 'piece' ? 1 : 100,
        unit: unit,
      ),
      picturedAmount: unit == 'piece' ? 1 : 150,
      picturedUnit: unit,
      nutrients: GeminiEstimateNutrients({
        for (final n in FoodNutrient.values)
          n: sparse && n != FoodNutrient.calories && n != FoodNutrient.sugar
              ? null
              : switch (n) {
                  FoodNutrient.calories => 160,
                  FoodNutrient.protein => 10,
                  FoodNutrient.carbohydrates => 20,
                  FoodNutrient.fiber => 3,
                  FoodNutrient.sugar => 0,
                  FoodNutrient.fat => 20,
                  _ => 1,
                },
      }, netCarbohydrates: sparse ? null : 17),
    );

Future<MealItem> _seed(
  AppDatabase db, {
  String unit = 'g',
  bool sparse = false,
}) async {
  final source = _estimate(unit: unit, sparse: sparse);
  await MealRepository(db).addGeminiVisionMealAtomically(
    date: _day,
    mealType: 'lunch',
    ownerId: _owner,
    requestId: source.requestId,
    items: [
      ReviewedGeminiVisionEstimate(
        estimate: source,
        amount: unit == 'piece' ? 1 : 150,
        unit: unit,
      ),
    ],
    isCurrentOwner: () => true,
  );
  return (await db.select(db.mealItems).get()).single;
}

void _expectPortion(
  MealItem item,
  GeminiVisionEstimate source,
  double quantity,
) {
  final saved = MealFoodEvidence.read(
    item,
    ownerKey: LocalDatabaseScope.keyForOwner(_owner),
  );
  expect(saved.isValid, isTrue);
  expect(saved.vision, isNotNull);
  expect(saved.vision!.quantity, quantity);
  expect(saved.vision!.food.estimate.toJson(), source.toJson());
  expect(item.foodVerifiedSnapshot, isFalse);
  expect(item.servingUnitSnapshot, source.basis!.unit);
  for (final n in FoodNutrient.values) {
    final value = source.nutrients[n];
    expect(
      saved.fullValue(n),
      value == null
          ? isNull
          : closeTo(value * quantity / source.basis!.quantity, 1e-8),
      reason: n.name,
    );
  }
  final net = source.nutrients.netCarbohydrates;
  expect(
    saved.directNetCarbohydrates,
    net == null
        ? isNull
        : closeTo(net * quantity / source.basis!.quantity, 1e-8),
  );
}

void main() {
  test(
    'real quantity edits retain all19 nutrients, direct net and original immutable basis',
    () async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: _owner,
      );
      try {
        final first = await _seed(db);
        final foodBefore = (await db.select(db.foods).get()).single.toJson();
        for (final amount in [225.0, 75.0]) {
          final before = await MealRepository(db).getMealItem(first.id);
          await MealRepository(
            db,
          ).updateMealItem(id: first.id, quantity: amount);
          final item = await MealRepository(db).getMealItem(first.id);
          _expectPortion(item, _estimate(), amount);
          expect(item.revision, before.revision + 1);
          expect(item.syncStatus, 'pending');
        }
        expect((await db.select(db.foods).get()).single.toJson(), foodBefore);
      } finally {
        await db.close();
      }
    },
  );
  for (final unit in ['piece', 'ml']) {
    test(
      'real $unit edit stays in the same source basis without converting to grams',
      () async {
        final db = AppDatabase.forTesting(
          NativeDatabase.memory(),
          localOwnerId: _owner,
        );
        try {
          final first = await _seed(db, unit: unit);
          final amount = unit == 'piece' ? 2.0 : 250.0;
          await MealRepository(
            db,
          ).updateMealItem(id: first.id, quantity: amount);
          _expectPortion(
            await MealRepository(db).getMealItem(first.id),
            _estimate(unit: unit),
            amount,
          );
        } finally {
          await db.close();
        }
      },
    );
  }
  test(
    'quantity edit preserves known zero and every missing nutrient as unknown',
    () async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: _owner,
      );
      try {
        final first = await _seed(db, sparse: true);
        await MealRepository(db).updateMealItem(id: first.id, quantity: 225);
        final item = await MealRepository(db).getMealItem(first.id);
        _expectPortion(item, _estimate(sparse: true), 225);
        expect(item.sugar, 0);
        expect(item.sodium, 0); // Compatibility zero is not evidence.
      } finally {
        await db.close();
      }
    },
  );
  test(
    'closed day blocks a Vision quantity edit and keeps the exact preimage',
    () async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: _owner,
      );
      try {
        await DailyLogRepository(db).startDay(_day);
        final first = await _seed(db);
        await DailyLogRepository(db).closeDay(_day);
        await expectLater(
          MealRepository(db).updateMealItem(id: first.id, quantity: 225),
          throwsA(isA<CoachMealConflict>()),
        );
        expect(
          (await MealRepository(db).getMealItem(first.id)).toJson(),
          first.toJson(),
        );
      } finally {
        await db.close();
      }
    },
  );
  test(
    'invalid historical quantity evidence cannot be relabelled by an edit',
    () async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: _owner,
      );
      try {
        final first = await _seed(db);
        await db.customStatement(
          'UPDATE meal_items SET quantity=151 WHERE id=?',
          [first.id],
        );
        final before = (await MealRepository(
          db,
        ).getMealItem(first.id)).toJson();
        await expectLater(
          MealRepository(db).updateMealItem(id: first.id, quantity: 225),
          throwsA(isA<CoachMealConflict>()),
        );
        expect(
          (await MealRepository(db).getMealItem(first.id)).toJson(),
          before,
        );
      } finally {
        await db.close();
      }
    },
  );
  test(
    'edited quantity and all19 nutrient evidence survive the existing cloud codec',
    () async {
      final a = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: _owner,
      );
      final b = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: _owner,
      );
      try {
        for (final db in [a, b]) {
          await LocalDataAccountBoundary(db).bindAuthenticatedOwner(_owner);
        }
        final first = await _seed(a);
        await MealRepository(a).updateMealItem(id: first.id, quantity: 225);
        final source = CloudNutritionSnapshotCodec(
          a,
          ownerId: _owner,
          ownerIsCurrent: () => true,
        );
        final target = CloudNutritionSnapshotCodec(
          b,
          ownerId: _owner,
          ownerIsCurrent: () => true,
        );
        for (final snapshot in await source.capture(scopes: {'nutrition'})) {
          await target.apply(snapshot);
        }
        _expectPortion(
          (await b.select(b.mealItems).get()).single,
          _estimate(),
          225,
        );
      } finally {
        await a.close();
        await b.close();
      }
    },
  );
}
