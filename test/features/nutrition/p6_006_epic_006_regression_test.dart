import 'package:body_intelligence_log/features/nutrition/domain/meal_builder.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_builder_engine.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_validation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Epic 006 builder and validation contracts remain compatible', () {
    const draft = MealBuilderDraft(
      name: ' Dinner ',
      mealType: 'dinner',
      items: <MealBuilderItemDraft>[
        MealBuilderItemDraft(foodId: 2, quantityGrams: 120, position: 9),
        MealBuilderItemDraft(foodId: 1, quantityGrams: 80, position: 4),
      ],
    );

    const builder = MealBuilderEngine();
    const validator = MealValidationEngine();
    final canonical = builder.canonicalize(draft);
    final validation = validator.validate(canonical);

    expect(canonical.name, 'Dinner');
    expect(canonical.items.map((item) => item.position), <int>[1, 2]);
    expect(validation.isSafeToPersist, isTrue);
  });
}
