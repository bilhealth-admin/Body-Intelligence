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
    final values = _allFoodNutrients(food);
    final calories = values
        .where((value) => value.nutrient == FoodNutrient.calories)
        .toList(growable: false);
    final premiumValues = values
        .where((value) => value.nutrient != FoodNutrient.calories)
        .toList(growable: false);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in calories)
          _NutrientValuePill(
            food: food,
            nutrientValue: value,
            expanded: expanded,
          ),
        if (premiumValues.isNotEmpty)
          PremiumNutritionGlass(
            key: Key(
              expanded
                  ? 'food-catalog-nutrition-facts-glass'
                  : 'food-catalog-macros-glass',
            ),
            compact: !expanded,
            showLabel: false,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: premiumValues
                  .map(
                    (value) => _NutrientValuePill(
                      food: food,
                      nutrientValue: value,
                      expanded: expanded,
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
      ],
    );
  }
}

class _CompactFoodNutrientSummary extends StatelessWidget {
  const _CompactFoodNutrientSummary({required this.food});

  final Food food;

  @override
  Widget build(BuildContext context) {
    final summary = _summaryNutrients(food);
    final calories = summary.first;
    final macros = summary
        .where(
          (value) => const {
            FoodNutrient.protein,
            FoodNutrient.carbohydrates,
            FoodNutrient.fat,
          }.contains(value.nutrient),
        )
        .toList(growable: false);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 88,
          child: _CompactNutrientMetric(food: food, nutrientValue: calories),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: PremiumNutritionGlass(
            key: const Key('food-catalog-macros-glass'),
            compact: true,
            showLabel: false,
            borderRadius: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: .56),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    for (final macro in macros)
                      Expanded(
                        child: _CompactNutrientMetric(
                          food: food,
                          nutrientValue: macro,
                          bare: true,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactNutrientMetric extends StatelessWidget {
  const _CompactNutrientMetric({
    required this.food,
    required this.nutrientValue,
    this.bare = false,
  });

  final Food food;
  final _FoodNutrientValue nutrientValue;
  final bool bare;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final known = _foodNutrientKnown(food, nutrientValue.nutrient);
    final label = _foodNutrientLabel(context, nutrientValue.nutrient);
    final value = known
        ? '${_localizedNutrientNumber(context, nutrientValue.value)} ${nutrientValue.unit}'
        : '—';
    final metric = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                textDirection: TextDirection.ltr,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      label: '$label, $value',
      child: bare
          ? metric
          : DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: .42),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: .16),
                ),
              ),
              child: metric,
            ),
    );
  }
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
        ? '${_localizedNutrientNumber(context, nutrientValue.value)} ${nutrientValue.unit}'
        : _foodValueCopy(context, 'Not available');
    return Semantics(
      label: '$label, $value',
      child: Container(
        constraints: BoxConstraints(minWidth: expanded ? 126 : 0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: known
              ? scheme.primaryContainer.withValues(alpha: 0.42)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: known
                ? scheme.primary.withValues(alpha: 0.16)
                : scheme.outlineVariant,
          ),
        ),
        child: RichText(
          text: TextSpan(
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            children: [
              TextSpan(text: '$label  '),
              TextSpan(
                text: value,
                style: TextStyle(
                  color: known ? scheme.onSurface : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
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
];

bool _foodNutrientKnown(Food food, FoodNutrient nutrient) {
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
  };
  return _foodValueCopy(context, key);
}
