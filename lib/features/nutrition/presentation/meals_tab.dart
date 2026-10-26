part of 'meals_recipes_foods_page.dart';

final myMealHistoryProvider = StreamProvider.autoDispose<List<MealWithItems>>(
  (ref) => ref
      .watch(mealRepositoryProvider)
      .watchAll()
      .map(
        (rows) =>
            rows.where((row) => row.items.isNotEmpty).toList()
              ..sort((a, b) => b.meal.date.compareTo(a.meal.date)),
      ),
);

class _MealsTab extends ConsumerWidget {
  const _MealsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(myMealHistoryProvider);
    final meals = history.value ?? const <MealWithItems>[];
    String t(String en, String ar) => nutritionEntryText(context, en, ar);
    return ListView(
      key: const Key('my-meals-tab'),
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                kind: BilSemanticIconKind.meal,
                label: _c(context, 'Create meal'),
                onTap: () => Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => MealBuilderPage(
                      initialDate: ref.read(selectedLogDateProvider),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                kind: BilSemanticIconKind.meal,
                iconOverride: Icons.content_copy_rounded,
                label: _c(context, 'Copy previous meal'),
                onTap: meals.isEmpty ? null : () => _choose(context, ref),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          t(
            'Your recorded meals appear here, including meals recorded only once. Choose a meal, review its foods, and choose the copy date and meal type.',
            'تظهر هنا وجباتك المسجّلة، حتى التي سُجّلت مرة واحدة. اختر الوجبة، راجع أطعمتها ثم حدّد تاريخ النسخ ونوع الوجبة.',
          ),
        ),
        const SizedBox(height: 14),
        if (history.isLoading && !history.hasValue)
          const Center(child: BilFeatureWelcomeStatus()),
        if (history.hasError)
          TextButton.icon(
            onPressed: () => ref.invalidate(myMealHistoryProvider),
            icon: const BilNavigationFeedback(child: Icon(Icons.refresh)),
            label: Text(
              t(
                'Could not load meals. Retry',
                'تعذر تحميل الوجبات. أعد المحاولة',
              ),
            ),
          ),
        if (!history.isLoading && !history.hasError && meals.isEmpty)
          _EmptyState(
            icon: Icons.ramen_dining_outlined,
            title: t('Create your first meal', 'أنشئ وجبتك الأولى'),
            body: t(
              'Use Create meal to combine real foods and amounts. Nothing is saved by opening this page.',
              'استخدم «إنشاء وجبة» لجمع أطعمة وكميات فعلية. فتح الصفحة وحده لا يسجّل شيئًا.',
            ),
          ),
        for (final meal in meals.take(100))
          BilPearlMaterialCard(
            child: ListTile(
              title: Text(meal.meal.name),
              subtitle: Text(
                '${MaterialLocalizations.of(context).formatMediumDate(meal.meal.date)} · '
                '${nutritionMealType(context, meal.meal.type)} · ${meal.items.length} ${t('items', 'أطعمة')}',
              ),
              onTap: () => _copy(context, ref, meal),
              trailing: IconButton(
                tooltip: _c(context, 'Copy previous meal'),
                icon: const Icon(Icons.content_copy_outlined),
                onPressed: () => _copy(context, ref, meal),
              ),
            ),
          ),
        if (meals.length > 100)
          Text(t('Showing the most recent 100 meals.', 'تُعرض أحدث 100 وجبة.')),
      ],
    );
  }

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(mealRepositoryProvider);
    final selected = await showBilModalBottomSheet<MealWithItems>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .7,
        child: Consumer(
          builder: (context, ref, _) {
            if (!identical(repository, ref.watch(mealRepositoryProvider))) {
              return const SizedBox.shrink();
            }
            return ref
                .watch(myMealHistoryProvider)
                .when(
                  loading: () => const Center(child: BilFeatureWelcomeStatus()),
                  error: (_, _) => Center(
                    child: TextButton(
                      onPressed: () => ref.invalidate(myMealHistoryProvider),
                      child: Text(_c(context, 'Retry')),
                    ),
                  ),
                  data: (rows) => ListView(
                    children: [
                      ListTile(title: Text(_c(context, 'Copy previous meal'))),
                      for (final row in rows.take(100))
                        ListTile(
                          title: Text(row.meal.name),
                          subtitle: Text(
                            '${MaterialLocalizations.of(context).formatMediumDate(row.meal.date)} · '
                            '${nutritionMealType(context, row.meal.type)} · ${row.items.length}',
                          ),
                          onTap: () => Navigator.pop(sheetContext, row),
                        ),
                    ],
                  ),
                );
          },
        ),
      ),
    );
    if (context.mounted &&
        selected != null &&
        identical(repository, ref.read(mealRepositoryProvider))) {
      await _copy(context, ref, selected);
    }
  }

  Future<void> _copy(
    BuildContext context,
    WidgetRef ref,
    MealWithItems source,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MealCopyPage(
          source: source,
          initialDate: ref.read(selectedLogDateProvider),
        ),
      ),
    );
  }
}
