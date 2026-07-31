import 'package:body_intelligence_log/features/nutrition/domain/meal_builder.dart';
import 'package:body_intelligence_log/features/nutrition/domain/meal_template.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_builder_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P6-001 and P6-002 public contracts remain available', () {
    final template = MealTemplate(
      id: 'template',
      name: 'Breakfast',
      mealType: 'breakfast',
      items: const <MealTemplateItem>[],
      createdAt: DateTime.utc(2026, 7, 23),
    );
    const draft = MealBuilderDraft(
      name: 'Lunch',
      mealType: 'lunch',
      items: <MealBuilderItemDraft>[
        MealBuilderItemDraft(foodId: 1, quantityGrams: 100, position: 1),
      ],
    );

    expect(template.name, 'Breakfast');
    expect(const MealBuilderEngine().validate(draft).isValid, isTrue);
  });
}
