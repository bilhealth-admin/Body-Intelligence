import 'dart:io';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_scope.dart';
import 'package:body_intelligence_log/data/database/food_basis_evidence.dart';
import 'package:body_intelligence_log/data/database/meal_food_evidence.dart';
import 'package:body_intelligence_log/data/database/vision_estimate_evidence.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_nutrition_snapshot_codec.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/local_data_account_boundary.dart';
import 'package:body_intelligence_log/features/nutrition/domain/gemini_vision_estimate.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show AllowedArgumentCount;

const owner = '11111111-1111-4111-8111-111111111111';
GeminiVisionEstimate estimate({
  int index = 0,
  String unit = 'g',
  bool sparse = false,
}) => GeminiVisionEstimate(
  requestId: 'photo-persist-one',
  index: index,
  name: 'Photo meal $index',
  modelRevision: 'gemini-test',
  promptRevision: 'photo-v2-test',
  basis: GeminiEstimateBasis(quantity: unit == 'piece' ? 1 : 100, unit: unit),
  picturedAmount: unit == 'piece' ? 1 : 150,
  picturedUnit: unit,
  nutrients: GeminiEstimateNutrients({
    for (final n in FoodNutrient.values)
      n: sparse && n != FoodNutrient.calories && n != FoodNutrient.sugar
          ? null
          : switch (n) {
              FoodNutrient.calories => 160,
              FoodNutrient.carbohydrates => 20,
              FoodNutrient.fiber => 3,
              FoodNutrient.sugar => 0,
              FoodNutrient.fat => 20,
              _ => n.index.toDouble() + 1,
            },
  }, netCarbohydrates: sparse ? null : 17),
);
ReviewedGeminiVisionEstimate reviewed({
  int index = 0,
  double amount = 150,
  String unit = 'g',
  bool sparse = false,
}) => ReviewedGeminiVisionEstimate(
  estimate: estimate(index: index, unit: unit, sparse: sparse),
  amount: amount,
  unit: unit,
);

Future<int> commit(
  AppDatabase db,
  List<ReviewedGeminiVisionEstimate> items, {
  bool Function()? current,
  String selectedOwner = owner,
}) => MealRepository(db).addGeminiVisionMealAtomically(
  date: DateTime(2026, 11, 18),
  mealType: 'lunch',
  ownerId: selectedOwner,
  requestId: 'photo-persist-one',
  items: items,
  isCurrentOwner: current ?? () => true,
);

void main() {
  test(
    'existing separately-consented cloud codec round trips full estimate evidence without dropping micros',
    () async {
      final a = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: owner,
      );
      final b = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: owner,
      );
      try {
        for (final db in [a, b]) {
          await LocalDataAccountBoundary(db).bindAuthenticatedOwner(owner);
        }
        await commit(a, [reviewed()]);
        final snapshots = await CloudNutritionSnapshotCodec(
          a,
          ownerId: owner,
          ownerIsCurrent: () => true,
        ).capture(scopes: {'nutrition'});
        final target = CloudNutritionSnapshotCodec(
          b,
          ownerId: owner,
          ownerIsCurrent: () => true,
        );
        for (final snapshot in snapshots) {
          await target.apply(snapshot);
        }
        final actual = MealFoodEvidence.read(
          (await b.select(b.mealItems).get()).single,
          ownerKey: LocalDatabaseScope.keyForOwner(owner),
        );
        for (final n in FoodNutrient.values) {
          expect(
            actual.fullValue(n),
            closeTo(estimate().nutrients[n]! * 1.5, .000001),
            reason: n.name,
          );
        }
        expect(actual.directNetCarbohydrates, 25.5);
        expect(actual.vision!.food.estimate.toJson(), estimate().toJson());
      } finally {
        await a.close();
        await b.close();
      }
    },
  );
  test(
    'all provided micros and direct net survive atomic commit and actual database restart',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'bil-gemini-restart-',
      );
      final file = File('${directory.path}/nutrition.sqlite');
      var db = AppDatabase.forTesting(
        NativeDatabase(file),
        localOwnerId: owner,
      );
      try {
        final mealId = await commit(db, [reviewed()]);
        await db.close();
        db = AppDatabase.forTesting(NativeDatabase(file), localOwnerId: owner);
        final rows = await db.select(db.mealItems).get();
        expect(rows, hasLength(1));
        expect(rows.single.mealId, mealId);
        final food = (await db.select(db.foods).get()).single;
        final key = LocalDatabaseScope.keyForOwner(owner);
        final basis = FoodBasisEvidence.read(food, ownerKey: key);
        final saved = MealFoodEvidence.read(rows.single, ownerKey: key);
        expect(basis.isValid, isTrue);
        expect(saved.isValid, isTrue);
        expect(food.verified, isFalse);
        expect(rows.single.foodVerifiedSnapshot, isFalse);
        expect(food.source, VisionFoodEvidence.source);
        for (final n in FoodNutrient.values) {
          expect(basis.value(n), estimate().nutrients[n], reason: n.name);
          expect(
            saved.fullValue(n),
            closeTo(estimate().nutrients[n]! * 1.5, .000001),
            reason: n.name,
          );
        }
        expect(saved.directNetCarbohydrates, 25.5);
        expect(saved.vision!.food.estimate.provider, 'gemini');
        expect(saved.vision!.food.estimate.modelRevision, 'gemini-test');
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'zero remains zero and unknowns remain unknown through numeric compatibility columns',
    () async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: owner,
      );
      try {
        await commit(db, [reviewed(sparse: true)]);
        final item = (await db.select(db.mealItems).get()).single;
        final evidence = MealFoodEvidence.read(item);
        expect(evidence.fullValue(FoodNutrient.calories), 240);
        expect(evidence.fullValue(FoodNutrient.sugar), 0);
        expect(evidence.fullValue(FoodNutrient.sodium), isNull);
        expect(evidence.fullValue(FoodNutrient.protein), isNull);
        expect(evidence.directNetCarbohydrates, isNull);
        expect(item.sodium, 0); // Compatibility storage is not evidence.
      } finally {
        await db.close();
      }
    },
  );
  test(
    'count and volume scale once in their own basis without inventing grams',
    () async {
      for (final unit in ['piece', 'ml']) {
        final db = AppDatabase.forTesting(
          NativeDatabase.memory(),
          localOwnerId: owner,
        );
        try {
          final amount = unit == 'piece' ? 2.0 : 250.0;
          await commit(db, [reviewed(amount: amount, unit: unit)]);
          final food = (await db.select(db.foods).get()).single;
          final item = (await db.select(db.mealItems).get()).single;
          final basis = FoodBasisEvidence.read(food);
          expect(basis.basisGrams, isNull);
          expect(item.quantity, amount);
          expect(item.servingUnitSnapshot, unit);
          expect(
            MealFoodEvidence.read(item).fullValue(FoodNutrient.calories),
            160 * amount / food.servingSize,
          );
        } finally {
          await db.close();
        }
      }
    },
  );
  test(
    'same owner request replay is durable and changed portion is rejected',
    () async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: owner,
      );
      try {
        final first = await commit(db, [reviewed()]);
        expect(await commit(db, [reviewed()]), first);
        await expectLater(
          commit(db, [reviewed(amount: 160)]),
          throwsStateError,
        );
        expect(await db.select(db.foods).get(), hasLength(1));
        expect(await db.select(db.meals).get(), hasLength(1));
        expect(await db.select(db.mealItems).get(), hasLength(1));
      } finally {
        await db.close();
      }
    },
  );
  test('wrong owner or retired same-owner visit writes nothing', () async {
    final db = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: owner,
    );
    try {
      await expectLater(
        commit(db, [reviewed()], selectedOwner: 'other'),
        throwsA(isA<CoachMealConflict>()),
      );
      await expectLater(
        commit(db, [reviewed()], current: () => false),
        throwsA(isA<CoachMealConflict>()),
      );
      expect(await db.select(db.foods).get(), isEmpty);
      expect(await db.select(db.meals).get(), isEmpty);
    } finally {
      await db.close();
    }
  });
  test(
    'owner visit retires during actual SQL insert and rolls all rows and receipt back',
    () async {
      var visitCurrent = true;
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (connection) {
            connection.createFunction(
              functionName: 'retire_vision_visit',
              argumentCount: const AllowedArgumentCount(0),
              directOnly: false,
              function: (_) {
                visitCurrent = false;
                return 0;
              },
            );
          },
        ),
        localOwnerId: owner,
      );
      try {
        await db.customSelect('SELECT 1').get();
        await db.customStatement(
          'CREATE TRIGGER retire_vision_owner BEFORE INSERT ON foods BEGIN SELECT retire_vision_visit(); END',
        );
        await expectLater(
          commit(db, [reviewed()], current: () => visitCurrent),
          throwsA(isA<CoachMealConflict>()),
        );
        expect(visitCurrent, isFalse);
        expect(await db.select(db.foods).get(), isEmpty);
        expect(await db.select(db.meals).get(), isEmpty);
        expect(await db.select(db.mealItems).get(), isEmpty);
        expect(
          (await db.select(db.preferences).get()).where(
            (p) => p.key.startsWith('visionMealCommitV2.'),
          ),
          isEmpty,
        );
      } finally {
        await db.close();
      }
    },
  );
  test(
    'storage failure on second item rolls first item, basis rows, meal and receipt back',
    () async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: owner,
      );
      try {
        await db.customSelect('SELECT 1').get();
        await db.customStatement(
          "CREATE TRIGGER fail_vision_second BEFORE INSERT ON foods WHEN NEW.name = 'Photo meal 1' BEGIN SELECT RAISE(ABORT, 'synthetic storage failure'); END",
        );
        await expectLater(
          commit(db, [reviewed(), reviewed(index: 1)]),
          throwsA(
            predicate<Object>(
              (error) => error.toString().contains('synthetic storage failure'),
            ),
          ),
        );
        expect(await db.select(db.foods).get(), isEmpty);
        expect(await db.select(db.meals).get(), isEmpty);
        expect(await db.select(db.mealItems).get(), isEmpty);
        expect(
          (await db.select(db.preferences).get()).where(
            (p) => p.key.startsWith('visionMealCommitV2.'),
          ),
          isEmpty,
        );
      } finally {
        await db.close();
      }
    },
  );
}
