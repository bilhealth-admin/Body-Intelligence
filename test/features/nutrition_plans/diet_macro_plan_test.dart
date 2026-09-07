import 'package:body_intelligence_log/features/nutrition_plans/domain/diet_macro_plan.dart';
import 'package:body_intelligence_log/features/nutrition_plans/domain/nutrition_pathway_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('whole-gram display keeps the exact allocation value', () {
    const target = DietMacroTarget(
      calories: 1000,
      carbsGrams: 78.666,
      proteinGrams: 100,
      fatGrams: 31.704,
    );

    expect(roundedDietMacroGrams(target.carbsGrams), 79);
    expect(target.carbsGrams, 78.666);
    expect(target.calculatedCalories, closeTo(1000, .000001));
  });

  group('fixed-energy macro allocation', () {
    test('Monday 20 g and Sunday 200 g both preserve 2000 kcal', () {
      final week = dietPresets['carb-cycling']!.toDraft().resolveWeek()!;
      final monday = week[DateTime.monday]!;
      final sunday = week[DateTime.sunday]!;

      expect(monday.carbsGrams, 20);
      expect(sunday.carbsGrams, 200);
      expect(monday.calculatedCalories, closeTo(2000, .001));
      expect(sunday.calculatedCalories, closeTo(2000, .001));
      expect(monday.proteinGrams, greaterThan(sunday.proteinGrams));
      expect(monday.fatGrams, greaterThan(sunday.fatGrams));
    });

    test('fat level moves energy between fat and protein without drift', () {
      final lighter = DietMacroAllocator.allocate(
        calories: 2100,
        carbsGrams: 150,
        fatLevel: DietFatLevel.lighter,
      )!;
      final medium = DietMacroAllocator.allocate(
        calories: 2100,
        carbsGrams: 150,
        fatLevel: DietFatLevel.medium,
      )!;
      final richer = DietMacroAllocator.allocate(
        calories: 2100,
        carbsGrams: 150,
        fatLevel: DietFatLevel.richer,
      )!;

      expect(lighter.fatGrams, lessThan(medium.fatGrams));
      expect(medium.fatGrams, lessThan(richer.fatGrams));
      expect(lighter.proteinGrams, greaterThan(medium.proteinGrams));
      expect(medium.proteinGrams, greaterThan(richer.proteinGrams));
      for (final value in [lighter, medium, richer]) {
        expect(value.calculatedCalories, closeTo(2100, .001));
        expect(value.toScheduledGoal().isValid, isTrue);
      }
    });

    test(
      'accepts any positive calorie target and rejects impossible energy',
      () {
        expect(
          DietMacroAllocator.allocate(
            calories: 700,
            carbsGrams: 20,
            fatLevel: DietFatLevel.medium,
          ),
          isNotNull,
        );
        expect(
          DietMacroAllocator.allocate(
            calories: 0,
            carbsGrams: 0,
            fatLevel: DietFatLevel.medium,
          ),
          isNull,
        );
        expect(
          DietMacroAllocator.allocate(
            calories: 1200,
            carbsGrams: 301,
            fatLevel: DietFatLevel.medium,
          ),
          isNull,
        );
        expect(
          DietMacroAllocator.allocate(
            calories: 2000,
            carbsGrams: double.nan,
            fatLevel: DietFatLevel.medium,
          ),
          isNull,
        );
      },
    );

    test('requires calories and every macro to stay strictly positive', () {
      const valid = DietMacroTarget(
        calories: 170,
        carbsGrams: 10,
        proteinGrams: 10,
        fatGrams: 10,
      );
      expect(valid.isValid, isTrue);
      expect(
        const DietMacroTarget(
          calories: 130,
          carbsGrams: 0,
          proteinGrams: 10,
          fatGrams: 10,
        ).isValid,
        isFalse,
      );
      expect(
        DietMacroAllocator.allocate(
          calories: 170,
          carbsGrams: 0,
          fatLevel: DietFatLevel.medium,
        ),
        isNull,
      );
      expect(
        DietMacroAllocator.rebalance(
          current: valid,
          edited: DietMacroComponent.protein,
          grams: 0,
          fallbackFatLevel: DietFatLevel.medium,
        ),
        isNull,
      );
    });

    test('800 and 1000 kcal stay fixed while every macro is editable', () {
      final initial = DietMacroAllocator.allocate(
        calories: 800,
        carbsGrams: 80,
        fatLevel: DietFatLevel.medium,
      )!;
      final proteinEdited = DietMacroAllocator.rebalance(
        current: initial,
        edited: DietMacroComponent.protein,
        grams: 100,
        fallbackFatLevel: DietFatLevel.medium,
      )!;
      expect(proteinEdited.proteinGrams, 100);
      expect(proteinEdited.calculatedCalories, closeTo(800, .000001));

      final fatEdited = DietMacroAllocator.rebalance(
        current: proteinEdited,
        edited: DietMacroComponent.fat,
        grams: 30,
        fallbackFatLevel: DietFatLevel.medium,
      )!;
      expect(fatEdited.fatGrams, 30);
      expect(fatEdited.calculatedCalories, closeTo(800, .000001));

      final carbEdited = DietMacroAllocator.rebalance(
        current: fatEdited,
        edited: DietMacroComponent.carbs,
        grams: 50,
        fallbackFatLevel: DietFatLevel.medium,
      )!;
      expect(carbEdited.carbsGrams, 50);
      expect(carbEdited.calculatedCalories, closeTo(800, .000001));

      final rescaled = DietMacroAllocator.rescale(
        current: carbEdited,
        calories: 1000,
      )!;
      expect(rescaled.calories, 1000);
      expect(rescaled.calculatedCalories, closeTo(1000, .000001));
    });

    test('keeps earlier edits fixed and moves only the remaining macro', () {
      final initial = DietMacroAllocator.allocate(
        calories: 1000,
        carbsGrams: 100,
        fatLevel: DietFatLevel.medium,
      )!;

      final carbsFirst = DietMacroAllocator.rebalancePreserving(
        current: initial,
        edited: DietMacroComponent.carbs,
        grams: 120,
        locked: const {},
        fallbackFatLevel: DietFatLevel.medium,
      )!;
      final carbsThenProtein = DietMacroAllocator.rebalancePreserving(
        current: carbsFirst,
        edited: DietMacroComponent.protein,
        grams: 100,
        locked: const {DietMacroComponent.carbs},
        fallbackFatLevel: DietFatLevel.medium,
      )!;
      expect(carbsThenProtein.carbsGrams, closeTo(120, .000001));
      expect(carbsThenProtein.proteinGrams, closeTo(100, .000001));
      expect(carbsThenProtein.fatGrams, closeTo(120 / 9, .000001));
      expect(carbsThenProtein.calculatedCalories, closeTo(1000, .000001));

      final fatAfterProtein = DietMacroAllocator.rebalancePreserving(
        current: carbsThenProtein,
        edited: DietMacroComponent.fat,
        grams: 30,
        locked: const {DietMacroComponent.protein},
        fallbackFatLevel: DietFatLevel.medium,
      )!;
      expect(fatAfterProtein.proteinGrams, closeTo(100, .000001));
      expect(fatAfterProtein.fatGrams, closeTo(30, .000001));
      expect(fatAfterProtein.carbsGrams, closeTo(82.5, .000001));
      expect(fatAfterProtein.calculatedCalories, closeTo(1000, .000001));

      final fatFirst = DietMacroAllocator.rebalancePreserving(
        current: initial,
        edited: DietMacroComponent.fat,
        grams: 40,
        locked: const {},
        fallbackFatLevel: DietFatLevel.medium,
      )!;
      final fatThenCarbs = DietMacroAllocator.rebalancePreserving(
        current: fatFirst,
        edited: DietMacroComponent.carbs,
        grams: 120,
        locked: const {DietMacroComponent.fat},
        fallbackFatLevel: DietFatLevel.medium,
      )!;
      expect(fatThenCarbs.fatGrams, closeTo(40, .000001));
      expect(fatThenCarbs.carbsGrams, closeTo(120, .000001));
      expect(fatThenCarbs.proteinGrams, closeTo(40, .000001));

      final proteinFirst = DietMacroAllocator.rebalancePreserving(
        current: initial,
        edited: DietMacroComponent.protein,
        grams: 100,
        locked: const {},
        fallbackFatLevel: DietFatLevel.medium,
      )!;
      final proteinThenCarbs = DietMacroAllocator.rebalancePreserving(
        current: proteinFirst,
        edited: DietMacroComponent.carbs,
        grams: 120,
        locked: const {DietMacroComponent.protein},
        fallbackFatLevel: DietFatLevel.medium,
      )!;
      expect(proteinThenCarbs.proteinGrams, closeTo(100, .000001));
      expect(proteinThenCarbs.carbsGrams, closeTo(120, .000001));
      expect(proteinThenCarbs.fatGrams, closeTo(120 / 9, .000001));
    });
  });

  test('all editable systems resolve a complete seven-day week', () {
    expect(dietPresets, hasLength(10));
    for (final preset in dietPresets.values) {
      final week = preset.toDraft().resolveWeek();
      expect(week, isNotNull, reason: preset.pathwayId);
      expect(week!.keys.toSet(), {1, 2, 3, 4, 5, 6, 7});
      expect(
        week.values.every((target) => target.isValid),
        isTrue,
        reason: preset.pathwayId,
      );
    }
  });

  group('pregnancy guidance', () {
    test(
      'uses trimester energy increments and a balanced 50 percent carb base',
      () {
        for (final entry in const <int, double>{1: 0, 2: 340, 3: 452}.entries) {
          final draft = PregnancyNutritionGuidance.forTrimester(
            prePregnancyCalories: 2000,
            trimester: entry.key,
          );
          expect(draft.calories, 2000 + entry.value);
          expect(draft.pregnancyTrimester, entry.key);
          expect(draft.resolveWeek(), hasLength(7));
          final monday = draft.resolveWeek()![DateTime.monday]!;
          expect(monday.carbsGrams * 4 / monday.calories, closeTo(.50, .001));
          expect(monday.calculatedCalories, closeTo(draft.calories, .001));
        }
      },
    );

    test('keeps the reviewed WHO reference values explicit', () {
      expect(PregnancyNutritionGuidance.ironSupplementMilligrams, (30, 60));
      expect(PregnancyNutritionGuidance.folicAcidSupplementMicrograms, 400);
      expect(PregnancyNutritionGuidance.iodineMicrograms, 250);
      expect(PregnancyNutritionGuidance.calciumLowIntakeMilligrams, (
        1500,
        2000,
      ));
    });
  });

  test('draft serialization preserves all independent weekdays', () {
    final preset = dietPresets['carb-cycling']!.toDraft();
    final week = preset.resolveWeek()!;
    final source = DietDraft(
      pathwayId: preset.pathwayId,
      calories: 1000,
      fatLevel: preset.fatLevel,
      carbsByWeekday: {
        for (final entry in week.entries) entry.key: entry.value.carbsGrams / 2,
      },
      proteinByWeekday: {
        for (final entry in week.entries)
          entry.key: entry.value.proteinGrams / 2,
      },
      fatByWeekday: {
        for (final entry in week.entries) entry.key: entry.value.fatGrams / 2,
      },
    );
    final decoded = DietDraft.decode(source.encode());
    expect(decoded, isNotNull);
    expect(decoded!.pathwayId, 'carb-cycling');
    expect(decoded.carbsByWeekday, source.carbsByWeekday);
    expect(decoded.proteinByWeekday, source.proteinByWeekday);
    expect(decoded.fatByWeekday, source.fatByWeekday);
    expect(decoded.resolveWeek(), hasLength(7));
    expect(
      decoded.resolveWeek()!.values.every(
        (target) => (target.calculatedCalories - 1000).abs() < .001,
      ),
      isTrue,
    );
  });
}
