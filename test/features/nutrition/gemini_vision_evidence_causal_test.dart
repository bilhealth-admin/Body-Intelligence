import 'dart:convert';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_scope.dart';
import 'package:body_intelligence_log/data/database/food_basis_evidence.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Uses only pre-existing public APIs. The preimage rejects this new source;
/// the amendment must preserve its full sparse evidence without granting trust.
void main() {
  test(
    'Gemini estimate food retains full provided nutrient evidence without catalog verification',
    () async {
      const owner = '11111111-1111-4111-8111-111111111111';
      const identity = '22222222-2222-4222-8222-222222222222';
      final key = LocalDatabaseScope.keyForOwner(owner);
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: owner,
      );
      try {
        final nutrients = {
          for (final n in FoodNutrient.values)
            n.name: switch (n) {
              FoodNutrient.calories => 160,
              FoodNutrient.carbohydrates => 20,
              FoodNutrient.fiber => 3,
              FoodNutrient.sugar => 0,
              _ => 1,
            },
          'netCarbohydrates': 17,
        };
        await db
            .into(db.foods)
            .insert(
              FoodsCompanion.insert(
                uuid: const Value(identity),
                name: 'Photo meal',
                category: const Value('vision_estimate_v2'),
                servingSize: const Value(100),
                servingUnit: const Value('g'),
                calories: 160,
                protein: 1,
                carbs: 20,
                fats: 1,
                fiber: const Value(3),
                sugar: const Value(0),
                sodium: const Value(1),
                potassium: const Value(1),
                calcium: const Value(1),
                magnesium: const Value(1),
                phosphorus: const Value(1),
                iron: const Value(1),
                vitaminC: const Value(1),
                nutrientEvidenceMask: const Value(2047),
                source: const Value('Google Gemini photo estimate'),
                foodEvidenceJson: Value(
                  jsonEncode({
                    'schema': 'bil.vision.estimate.food.v1',
                    'identity': identity,
                    'ownerKey': key,
                    'estimate': {
                      'requestId': 'photo-causal',
                      'index': 0,
                      'name': 'Photo meal',
                      'modelRevision': 'gemini-test',
                      'promptRevision': 'photo-v2-test',
                      'kind': 'gemini_photo_estimate',
                      'provider': 'gemini',
                      'basis': {'quantity': 100, 'unit': 'g'},
                      'nutrients': nutrients,
                      'picturedAmount': 150,
                      'picturedUnit': 'g',
                      'uncertainty': null,
                    },
                  }),
                ),
              ),
            );
        final row = (await db.select(db.foods).get()).single;
        final evidence = FoodBasisEvidence.read(row, ownerKey: key);
        expect(evidence.value(FoodNutrient.vitaminA), 1);
        expect(evidence.value(FoodNutrient.sodium), 1);
        expect(evidence.value(FoodNutrient.sugar), 0);
        expect(evidence.value(FoodNutrient.transFat), 1);
        expect(evidence.isValid, isTrue);
        expect(evidence.isModern, isTrue);
        expect(row.verified, isFalse);
        expect(evidence.isCatalog, isFalse);
        expect(FoodBasisEvidence.read(row, ownerKey: 'other').isValid, isFalse);
        final lost = row.copyWith(foodEvidenceJson: const Value(null));
        expect(FoodBasisEvidence.read(lost).isValid, isFalse);
        expect(
          FoodBasisEvidence.read(lost).values.values,
          everyElement(isNull),
        );
      } finally {
        await db.close();
      }
    },
  );
}
