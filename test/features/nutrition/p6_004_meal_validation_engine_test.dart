import 'package:body_intelligence_log/features/nutrition/domain/meal_builder.dart';
import 'package:body_intelligence_log/features/nutrition/domain/meal_validation.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_validation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = MealValidationEngine();

  test('valid meal produces a safe report', () {
    const draft = MealBuilderDraft(
      name: 'Lunch',
      mealType: 'lunch',
      items: <MealBuilderItemDraft>[
        MealBuilderItemDraft(foodId: 1, quantityGrams: 150, position: 1),
      ],
    );

    final report = engine.validate(draft);

    expect(report.issues, isEmpty);
    expect(report.isSafeToPersist, isTrue);
  });

  test('invalid values are errors and duplicate food is a warning', () {
    const draft = MealBuilderDraft(
      name: 'Unsafe',
      mealType: 'dinner',
      items: <MealBuilderItemDraft>[
        MealBuilderItemDraft(foodId: 2, quantityGrams: 6000, position: 1),
        MealBuilderItemDraft(foodId: 2, quantityGrams: -1, position: 1),
      ],
    );

    final report = engine.validate(draft);

    expect(report.hasErrors, isTrue);
    expect(
      report.issues.map((issue) => issue.kind),
      containsAll(<MealValidationIssueKind>[
        MealValidationIssueKind.duplicateFood,
        MealValidationIssueKind.invalidQuantity,
        MealValidationIssueKind.duplicatePosition,
        MealValidationIssueKind.excessiveQuantity,
      ]),
    );
    expect(report.isSafeToPersist, isFalse);
  });

  test('validation is deterministic and read-only', () {
    const draft = MealBuilderDraft(
      name: 'Snack',
      mealType: 'snack',
      items: <MealBuilderItemDraft>[
        MealBuilderItemDraft(foodId: 3, quantityGrams: 100, position: 1),
      ],
    );

    final first = engine.validate(draft);
    final second = engine.validate(draft);

    expect(
      second.issues.map((issue) => issue.kind),
      first.issues.map((issue) => issue.kind),
    );
    expect(draft.items.single.quantityGrams, 100);
  });
}
