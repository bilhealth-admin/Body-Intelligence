part of 'nutrition_analytics_page.dart';

class _FoodAnalysisTab extends StatefulWidget {
  const _FoodAnalysisTab({required this.meals});

  final List<MealWithItems> meals;

  @override
  State<_FoodAnalysisTab> createState() => _FoodAnalysisTabState();
}

class _FoodAnalysisTabState extends State<_FoodAnalysisTab> {
  TrackedNutrient selected = TrackedNutrient.protein;

  static const choices = <TrackedNutrient>[
    TrackedNutrient.calories,
    TrackedNutrient.protein,
    TrackedNutrient.carbohydrates,
    TrackedNutrient.fat,
    TrackedNutrient.fiber,
    TrackedNutrient.sugar,
    TrackedNutrient.sodium,
    TrackedNutrient.potassium,
  ];

  @override
  Widget build(BuildContext context) {
    final snapshots = <FoodAnalysisItemSnapshot>[
      for (final meal in widget.meals)
        for (final item in meal.items)
          FoodAnalysisItemSnapshot(
            foodId: item.foodId,
            foodName:
                meal.foodsById[item.foodId]?.name ??
                _t(context, 'Unknown food'),
            nutrientEvidenceMask: item.nutrientEvidenceMask,
            source: item.foodSourceSnapshot,
            verified: item.foodVerifiedSnapshot,
            values: {
              TrackedNutrient.calories: item.calories,
              TrackedNutrient.protein: item.protein,
              TrackedNutrient.carbohydrates: item.carbs,
              TrackedNutrient.fat: item.fats,
              TrackedNutrient.fiber: item.fiber,
              TrackedNutrient.sugar: item.sugar,
              TrackedNutrient.sodium: item.sodium,
              TrackedNutrient.potassium: item.potassium,
              TrackedNutrient.calcium: item.calcium,
              TrackedNutrient.magnesium: item.magnesium,
              TrackedNutrient.phosphorus: item.phosphorus,
            },
          ),
    ];
    final analysis = FoodAnalysisEngine.analyze(
      items: snapshots,
      nutrient: selected,
    );
    final unit = _unitFor(selected);
    return ListView(
      key: const Key('nutrition-food-analysis-tab'),
      padding: const EdgeInsets.all(20),
      children: [
        const _DayHeader(),
        const SizedBox(height: 18),
        Text(
          _t(context, 'Choose a nutrient'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<TrackedNutrient>(
          initialValue: selected,
          items: [
            for (final nutrient in choices)
              DropdownMenuItem(
                value: nutrient,
                child: Text(_t(context, _nutrientKey(nutrient))),
              ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => selected = value);
          },
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: _t(context, 'Nutrient'),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _t(context, 'Top contributors'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          _coverageText(context, analysis),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (analysis.contributors.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(_t(context, 'No evidenced values are available.')),
            ),
          )
        else
          for (final contributor in analysis.contributors)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            contributor.foodName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          '${contributor.value.round()} $unit · '
                          '${(contributor.share * 100).round()}%',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: contributor.share),
                    const SizedBox(height: 8),
                    Text(
                      '${_t(context, 'Logged entries')}: '
                      '${contributor.entryCount} · '
                      '${contributor.allSnapshotsVerified ? _t(context, 'Verified snapshot') : _t(context, 'Unverified snapshot')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _t(
                context,
                'This analysis describes recorded nutrient contributions. It does not label foods as good or bad.',
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _coverageText(BuildContext context, FoodNutrientAnalysis analysis) {
    if (analysis.coverage == FoodAnalysisCoverage.none) {
      return _t(context, 'No logged item has evidence for this nutrient.');
    }
    final base =
        '${_t(context, 'Known total')}: '
        '${analysis.knownTotal.round()} ${_unitFor(selected)}';
    if (analysis.unknownEntryCount == 0) return base;
    return '$base · ${_t(context, 'Entries with unknown values')}: '
        '${analysis.unknownEntryCount}';
  }
}

String _unitFor(TrackedNutrient nutrient) => switch (nutrient) {
  TrackedNutrient.calories => 'kcal',
  TrackedNutrient.sodium ||
  TrackedNutrient.potassium ||
  TrackedNutrient.calcium ||
  TrackedNutrient.magnesium ||
  TrackedNutrient.phosphorus => 'mg',
  _ => 'g',
};

String _nutrientKey(TrackedNutrient nutrient) => switch (nutrient) {
  TrackedNutrient.calories => 'Calories',
  TrackedNutrient.protein => 'Protein',
  TrackedNutrient.carbohydrates => 'Carbohydrates',
  TrackedNutrient.fat => 'Fat',
  TrackedNutrient.fiber => 'Fiber',
  TrackedNutrient.sugar => 'Sugar',
  TrackedNutrient.sodium => 'Sodium',
  TrackedNutrient.potassium => 'Potassium',
  TrackedNutrient.calcium => 'Calcium',
  TrackedNutrient.magnesium => 'Magnesium',
  TrackedNutrient.phosphorus => 'Phosphorus',
};
