part of 'meals_recipes_foods_page.dart';

class _RecipesTab extends ConsumerWidget {
  const _RecipesTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(trustedRecipesProvider);
    return ListView(
      key: const Key('my-recipes-tab'),
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            for (final action in [
              (Icons.add_rounded, 'Create recipe'),
              (Icons.explore_outlined, 'Discover'),
              (Icons.file_download_outlined, 'Import'),
            ]) ...[
              Expanded(
                child: _ActionCard(
                  icon: action.$1,
                  label: _c(context, action.$2),
                  onTap: () => action.$2 == 'Discover'
                      ? context.push('/wellness/recipes')
                      : _showAddRecipeSheet(context),
                ),
              ),
              if (action.$2 != 'Import') const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 32),
        if (saved.isLoading) const Center(child: CircularProgressIndicator()),
        if (saved.hasError) Text(_recipeListCopy(context, 'loadFailed')),
        if (saved.value?.isEmpty ?? true)
          _EmptyState(
            icon: Icons.menu_book_rounded,
            title: _c(context, 'Build your recipe collection'),
            body: _c(
              context,
              'Discover local recipes and save favorites. Calculated nutrition is labeled and never invented.',
            ),
          ),
        for (final savedRecipe in saved.value ?? const [])
          Card(
            child: ListTile(
              leading: Icon(
                savedRecipe.recipe.nutrition == null
                    ? Icons.menu_book_outlined
                    : Icons.calculate_outlined,
              ),
              title: Text(savedRecipe.recipe.name),
              subtitle: Text(
                '${savedRecipe.recipe.servings} ${_recipeListCopy(context, 'servings')} · ${savedRecipe.recipe.totalMinutes} min',
              ),
              trailing: PopupMenuButton<String>(
                tooltip: _recipeListCopy(context, 'recipeActions'),
                onSelected: (action) =>
                    _addToDiary(context, ref, savedRecipe, action),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: '_edit',
                    child: Text(_recipeListCopy(context, 'edit')),
                  ),
                  PopupMenuItem(
                    value: '_delete',
                    child: Text(_recipeListCopy(context, 'delete')),
                  ),
                  if (savedRecipe.recipe.nutrition == null)
                    PopupMenuItem<String>(
                      enabled: false,
                      child: Text(
                        _recipeListCopy(context, 'nutritionRequired'),
                      ),
                    )
                  else
                    for (final type in const [
                      'breakfast',
                      'lunch',
                      'dinner',
                      'snack',
                    ])
                      PopupMenuItem(
                        value: type,
                        child: Text(_recipeListCopy(context, type)),
                      ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addToDiary(
    BuildContext context,
    WidgetRef ref,
    SavedTrustedRecipe savedRecipe,
    String mealType,
  ) async {
    if (mealType == '_edit') {
      context.push('/nutrition/recipes/import?recipeId=${savedRecipe.id}');
      return;
    }
    if (mealType == '_delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(_recipeListCopy(dialogContext, 'deleteTitle')),
          content: Text(_recipeListCopy(dialogContext, 'deleteBody')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_recipeListCopy(dialogContext, 'cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_recipeListCopy(dialogContext, 'delete')),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await ref.read(trustedRecipeRepositoryProvider).delete(savedRecipe.id);
      ref.invalidate(trustedRecipesProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_recipeListCopy(context, 'deleted'))),
      );
      return;
    }
    await TrustedRecipeDiaryService(
      ref.read(foodRepositoryProvider),
      ref.read(mealRepositoryProvider),
    ).addServing(saved: savedRecipe, date: DateTime.now(), mealType: mealType);
    ref.invalidate(dailyMealsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_recipeListCopy(context, 'addedToDiary'))),
    );
  }

  static Future<void> _showAddRecipeSheet(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              key: const Key('add-recipe-choice-sheet'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _recipeChoiceCopy(sheetContext, 'title'),
                  style: Theme.of(sheetContext).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 18),
                _RecipeChoiceTile(
                  key: const Key('import-recipe-from-web'),
                  icon: Icons.language_rounded,
                  title: _recipeChoiceCopy(sheetContext, 'webTitle'),
                  subtitle: _recipeChoiceCopy(sheetContext, 'webBody'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/nutrition/recipes/import');
                  },
                ),
                const SizedBox(height: 12),
                _RecipeChoiceTile(
                  key: const Key('enter-recipe-manually'),
                  icon: Icons.edit_note_rounded,
                  title: _recipeChoiceCopy(sheetContext, 'manualTitle'),
                  subtitle: _recipeChoiceCopy(sheetContext, 'manualBody'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/wellness/recipes');
                  },
                ),
              ],
            ),
          ),
        ),
      );
}

String _recipeListCopy(BuildContext context, String key) {
  const copy = <String, Map<String, String>>{
    'en': {
      'loadFailed': 'Saved recipes could not be loaded.',
      'servings': 'servings',
      'addToDiary': 'Add one serving to diary',
      'recipeActions': 'Recipe actions',
      'addedToDiary': 'One recipe serving was added to today.',
      'nutritionRequired':
          'Calculated nutrition with sources is required before logging.',
      'breakfast': 'Breakfast',
      'edit': 'Edit recipe',
      'delete': 'Delete recipe',
      'deleteTitle': 'Delete this recipe?',
      'deleteBody': 'This removes the saved recipe from this device.',
      'cancel': 'Cancel',
      'deleted': 'Recipe deleted.',
      'lunch': 'Lunch',
      'dinner': 'Dinner',
      'snack': 'Snack',
    },
    'ar': {
      'loadFailed': 'تعذر تحميل الوصفات المحفوظة.',
      'servings': 'حصص',
      'addToDiary': 'أضف حصة إلى اليوميات',
      'recipeActions': 'إجراءات الوصفة',
      'addedToDiary': 'أُضيفت حصة من الوصفة إلى اليوم.',
      'nutritionRequired': 'يلزم توفر تغذية محسوبة بمصادر قبل التسجيل.',
      'edit': 'تعديل الوصفة',
      'delete': 'حذف الوصفة',
      'deleteTitle': 'حذف هذه الوصفة؟',
      'deleteBody': 'سيؤدي هذا إلى إزالة الوصفة المحفوظة من هذا الجهاز.',
      'cancel': 'إلغاء',
      'deleted': 'تم حذف الوصفة.',
      'breakfast': 'الإفطار',
      'lunch': 'الغداء',
      'dinner': 'العشاء',
      'snack': 'وجبة خفيفة',
    },
    'fr': {
      'loadFailed': 'Impossible de charger les recettes enregistrées.',
      'servings': 'portions',
      'addToDiary': 'Ajouter une portion au journal',
      'recipeActions': 'Actions de la recette',
      'addedToDiary': 'Une portion a été ajoutée à aujourd’hui.',
      'nutritionRequired':
          'Une nutrition calculée avec ses sources est requise.',
      'edit': 'Modifier la recette',
      'delete': 'Supprimer la recette',
      'deleteTitle': 'Supprimer cette recette ?',
      'deleteBody': 'La recette enregistrée sera supprimée de cet appareil.',
      'cancel': 'Annuler',
      'deleted': 'Recette supprimée.',
      'breakfast': 'Petit-déjeuner',
      'lunch': 'Déjeuner',
      'dinner': 'Dîner',
      'snack': 'Collation',
    },
    'es': {
      'loadFailed': 'No se pudieron cargar las recetas guardadas.',
      'servings': 'porciones',
      'addToDiary': 'Añadir una porción al diario',
      'recipeActions': 'Acciones de la receta',
      'addedToDiary': 'Se añadió una porción a hoy.',
      'nutritionRequired': 'Se requiere nutrición calculada con sus fuentes.',
      'edit': 'Editar receta',
      'delete': 'Eliminar receta',
      'deleteTitle': '¿Eliminar esta receta?',
      'deleteBody': 'La receta guardada se eliminará de este dispositivo.',
      'cancel': 'Cancelar',
      'deleted': 'Receta eliminada.',
      'breakfast': 'Desayuno',
      'lunch': 'Almuerzo',
      'dinner': 'Cena',
      'snack': 'Tentempié',
    },
    'tr': {
      'loadFailed': 'Kayıtlı tarifler yüklenemedi.',
      'servings': 'porsiyon',
      'addToDiary': 'Günlüğe bir porsiyon ekle',
      'recipeActions': 'Tarif işlemleri',
      'addedToDiary': 'Bugüne bir porsiyon eklendi.',
      'nutritionRequired':
          'Kaydetmeden önce kaynaklı hesaplanmış beslenme gerekir.',
      'edit': 'Tarifi düzenle',
      'delete': 'Tarifi sil',
      'deleteTitle': 'Bu tarif silinsin mi?',
      'deleteBody': 'Kayıtlı tarif bu cihazdan kaldırılır.',
      'cancel': 'İptal',
      'deleted': 'Tarif silindi.',
      'breakfast': 'Kahvaltı',
      'lunch': 'Öğle yemeği',
      'dinner': 'Akşam yemeği',
      'snack': 'Atıştırmalık',
    },
  };
  final language = Localizations.localeOf(context).languageCode;
  final english = copy['en']![key]!;
  return copy[language]?[key] ??
      RuntimeCopy.resolve(
        english,
        BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
      ) ??
      english;
}
