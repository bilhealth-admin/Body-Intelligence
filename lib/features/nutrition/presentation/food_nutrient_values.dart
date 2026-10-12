part of '../food_page.dart';

class _FoodNutrientValue {
  const _FoodNutrientValue({
    required this.nutrient,
    required this.value,
    required this.unit,
  });

  final FoodNutrient nutrient;
  final double value;
  final String unit;
}

class _FoodNutrientSummary extends StatelessWidget {
  const _FoodNutrientSummary({required this.food, this.expanded = false});
  final Food food;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    if (!expanded) return _CompactFoodNutrientSummary(food: food);
    return Column(
      key: const Key('food-catalog-nutrition-facts-glass'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PremiumNutritionGroupLabel(),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in _allFoodNutrients(food))
              _NutrientValuePill(
                food: food,
                nutrientValue: value,
                expanded: true,
              ),
          ],
        ),
      ],
    );
  }
}

class _CompactFoodNutrientSummary extends StatelessWidget {
  const _CompactFoodNutrientSummary({required this.food});
  final Food food;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final summary = _summaryNutrients(food);
      final wideText = MediaQuery.textScalerOf(context).scale(1) >= 1.4;
      return Column(
        key: const Key('food-catalog-macros-glass'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumNutritionGroupLabel(),
          if (wideText || constraints.maxWidth < 280)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in summary)
                  SizedBox(
                    width: (constraints.maxWidth - 8) / 2,
                    child: _CompactNutrientMetric(
                      food: food,
                      nutrientValue: value,
                    ),
                  ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final value in summary)
                  Expanded(
                    child: _CompactNutrientMetric(
                      food: food,
                      nutrientValue: value,
                    ),
                  ),
              ],
            ),
        ],
      );
    },
  );
}

class _CompactNutrientMetric extends StatelessWidget {
  const _CompactNutrientMetric({
    required this.food,
    required this.nutrientValue,
  });
  final Food food;
  final _FoodNutrientValue nutrientValue;

  @override
  Widget build(BuildContext context) => _NutrientValuePill(
    food: food,
    nutrientValue: nutrientValue,
    expanded: false,
  );
}

class _NutrientValuePill extends StatelessWidget {
  const _NutrientValuePill({
    required this.food,
    required this.nutrientValue,
    required this.expanded,
  });
  final Food food;
  final _FoodNutrientValue nutrientValue;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final known = _foodNutrientKnown(food, nutrientValue.nutrient);
    final label = _foodNutrientLabel(context, nutrientValue.nutrient);
    final value = known
        ? _localizedNutrientNumber(context, nutrientValue.value)
        : _foodValueCopy(context, 'Not available');
    final paid = known && nutrientValue.nutrient != FoodNutrient.calories;
    final valueText = Text(
      value,
      textDirection: known ? TextDirection.ltr : null,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    );
    return Container(
      constraints: BoxConstraints(minWidth: expanded ? 126 : 0),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label · ${nutrientValue.unit}',
            key: Key('food-nutrient-name-${nutrientValue.nutrient.name}'),
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          if (paid)
            PremiumNutritionGlass(
              key: Key('food-nutrient-value-${nutrientValue.nutrient.name}'),
              compact: true,
              showLabel: false,
              borderRadius: 8,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: valueText,
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: valueText,
              ),
            ),
        ],
      ),
    );
  }
}

List<_FoodNutrientValue> _summaryNutrients(Food food) => [
  _FoodNutrientValue(
    nutrient: FoodNutrient.calories,
    value: food.calories,
    unit: 'kcal',
  ),
  _FoodNutrientValue(
    nutrient: FoodNutrient.protein,
    value: food.protein,
    unit: 'g',
  ),
  _FoodNutrientValue(
    nutrient: FoodNutrient.carbohydrates,
    value: food.carbs,
    unit: 'g',
  ),
  _FoodNutrientValue(nutrient: FoodNutrient.fat, value: food.fats, unit: 'g'),
];

List<_FoodNutrientValue> _allFoodNutrients(Food food) => [
  ..._summaryNutrients(food),
  _FoodNutrientValue(
    nutrient: FoodNutrient.sodium,
    value: food.sodium,
    unit: 'mg',
  ),
  _FoodNutrientValue(
    nutrient: FoodNutrient.potassium,
    value: food.potassium,
    unit: 'mg',
  ),
  _FoodNutrientValue(
    nutrient: FoodNutrient.fiber,
    value: food.fiber,
    unit: 'g',
  ),
  _FoodNutrientValue(
    nutrient: FoodNutrient.sugar,
    value: food.sugar,
    unit: 'g',
  ),
  _FoodNutrientValue(
    nutrient: FoodNutrient.calcium,
    value: food.calcium,
    unit: 'mg',
  ),
  _FoodNutrientValue(
    nutrient: FoodNutrient.magnesium,
    value: food.magnesium,
    unit: 'mg',
  ),
  _FoodNutrientValue(
    nutrient: FoodNutrient.phosphorus,
    value: food.phosphorus,
    unit: 'mg',
  ),
  _FoodNutrientValue(nutrient: FoodNutrient.iron, value: food.iron, unit: 'mg'),
  _FoodNutrientValue(
    nutrient: FoodNutrient.vitaminC,
    value: food.vitaminC,
    unit: 'mg',
  ),
  for (final nutrient in FoodNutrient.values.where(
    (n) => n.index > FoodNutrient.vitaminC.index,
  ))
    _FoodNutrientValue(
      nutrient: nutrient,
      value: FoodBasisEvidence.read(food).value(nutrient) ?? 0,
      unit: CoachFoodNutrients.units[nutrient]!,
    ),
];

bool _foodNutrientKnown(Food food, FoodNutrient nutrient) {
  if (food.foodEvidenceJson != null ||
      nutrient.index > FoodNutrient.vitaminC.index) {
    return FoodBasisEvidence.read(food).value(nutrient) != null;
  }
  final value = switch (nutrient) {
    FoodNutrient.calories => food.calories,
    FoodNutrient.protein => food.protein,
    FoodNutrient.carbohydrates => food.carbs,
    FoodNutrient.fat => food.fats,
    FoodNutrient.fiber => food.fiber,
    FoodNutrient.sugar => food.sugar,
    FoodNutrient.sodium => food.sodium,
    FoodNutrient.potassium => food.potassium,
    FoodNutrient.calcium => food.calcium,
    FoodNutrient.magnesium => food.magnesium,
    FoodNutrient.phosphorus => food.phosphorus,
    FoodNutrient.iron => food.iron,
    FoodNutrient.vitaminC => food.vitaminC,
    _ => 0,
  };
  final maskTracksNutrient =
      nutrient != FoodNutrient.iron && nutrient != FoodNutrient.vitaminC;
  if (maskTracksNutrient &&
      UnifiedFood.evidenceFromMask(food.nutrientEvidenceMask, nutrient)) {
    return true;
  }
  // Old pre-evidence rows can still prove a non-zero value. Zero without a bit
  // is ambiguous and must never be presented as a measured nutrient value.
  return value != 0;
}

String _localizedNutrientNumber(BuildContext context, double value) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final pattern = value.abs() >= 100 ? '0' : '0.#';
  return NumberFormat(pattern, locale).format(value);
}

String _foodNutrientLabel(BuildContext context, FoodNutrient nutrient) {
  final key = switch (nutrient) {
    FoodNutrient.calories => 'Calories',
    FoodNutrient.protein => 'Protein',
    FoodNutrient.carbohydrates => 'Carbs',
    FoodNutrient.fat => 'Fat',
    FoodNutrient.fiber => 'Fiber',
    FoodNutrient.sugar => 'Sugar',
    FoodNutrient.sodium => 'Sodium',
    FoodNutrient.potassium => 'Potassium',
    FoodNutrient.calcium => 'Calcium',
    FoodNutrient.magnesium => 'Magnesium',
    FoodNutrient.phosphorus => 'Phosphorus',
    FoodNutrient.iron => 'Iron',
    FoodNutrient.vitaminC => 'Vitamin C',
    FoodNutrient.saturatedFat => 'Saturated fat',
    FoodNutrient.polyunsaturatedFat => 'Polyunsaturated fat',
    FoodNutrient.monounsaturatedFat => 'Monounsaturated fat',
    FoodNutrient.transFat => 'Trans fat',
    FoodNutrient.cholesterol => 'Cholesterol',
    FoodNutrient.vitaminA => 'Vitamin A',
  };
  return _foodValueCopy(context, key);
}
