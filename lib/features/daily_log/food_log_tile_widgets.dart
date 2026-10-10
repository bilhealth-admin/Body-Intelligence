part of 'food_log_page.dart';

/// Food browse tiles and empty-state widgets separated from route handling.
extension _FoodLogTileWidgets on _FoodLogPageState {
  Widget _buildFoodTile(
    BuildContext context,
    Food food, {
    required String localeTag,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;
    final name = FoodPresentationLocalizer.foodName(
      name: food.name,
      arabicName: food.arabicName,
      localeTag: localeTag,
      isCustom: food.isCustom,
      source: food.source,
    );
    return Card(
      key: Key('food-log-food-${food.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 6, 8, 6),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: food.verified
              ? const Color(0xFFE2F8EC)
              : accent.withValues(alpha: .10),
          child: Icon(
            food.verified
                ? Icons.verified_rounded
                : food.isCustom
                ? Icons.person_rounded
                : Icons.shield_outlined,
            color: food.verified ? const Color(0xFF087A43) : accent,
          ),
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${food.calories.round()} kcal · ${food.servingSize} ${food.servingUnit}',
        ),
        trailing: IconButton(
          key: Key('food-log-add-${food.id}'),
          tooltip: _t(context, 'Add'),
          onPressed: () => _addFood(context, food),
          icon: const Icon(Icons.add_circle_rounded, color: Color(0xFF1677D2)),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 70),
    child: Column(
      children: [
        const BilSemanticIconBadge(
          kind: BilSemanticIconKind.foodSearch,
          size: 74,
        ),
        const SizedBox(height: 20),
        Text(
          _t(context, 'No foods found'),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _t(context, 'Create and save your favorites for quick logging.'),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
