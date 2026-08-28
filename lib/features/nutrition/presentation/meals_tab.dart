part of 'meals_recipes_foods_page.dart';

class _MealsTab extends ConsumerWidget {
  const _MealsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = <UsualMealCandidate>[];
    var loading = false;
    Object? error;
    for (final type in const ['breakfast', 'lunch', 'dinner', 'snack']) {
      final result = ref.watch(usualMealsProvider(type));
      loading = loading || result.isLoading;
      error ??= result.error;
      candidates.addAll(result.value ?? const []);
    }
    return ListView(
      key: const Key('my-meals-tab'),
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.add_rounded,
                label: _c(context, 'Create meal'),
                onTap: () => context.push('/daily-log'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.content_copy_rounded,
                label: _c(context, 'Copy previous meal'),
                onTap: candidates.isEmpty
                    ? null
                    : () => _copy(context, ref, candidates.first),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (loading) const Center(child: CircularProgressIndicator()),
        if (error != null)
          Text(_c(context, 'Saved meals could not be loaded.')),
        if (!loading && error == null && candidates.isEmpty)
          _EmptyState(
            icon: Icons.ramen_dining_rounded,
            title: _c(context, 'Log your go-to meals faster'),
            body: _c(
              context,
              'Meals repeated in your diary appear here for quick reuse.',
            ),
          ),
        for (final candidate in candidates)
          Card(
            child: ListTile(
              title: Text(candidate.source.meal.name),
              subtitle: Text(
                '${candidate.occurrences} × · ${candidate.source.items.length} ${_c(context, 'items')}',
              ),
              trailing: IconButton(
                tooltip: _c(context, 'Copy to today'),
                icon: const Icon(Icons.add_circle_outline_rounded),
                onPressed: () => _copy(context, ref, candidate),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _copy(
    BuildContext context,
    WidgetRef ref,
    UsualMealCandidate candidate,
  ) async {
    try {
      final repository = ref.read(mealRepositoryProvider);
      final template = repository.createTemplateFromHistoricalMeal(
        meal: candidate.source,
        templateId: 'reuse-${candidate.source.meal.uuid}',
        templateName: candidate.source.meal.name,
      );
      await repository.instantiateTemplate(
        template: template,
        date: DateTime.now(),
      );
      ref.invalidate(dailyMealsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_c(context, 'Meal copied to today.'))),
      );
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_c(context, 'This meal is already present today.')),
        ),
      );
    }
  }
}
