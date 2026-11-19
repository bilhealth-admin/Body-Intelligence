import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:body_intelligence_log/features/nutrition/domain/gemini_vision_estimate.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_image_estimate_contract.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_image_analysis_service.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_vision_image_preprocessor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

Map<String, Object?> photoResponse() => {
  'schema_version': 2,
  'request_id': 'photo-request-one',
  'response_locale': 'en',
  'candidates': [
    {
      'name': 'Visible meal',
      'confidence': .8,
      'evidence': 'Visible serving on a plate',
      'amount': 150,
      'unit': 'g',
      'alternatives': [],
      'uncertainty': null,
      'warnings': [],
      'dish_identity': null,
      'visible_components': [],
      'provenance': {
        'identification_provider': 'gemini',
        'model_revision': 'gemini-test',
        'prompt_revision': 'photo-v2-test',
        'nutrition_resolution': 'gemini_photo_estimate',
      },
      'estimate': {
        'kind': 'gemini_photo_estimate',
        'basis': {'quantity': 100, 'unit': 'g'},
        'nutrients': {
          for (final n in FoodNutrient.values)
            n.name: switch (n) {
              FoodNutrient.calories => 150,
              FoodNutrient.carbohydrates => 20,
              FoodNutrient.fiber => 3,
              FoodNutrient.sugar => 0,
              _ => 1,
            },
          'netCarbohydrates': 17,
        },
        'uncertainty': null,
      },
    },
  ],
};
Map<String, dynamic> candidate(Map<String, Object?> root) =>
    (root['candidates'] as List).single as Map<String, dynamic>;

void main() {
  test('retired photo visit after preprocessing sends no upload', () async {
    var current = true, uploads = 0;
    final entered = Completer<void>(), release = Completer<void>();
    final service = MealImageAnalysisService(
      schemaVersion: 2,
      endpoint: 'https://example.invalid/analyze-meal',
      accessToken: () => 'synthetic',
      imagePreprocessor: _HeldPrepared(entered, release),
      gatewayPost: ({required uri, required headers, required body}) async {
        uploads++;
        return MealImageGatewayResponse(
          statusCode: 200,
          body: jsonEncode(photoResponse()),
        );
      },
    );
    final result = service.analyzeForOwner(
      XFile.fromData(
        Uint8List.fromList([255, 216, 255]),
        mimeType: 'image/jpeg',
      ),
      isCurrent: () => current,
    );
    await entered.future;
    current = false; // The delivered A -> B -> A visit predicate stays retired.
    release.complete();
    await expectLater(result, throwsA(isA<MealImageAnalysisException>()));
    expect(uploads, 0);
  });
  test('unguarded schema2 entry fails before image upload', () async {
    var uploads = 0;
    final service = MealImageAnalysisService(
      schemaVersion: 2,
      endpoint: 'https://example.invalid/analyze-meal',
      accessToken: () => 'synthetic',
      imagePreprocessor: _Prepared(),
      gatewayPost: ({required uri, required headers, required body}) async {
        uploads++;
        return MealImageGatewayResponse(
          statusCode: 200,
          body: jsonEncode(photoResponse()),
        );
      },
    );
    await expectLater(
      service.analyze(
        XFile.fromData(
          Uint8List.fromList([255, 216, 255]),
          mimeType: 'image/jpeg',
        ),
      ),
      throwsA(isA<MealImageAnalysisException>()),
    );
    expect(uploads, 0);
  });
  test(
    'explicit schema2 transport sends2 and cannot fall back to schema1 or catalog',
    () async {
      var requests = 0;
      final service = MealImageAnalysisService(
        schemaVersion: 2,
        endpoint: 'https://example.invalid/analyze-meal',
        requestedLocale: 'en',
        accessToken: () => 'synthetic',
        imagePreprocessor: _Prepared(),
        gatewayPost: ({required uri, required headers, required body}) async {
          requests++;
          expect(jsonDecode(body)['schema_version'], 2);
          return MealImageGatewayResponse(
            statusCode: 200,
            body: jsonEncode(photoResponse()),
          );
        },
      );
      final result = await service.analyzeForOwner(
        XFile.fromData(
          Uint8List.fromList([255, 216, 255]),
          mimeType: 'image/jpeg',
        ),
        isCurrent: () => true,
      );
      expect(service.usesGeminiEstimates, isTrue);
      expect(result.estimates.single.nutrients[FoodNutrient.calories], 150);
      expect(requests, 1);
    },
  );
  test(
    'schema2 rejects an old response and does not issue another analysis',
    () async {
      var requests = 0;
      final service = MealImageAnalysisService(
        schemaVersion: 2,
        endpoint: 'https://example.invalid/analyze-meal',
        accessToken: () => 'synthetic',
        imagePreprocessor: _Prepared(),
        gatewayPost: ({required uri, required headers, required body}) async {
          requests++;
          return const MealImageGatewayResponse(
            statusCode: 200,
            body: '{"schema_version":1,"request_id":"old","candidates":[]}',
          );
        },
      );
      await expectLater(
        service.analyzeForOwner(
          XFile.fromData(
            Uint8List.fromList([255, 216, 255]),
            mimeType: 'image/jpeg',
          ),
          isCurrent: () => true,
        ),
        throwsA(isA<MealImageAnalysisException>()),
      );
      expect(requests, 1);
    },
  );
  test(
    'schema2 retains all nineteen plus direct net without verified status',
    () {
      final result = parseGeminiMealImageResponse(jsonEncode(photoResponse()));
      expect(result.schemaVersion, 2);
      expect(
        result.candidates.single.nutritionResolution,
        MealNutritionResolution.geminiPhotoEstimate,
      );
      final food = result.estimates.single;
      expect(food.nutrients.values, hasLength(19));
      expect(food.nutrients[FoodNutrient.sugar], 0);
      expect(food.nutrients[FoodNutrient.sodium], 1);
      expect(food.nutrients[FoodNutrient.vitaminA], 1);
      expect(food.nutrients.netCarbohydrates, 17);
      expect(food.basis!.quantity, 100);
      expect(food.picturedAmount, 150);
      expect(
        GeminiVisionEstimate.fromJson(
          jsonDecode(jsonEncode(food.toJson())),
        ).toJson(),
        food.toJson(),
      );
    },
  );
  test('known zero survives while absent nutrients and net stay unknown', () {
    final response = photoResponse();
    final data = candidate(response)['estimate'] as Map<String, Object?>;
    data['nutrients'] = {'calories': 0, 'protein': null};
    final n = parseGeminiMealImageResponse(
      jsonEncode(response),
    ).estimates.single.nutrients;
    expect(n[FoodNutrient.calories], 0);
    expect(n[FoodNutrient.protein], isNull);
    expect(n[FoodNutrient.sodium], isNull);
    expect(n.netCarbohydrates, isNull);
  });
  test('schema1 validator remains strict and schema2 does not downgrade', () {
    expect(
      () => parseMealImageResponse(jsonEncode(photoResponse())),
      throwsA(isA<MealImageAnalysisException>()),
    );
    final old = photoResponse()..['schema_version'] = 1;
    expect(
      () => parseGeminiMealImageResponse(jsonEncode(old)),
      throwsA(isA<MealImageAnalysisException>()),
    );
  });
  test('spoofed catalog provenance fails rather than acquiring trust', () {
    final response = photoResponse();
    (candidate(response)['provenance'] as Map)['nutrition_resolution'] =
        'verified_food_record';
    expect(
      () => parseGeminiMealImageResponse(jsonEncode(response)),
      throwsA(isA<MealImageAnalysisException>()),
    );
  });
  test('piece and milliliter remain explicit compatible units', () {
    for (final unit in ['piece', 'ml']) {
      final response = photoResponse();
      candidate(response)['unit'] = unit;
      (candidate(response)['estimate'] as Map)['basis'] = {
        'quantity': 100,
        'unit': unit,
      };
      final e = parseGeminiMealImageResponse(
        jsonEncode(response),
      ).estimates.single;
      expect(e.basis!.unit, unit);
      expect(e.picturedUnit, unit);
    }
  });
  test(
    'incompatible pictured count and gram basis is not silently converted',
    () {
      final response = photoResponse();
      candidate(response)['unit'] = 'piece';
      expect(
        () => parseGeminiMealImageResponse(jsonEncode(response)),
        throwsA(isA<MealImageAnalysisException>()),
      );
    },
  );
  test('unknown basis is permitted only with all nutrition unknown', () {
    final response = photoResponse();
    final estimate = candidate(response)['estimate'] as Map;
    estimate['basis'] = null;
    expect(
      () => parseGeminiMealImageResponse(jsonEncode(response)),
      throwsA(isA<MealImageAnalysisException>()),
    );
    estimate['nutrients'] = <String, Object?>{};
    expect(
      parseGeminiMealImageResponse(jsonEncode(response)).estimates.single.basis,
      isNull,
    );
  });
  test('nonfinite or negative values and inconsistent net are rejected', () {
    for (final invalid in [-1.0, double.nan, double.infinity]) {
      expect(
        () => GeminiEstimateNutrients({
          FoodNutrient.calories: invalid,
        }, netCarbohydrates: null),
        throwsFormatException,
      );
    }
    expect(
      () => GeminiEstimateNutrients({
        FoodNutrient.carbohydrates: 10,
        FoodNutrient.fiber: 2,
      }, netCarbohydrates: 9),
      throwsFormatException,
    );
    expect(
      () =>
          GeminiEstimateNutrients({FoodNutrient.fiber: 2}, netCarbohydrates: 8),
      throwsFormatException,
    );
  });
}

class _Prepared implements MealVisionImagePreprocessor {
  @override
  Future<MealVisionPreparedImage> prepare({
    required List<int> bytes,
    required String mimeType,
  }) async => MealVisionPreparedImage(
    bytes: Uint8List.fromList(bytes),
    mimeType: mimeType,
    sha256: 'synthetic',
    width: 1,
    height: 1,
    reencoded: true,
    orientationCorrected: true,
  );
}

class _HeldPrepared extends _Prepared {
  _HeldPrepared(this.entered, this.release);
  final Completer<void> entered, release;
  @override
  Future<MealVisionPreparedImage> prepare({
    required List<int> bytes,
    required String mimeType,
  }) async {
    entered.complete();
    await release.future;
    return super.prepare(bytes: bytes, mimeType: mimeType);
  }
}
