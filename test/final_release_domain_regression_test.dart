import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/features/wellness/domain/recipe_content_localizer.dart';
import 'package:body_intelligence_log/features/nutrition_plans/domain/diet_macro_plan.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/recipe_import/domain/recipe_ingredient_evidence.dart';

void main() {
  test('a linked source is rejected when it names a different preparation', () {
    expect(
      RecipeIngredientEvidence.hasKnownMismatch('beef', 'Bologna, beef'),
      isTrue,
    );
    expect(
      RecipeIngredientEvidence.hasKnownMismatch('tomato', 'Tomato powder'),
      isTrue,
    );
    expect(
      RecipeIngredientEvidence.hasKnownMismatch('milk', 'Crackers, milk'),
      isTrue,
    );
    expect(
      RecipeIngredientEvidence.hasKnownMismatch(
        'olive oil',
        'Oil, olive, salad or cooking',
      ),
      isFalse,
    );
    expect(
      RecipeIngredientEvidence.hasKnownMismatch(
        'tomato powder',
        'Tomato powder',
      ),
      isFalse,
    );
    expect(
      RecipeIngredientEvidence.hasKnownMismatch('okra', 'Okra, raw'),
      isFalse,
    );
    expect(
      RecipeIngredientEvidence.hasKnownMismatch(
        'tahini',
        'Seeds, sesame butter, tahini, from roasted and toasted kernels',
      ),
      isFalse,
    );
  });
  test(
    'all shipped known English method leaks are localized without changing source records',
    () {
      final files = Directory(
        'assets/catalogs/recipes/v1/shards',
      ).listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
      var checked = 0;
      for (final file in files) {
        final data = jsonDecode(file.readAsStringSync()) as Map;
        for (final record in data['records'] as List) {
          final localizations = record['localizations'] as Map;
          for (final locale in ['ar', 'fr', 'es', 'tr', 'th']) {
            final original = Map<String, dynamic>.from(
              localizations[locale] as Map,
            );
            final before = jsonEncode(original);
            final result = RecipeContentLocalizer.resolve(original, locale);
            expect(jsonEncode(original), before);
            expect(result['title'], original['title']);
            expect(
              (result['ingredients'] as List).length,
              (original['ingredients'] as List).length,
            );
            for (final step in result['steps'] as List) {
              expect(
                RegExp(
                  r'^(Measure and prepare:|Simmer gently until|Divide into the stated|Bake until|Cook covered|Cook the components)',
                ).hasMatch(step as String),
                isFalse,
                reason: '${record['canonicalId']} $locale: $step',
              );
            }
            if (locale == 'ar') {
              for (final line in result['ingredients'] as List) {
                expect(
                  RegExp('[A-Za-z]{3,}').hasMatch(line as String),
                  isFalse,
                  reason: '${record['canonicalId']}: $line',
                );
              }
            }
            checked++;
          }
        }
      }
      expect(checked, 1500 * 5);
    },
  );
  test('Bamia quantities and cooking meaning are preserved', () {
    expect(
      RecipeContentLocalizer.ingredient('600 g okra', 'ar'),
      '600 جم بامية',
    );
    expect(
      RecipeContentLocalizer.ingredient('600 g beef', 'ar'),
      '600 جم لحم بقري',
    );
    expect(
      RecipeContentLocalizer.step(
        'Simmer gently until the ingredients are tender and the flavours combine.',
        'ar',
      ),
      contains('نار هادئة'),
    );
    expect(
      RecipeContentLocalizer.step('Unknown original instruction.', 'ar'),
      'Unknown original instruction.',
    );
  });

  double value(DietMacroTarget target, DietMacroComponent field) =>
      switch (field) {
        DietMacroComponent.carbs => target.carbsGrams,
        DietMacroComponent.protein => target.proteinGrams,
        DietMacroComponent.fat => target.fatGrams,
      };
  for (final level in DietFatLevel.values) {
    for (final first in DietMacroComponent.values) {
      for (final second in DietMacroComponent.values.where((v) => v != first)) {
        test(
          'macro recency survives each digit: $level $first then $second',
          () {
            final third = DietMacroComponent.values.singleWhere(
              (v) => v != first && v != second,
            );
            final history = DietMacroEditHistory();
            var current = const DietMacroTarget(
              calories: 2000,
              carbsGrams: 200,
              proteinGrams: 125,
              fatGrams: 700 / 9,
            );
            DietMacroComponent? previous;
            for (final field in [first, second, third]) {
              final digits = field == DietMacroComponent.protein
                  ? ['1', '11', '110']
                  : field == DietMacroComponent.carbs
                  ? ['1', '15', '150']
                  : ['6', '60'];
              final preserved = previous == null
                  ? null
                  : value(current, previous);
              for (final digit in digits) {
                final updated = DietMacroAllocator.rebalancePreserving(
                  current: current,
                  edited: field,
                  grams: double.parse(digit),
                  locked: history.lockedFor(field),
                  fallbackFatLevel: level,
                );
                expect(updated, isNotNull);
                current = updated!;
                history.accept(field);
                expect(value(current, field), double.parse(digit));
                if (previous != null) {
                  expect(value(current, previous), preserved);
                }
                expect(current.calculatedCalories, closeTo(2000, .0001));
              }
              previous = field;
            }
            expect(history.lockedFor(first), {first, third});
            final separateDay = DietMacroEditHistory();
            expect(separateDay.lockedFor(first), {first});
          },
        );
      }
    }
  }

  test(
    'step value distinguishes real zero, absent today and permission denial',
    () {
      final now = DateTime(2026, 9, 10, 14);
      ConnectedHealthSignalView signal(DateTime day, double value) =>
          ConnectedHealthSignalView(
            key: 'steps',
            value: value,
            unit: 'count',
            source: 'apple_health',
            observedAt: day,
            confidence: 1,
          );
      ConnectedHealthSnapshot snapshot(
        List<ConnectedHealthSignalView> history,
      ) => ConnectedHealthSnapshot(
        status: ConnectedHealthStatus.synchronized,
        platformSource: 'Apple Health',
        availableSources: const ['Apple Health'],
        signals: const [],
        stepHistory: history,
        importedCount: history.length,
        lastSyncAt: now,
        failureCode: null,
      );
      final today = DateTime(2026, 9, 10);
      final historical = snapshot([signal(DateTime(2026, 9, 9, 13), 3800)]);
      expect(connectedHealthDailyStepTotals(historical, now)[today], isNull);
      expect(
        connectedHealthDailyStepTotals(
          historical.copyWith(signals: [signal(now, 4321)]),
          now,
        )[today],
        4321,
      );
      expect(
        connectedHealthDailyStepTotals(
          snapshot([signal(now, 4321)]).copyWith(signals: [signal(now, 4321)]),
          now,
        )[today],
        4321,
      );
      expect(connectedHealthStepTrendValues(historical, now).last, 0);
      final realZero = snapshot([signal(now, 0)]);
      expect(
        connectedHealthDailyStepTotals(realZero, now).containsKey(today),
        isTrue,
      );
      expect(connectedHealthDailyStepTotals(realZero, now)[today], 0);
      expect(
        connectedHealthDailyStepTotals(
          snapshot([signal(now, 4721)]),
          now,
        )[today],
        4721,
      );
      expect(
        connectedHealthDailyStepTotals(
          realZero.copyWith(status: ConnectedHealthStatus.permissionDenied),
          now,
        ),
        isEmpty,
      );
      expect(connectedHealthDailyStepTotals(null, now), isEmpty);
    },
  );
}
