part of 'nutrition_analytics_page.dart';

class _MacrosTab extends StatelessWidget {
  const _MacrosTab({required this.totals, required this.targets});
  final NutritionAnalyticsTotals totals;
  final _NutritionTargets targets;
  @override
  Widget build(BuildContext context) {
    final knownEnergy = totals.carbs * 4 + totals.protein * 4 + totals.fats * 9;
    return ListView(
      key: const Key('nutrition-macros-tab'),
      padding: const EdgeInsets.all(20),
      children: [
        const _DayHeader(),
        const SizedBox(height: 24),
        if (!totals.isComplete(TrackedNutrient.carbohydrates) ||
            !totals.isComplete(TrackedNutrient.protein) ||
            !totals.isComplete(TrackedNutrient.fat))
          _CoverageNotice(
            text: _t(
              context,
              'Macro distribution uses evidenced carbohydrate, protein, and fat only.',
            ),
          ),
        _DistributionRow(
          label: _t(context, 'Carbohydrates'),
          value: totals.carbs * 4,
          total: knownEnergy,
          color: const Color(0xFF26B8B0),
        ),
        _DistributionRow(
          label: _t(context, 'Fat'),
          value: totals.fats * 9,
          total: knownEnergy,
          color: const Color(0xFF731A9D),
        ),
        _DistributionRow(
          label: _t(context, 'Protein'),
          value: totals.protein * 4,
          total: knownEnergy,
          color: const Color(0xFFFFB33C),
        ),
        const Divider(height: 40),
        _TableHeader(),
        _NutrientRow(
          label: _t(context, 'Carbohydrates'),
          total: totals.carbs,
          goal: targets.carbs,
          unit: 'g',
        ),
        _NutrientRow(
          label: _t(context, 'Fat'),
          total: totals.fats,
          goal: targets.fats,
          unit: 'g',
        ),
        _NutrientRow(
          label: _t(context, 'Protein'),
          total: totals.protein,
          goal: targets.protein,
          unit: 'g',
        ),
      ],
    );
  }
}
