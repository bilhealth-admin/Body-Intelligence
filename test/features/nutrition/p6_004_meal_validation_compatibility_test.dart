import 'package:body_intelligence_log/features/nutrition/domain/meal_builder.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_builder_engine.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_validation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('meal builder and safety validation remain compatible', () {
    const draft = MealBuilderDraft(
      name: ' Breakfast ',
      mealType: 'breakfast',
      items: <MealBuilderItemDraft>[
        MealBuilderItemDraft(foodId: 1, quantityGrams: 80, position: 2),
        MealBuilderItemDraft(foodId: 2, quantityGrams: 120, position: 1),
      ],
    );

    const builder = MealBuilderEngine();
    const validator = MealValidationEngine();
    final canonical = builder.canonicalize(draft);
    final report = validator.validate(canonical);

    expect(canonical.name, 'Breakfast');
    expect(canonical.items.map((item) => item.position), <int>[1, 2]);
    expect(report.isSafeToPersist, isTrue);
  });
}
