import 'dart:convert';

import 'package:body_intelligence_log/features/nutrition/presentation/meal_vision_ui_copy.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_image_gateway_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses every unified review field without selecting an item', () {
    final analysis = parseMealImageResponse(
      jsonEncode({
        'schema_version': 1,
        'request_id': 'request-1234567890',
        'candidates': [
          {
            'name': 'Koshari',
            'confidence': .48,
            'evidence': 'rice and lentils visible',
            'amount': 420,
            'unit': 'g',
            'alternatives': [
              {'name': 'Rice and lentils', 'confidence': .31},
            ],
            'uncertainty': 'sauce obscures part of the plate',
            'warnings': ['Review the serving amount.'],
            'provenance': {
              'identification_provider': 'gemini',
              'model_revision': 'fixture',
              'nutrition_resolution': 'requires_verified_food_match',
            },
          },
        ],
      }),
    );

    final item = analysis.candidates.single;
    expect(item.amount, 420);
    expect(item.unit, 'g');
    expect(item.alternatives.single.name, 'Rice and lentils');
    expect(item.uncertainty, isNotEmpty);
    expect(item.warnings, isNotEmpty);
    expect(item.requiresReview, isTrue);
  });

  test('reviewed image amounts convert to the diary gram contract', () {
    expect(
      mealImageAmountInGrams(
        amount: 420,
        unit: 'g',
        servingSize: 100,
        servingUnit: 'g',
      ),
      420,
    );
    expect(
      mealImageAmountInGrams(
        amount: 0.5,
        unit: 'kg',
        servingSize: 100,
        servingUnit: 'g',
      ),
      500,
    );
    expect(
      mealImageAmountInGrams(
        amount: 2,
        unit: 'oz',
        servingSize: 1,
        servingUnit: 'oz',
      ),
      closeTo(56.69904625, 0.00000001),
    );
    expect(
      mealImageAmountInGrams(
        amount: 1,
        unit: 'lb',
        servingSize: 1,
        servingUnit: 'lb',
      ),
      closeTo(453.59237, 0.00000001),
    );
    expect(
      mealImageAmountInGrams(
        amount: 2,
        unit: 'serving',
        servingSize: 125,
        servingUnit: 'serving',
      ),
      250,
    );
    expect(
      mealImageAmountInGrams(
        amount: 1,
        unit: 'cup',
        servingSize: 100,
        servingUnit: 'g',
      ),
      isNull,
    );
  });

  test('vision UI copy is clean and complete in five locales', () {
    for (final locale in const ['en', 'ar', 'fr', 'es', 'tr']) {
      final copy = MealVisionUiCopy.of(locale);
      for (final key in const [
        'unavailable',
        'take',
        'choose',
        'none',
        'review',
        'no_match',
        'confirmed_added',
        'unit_mismatch',
      ]) {
        final text = copy.text(key);
        expect(text, isNotEmpty);
        expect(text, isNot(contains('Ø')));
        expect(text, isNot(contains('Ã')));
      }
    }
  });

  test('vision review copy resolves honestly across all 25 locales', () {
    expect(AppLocalizations.supportedLocales, hasLength(25));
    for (final locale in AppLocalizations.supportedLocales) {
      final copy = MealVisionUiCopy.ofLocale(locale);
      for (final key in const [
        'unavailable',
        'take',
        'choose',
        'none',
        'review',
        'no_match',
        'confirmed_added',
        'select_notice',
        'unit_mismatch',
        'cancel',
      ]) {
        expect(
          copy.text(key).trim(),
          isNotEmpty,
          reason: '$key ${locale.toLanguageTag()}',
        );
      }
    }
  });
}
