part of 'dashboard_grid.dart';

class _DashboardNutrientGoalCards extends StatelessWidget {
  const _DashboardNutrientGoalCards({
    required this.selected,
    required this.values,
    required this.goals,
  });

  final Set<String> selected;
  final Map<String, double?> values;
  final Map<String, double?> goals;

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    String label(String id) => switch ((language, id)) {
      ('ar', DashboardNutrientGoalIds.protein) => 'البروتين',
      ('ar', DashboardNutrientGoalIds.carbohydrates) => 'الكربوهيدرات',
      ('ar', DashboardNutrientGoalIds.fat) => 'الدهون',
      ('ar', DashboardNutrientGoalIds.fiber) => 'الألياف',
      ('ar', DashboardNutrientGoalIds.sodium) => 'الصوديوم',
      ('ar', DashboardNutrientGoalIds.potassium) => 'البوتاسيوم',
      ('fr', DashboardNutrientGoalIds.protein) => 'Protéines',
      ('fr', DashboardNutrientGoalIds.carbohydrates) => 'Glucides',
      ('fr', DashboardNutrientGoalIds.fat) => 'Lipides',
      ('fr', DashboardNutrientGoalIds.fiber) => 'Fibres',
      ('fr', DashboardNutrientGoalIds.sodium) => 'Sodium',
      ('fr', DashboardNutrientGoalIds.potassium) => 'Potassium',
      ('es', DashboardNutrientGoalIds.protein) => 'Proteína',
      ('es', DashboardNutrientGoalIds.carbohydrates) => 'Carbohidratos',
      ('es', DashboardNutrientGoalIds.fat) => 'Grasas',
      ('es', DashboardNutrientGoalIds.fiber) => 'Fibra',
      ('es', DashboardNutrientGoalIds.sodium) => 'Sodio',
      ('es', DashboardNutrientGoalIds.potassium) => 'Potasio',
      ('tr', DashboardNutrientGoalIds.protein) => 'Protein',
      ('tr', DashboardNutrientGoalIds.carbohydrates) => 'Karbonhidratlar',
      ('tr', DashboardNutrientGoalIds.fat) => 'Yağ',
      ('tr', DashboardNutrientGoalIds.fiber) => 'Lif',
      ('tr', DashboardNutrientGoalIds.sodium) => 'Sodyum',
      ('tr', DashboardNutrientGoalIds.potassium) => 'Potasyum',
      (_, DashboardNutrientGoalIds.carbohydrates) => context.strings.text(
        'Carbohydrates',
      ),
      (_, DashboardNutrientGoalIds.fat) => context.strings.text('Fat'),
      (_, DashboardNutrientGoalIds.fiber) => context.strings.text('Fiber'),
      (_, DashboardNutrientGoalIds.sodium) => context.strings.text('Sodium'),
      (_, DashboardNutrientGoalIds.potassium) => context.strings.text(
        'Potassium',
      ),
      _ => context.strings.text('Protein'),
    };
    final ids = DashboardNutrientGoalIds.all.where(selected.contains).toList();
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          switch (language) {
            'ar' => 'أهداف المغذيات',
            'fr' => 'Objectifs nutritionnels',
            'es' => 'Objetivos nutricionales',
            'tr' => 'Besin hedefleri',
            _ => context.strings.text('Nutrient goals'),
          },
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.45,
          ),
          itemCount: ids.length,
          itemBuilder: (context, index) {
            final id = ids[index];
            final value = values[id];
            final goal = goals[id];
            final progress = value == null || goal == null || goal <= 0
                ? null
                : (value / goal).clamp(0.0, 1.0);
            final milligrams =
                id == DashboardNutrientGoalIds.sodium ||
                id == DashboardNutrientGoalIds.potassium;
            final unit = milligrams ? 'mg' : 'g';
            final summary = value == null || goal == null
                ? context.strings.text(
                    'Goal or nutrition evidence is unavailable',
                  )
                : '${value.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)} $unit';
            return Semantics(
              key: Key('dashboard-nutrient-card-$id'),
              button: true,
              label:
                  '${label(id)}. $summary. ${context.strings.text('Edit goal')}',
              child: ExcludeSemantics(
                child: Card(
                  child: InkWell(
                    onTap: () => context.push('/settings/nutrition-goals'),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            label(id),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              value == null || goal == null ? '—' : summary,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          LinearProgressIndicator(
                            value: progress ?? 0,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(999),
                            color: progress == null
                                ? Theme.of(context).colorScheme.outlineVariant
                                : progress >= .8
                                ? const Color(0xFF2E9D62)
                                : progress >= .4
                                ? const Color(0xFFF2A23A)
                                : const Color(0xFFE57B25),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
    return content;
  }
}
