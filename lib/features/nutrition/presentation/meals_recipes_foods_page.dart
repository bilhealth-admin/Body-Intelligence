import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy.dart';
import '../../../data/repositories/meal_repository.dart';
import '../../../data/repositories/preferences_repository.dart';
import '../../../data/database/database_provider.dart';
import '../../../shared/widgets/secondary_page_app_bar.dart';
import '../../daily_log/providers/daily_log_provider.dart';
import '../../foods/providers/food_provider.dart';
import '../../recipe_import/providers/trusted_recipe_providers.dart';
import '../../recipe_import/domain/trusted_recipe.dart';
import '../../recipe_import/services/trusted_recipe_diary_service.dart';
import '../food_page.dart';

class MealsRecipesFoodsPage extends ConsumerStatefulWidget {
  const MealsRecipesFoodsPage({super.key});

  @override
  ConsumerState<MealsRecipesFoodsPage> createState() =>
      _MealsRecipesFoodsPageState();
}

class _MealsRecipesFoodsPageState extends ConsumerState<MealsRecipesFoodsPage> {
  Future<String?>? preference;

  @override
  void initState() {
    super.initState();
    preference = PreferencesRepository(
      ref.read(databaseProvider),
    ).get('diary.defaultSearchTab');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: preference,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: FilledButton.icon(
                onPressed: () => setState(
                  () => preference = PreferencesRepository(
                    ref.read(databaseProvider),
                  ).get('diary.defaultSearchTab'),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(_c(context, 'Retry')),
              ),
            ),
          );
        }
        final initialIndex = switch (snapshot.data) {
          'meals' => 0,
          'recipes' => 1,
          'my_foods' || _ => 2,
        };
        return DefaultTabController(
          length: 3,
          initialIndex: initialIndex,
          child: Scaffold(
            appBar: SecondaryPageAppBar(
              title: Text(_c(context, 'My nutrition')),
            ),
            body: Column(
              children: [
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerHeight: 1,
                  tabs: [
                    Tab(text: _c(context, 'My meals')),
                    Tab(text: _c(context, 'My recipes')),
                    Tab(text: _c(context, 'My foods')),
                  ],
                ),
                const Expanded(
                  child: TabBarView(
                    children: [
                      _MealsTab(),
                      _RecipesTab(),
                      FoodPage(embedded: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

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

class _RecipeChoiceTile extends StatelessWidget {
  const _RecipeChoiceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      leading: Icon(icon, size: 30),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(subtitle),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}

String _recipeChoiceCopy(BuildContext context, String key) {
  final language = Localizations.localeOf(context).languageCode;
  const copy = <String, Map<String, String>>{
    'en': {
      'title': 'Add a recipe',
      'webTitle': 'Import from the web',
      'webBody':
          'Paste a recipe link, then review every ingredient before saving.',
      'manualTitle': 'Enter ingredients manually',
      'manualBody': 'Build the recipe from reviewed foods and serving amounts.',
    },
    'ar': {
      'title': 'إضافة وصفة',
      'webTitle': 'الاستيراد من الويب',
      'webBody': 'الصق رابط الوصفة ثم راجع كل مكوّن قبل الحفظ.',
      'manualTitle': 'إدخال المكونات يدويًا',
      'manualBody': 'أنشئ الوصفة من أطعمة وكميات حصص تمت مراجعتها.',
    },
    'fr': {
      'title': 'Ajouter une recette',
      'webTitle': 'Importer depuis le Web',
      'webBody':
          'Collez un lien, puis vérifiez chaque ingrédient avant de sauvegarder.',
      'manualTitle': 'Saisir les ingrédients',
      'manualBody': 'Créez la recette avec des aliments et portions vérifiés.',
    },
    'es': {
      'title': 'Añadir una receta',
      'webTitle': 'Importar desde la web',
      'webBody': 'Pega un enlace y revisa cada ingrediente antes de guardar.',
      'manualTitle': 'Introducir ingredientes',
      'manualBody': 'Crea la receta con alimentos y porciones revisados.',
    },
    'tr': {
      'title': 'Tarif ekle',
      'webTitle': 'Web’den içe aktar',
      'webBody':
          'Bağlantıyı yapıştırın ve kaydetmeden önce malzemeleri inceleyin.',
      'manualTitle': 'Malzemeleri elle gir',
      'manualBody': 'Tarifi incelenmiş yiyecekler ve porsiyonlarla oluşturun.',
    },
  };
  final english = copy['en']![key]!;
  return copy[language]?[key] ??
      RuntimeCopy.resolve(
        english,
        BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
      ) ??
      english;
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title, body;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 20),
    child: Column(
      children: [
        Icon(icon, size: 80, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(body, textAlign: TextAlign.center),
      ],
    ),
  );
}

String _c(BuildContext context, String key) {
  final english = _copy['en']?[key] ?? key;
  return _copy[Localizations.localeOf(context).languageCode]?[key] ??
      RuntimeCopy.resolve(
        english,
        BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
      ) ??
      english;
}

const _copy = <String, Map<String, String>>{
  'en': {
    'My nutrition': 'My nutrition',
    'My meals': 'My meals',
    'My recipes': 'My recipes',
    'My foods': 'My foods',
    'Create meal': 'Create meal',
    'Copy previous meal': 'Copy previous meal',
    'Saved meals could not be loaded.': 'Saved meals could not be loaded.',
    'Log your go-to meals faster': 'Log your go-to meals faster',
    'Meals repeated in your diary appear here for quick reuse.':
        'Meals repeated in your diary appear here for quick reuse.',
    'items': 'items',
    'Copy to today': 'Copy to today',
    'Meal copied to today.': 'Meal copied to today.',
    'This meal is already present today.':
        'This meal is already present today.',
    'Create recipe': 'Create recipe',
    'Discover': 'Discover',
    'Import': 'Import',
    'Build your recipe collection': 'Build your recipe collection',
    'Discover local recipes and save favorites. Calculated nutrition is labeled and never invented.':
        'Discover local recipes and save favorites. Calculated nutrition is labeled and never invented.',
    'Import recipe': 'Import recipe',
    'Recipe files require review before foods or nutrition values are added. Use Create recipe to review ingredients locally.':
        'Recipe files require review before foods or nutrition values are added. Use Create recipe to review ingredients locally.',
    'Close': 'Close',
  },
  'ar': {
    'My nutrition': 'تغذيتي',
    'My meals': 'وجباتي',
    'My recipes': 'وصفاتي',
    'My foods': 'أطعمتي',
    'Create meal': 'إنشاء وجبة',
    'Copy previous meal': 'نسخ وجبة سابقة',
    'Saved meals could not be loaded.': 'تعذر تحميل الوجبات المحفوظة.',
    'Log your go-to meals faster': 'سجّل وجباتك المعتادة أسرع',
    'Meals repeated in your diary appear here for quick reuse.':
        'تظهر هنا الوجبات المتكررة في يومياتك لإعادة استخدامها بسرعة.',
    'items': 'عناصر',
    'Copy to today': 'نسخ إلى اليوم',
    'Meal copied to today.': 'نُسخت الوجبة إلى اليوم.',
    'This meal is already present today.': 'هذه الوجبة موجودة اليوم بالفعل.',
    'Create recipe': 'إنشاء وصفة',
    'Discover': 'اكتشف',
    'Import': 'استيراد',
    'Build your recipe collection': 'أنشئ مجموعة وصفاتك',
    'Discover local recipes and save favorites. Calculated nutrition is labeled and never invented.':
        'اكتشف وصفات محلية واحفظ مفضلاتك. تُوسم التغذية المحسوبة بوضوح ولا تُختلق القيم.',
    'Import recipe': 'استيراد وصفة',
    'Recipe files require review before foods or nutrition values are added. Use Create recipe to review ingredients locally.':
        'تتطلب ملفات الوصفات مراجعة قبل إضافة الطعام أو القيم الغذائية. استخدم إنشاء وصفة لمراجعة المكونات محليًا.',
    'Close': 'إغلاق',
  },
  'fr': {
    'My nutrition': 'Ma nutrition',
    'My meals': 'Mes repas',
    'My recipes': 'Mes recettes',
    'My foods': 'Mes aliments',
    'Create meal': 'Créer un repas',
    'Copy previous meal': 'Copier un repas précédent',
    'Saved meals could not be loaded.':
        'Impossible de charger les repas enregistrés.',
    'Log your go-to meals faster': 'Enregistrez plus vite vos repas habituels',
    'Meals repeated in your diary appear here for quick reuse.':
        'Les repas répétés dans votre journal apparaissent ici.',
    'items': 'éléments',
    'Copy to today': "Copier aujourd’hui",
    'Meal copied to today.': "Repas copié aujourd’hui.",
    'This meal is already present today.':
        'Ce repas est déjà présent aujourd’hui.',
    'Create recipe': 'Créer une recette',
    'Discover': 'Découvrir',
    'Import': 'Importer',
    'Build your recipe collection': 'Créez votre collection de recettes',
    'Discover local recipes and save favorites. Calculated nutrition is labeled and never invented.':
        'Découvrez des recettes locales et enregistrez vos favorites. La nutrition calculée est clairement indiquée.',
    'Import recipe': 'Importer une recette',
    'Recipe files require review before foods or nutrition values are added. Use Create recipe to review ingredients locally.':
        'Les fichiers de recette doivent être vérifiés avant tout ajout.',
    'Close': 'Fermer',
  },
  'es': {
    'My nutrition': 'Mi nutrición',
    'My meals': 'Mis comidas',
    'My recipes': 'Mis recetas',
    'My foods': 'Mis alimentos',
    'Create meal': 'Crear comida',
    'Copy previous meal': 'Copiar comida anterior',
    'Saved meals could not be loaded.':
        'No se pudieron cargar las comidas guardadas.',
    'Log your go-to meals faster': 'Registra más rápido tus comidas habituales',
    'Meals repeated in your diary appear here for quick reuse.':
        'Las comidas repetidas aparecen aquí para reutilizarlas.',
    'items': 'elementos',
    'Copy to today': 'Copiar a hoy',
    'Meal copied to today.': 'Comida copiada a hoy.',
    'This meal is already present today.': 'Esta comida ya está presente hoy.',
    'Create recipe': 'Crear receta',
    'Discover': 'Descubrir',
    'Import': 'Importar',
    'Build your recipe collection': 'Crea tu colección de recetas',
    'Discover local recipes and save favorites. Calculated nutrition is labeled and never invented.':
        'Descubre recetas locales y guarda tus favoritas. La nutrición calculada se indica claramente.',
    'Import recipe': 'Importar receta',
    'Recipe files require review before foods or nutrition values are added. Use Create recipe to review ingredients locally.':
        'Los archivos de recetas deben revisarse antes de añadir datos.',
    'Close': 'Cerrar',
  },
  'tr': {
    'My nutrition': 'Beslenmem',
    'My meals': 'Öğünlerim',
    'My recipes': 'Tariflerim',
    'My foods': 'Yiyeceklerim',
    'Create meal': 'Öğün oluştur',
    'Copy previous meal': 'Önceki öğünü kopyala',
    'Saved meals could not be loaded.': 'Kayıtlı öğünler yüklenemedi.',
    'Log your go-to meals faster': 'Sık öğünlerinizi daha hızlı kaydedin',
    'Meals repeated in your diary appear here for quick reuse.':
        'Günlüğünüzde tekrarlanan öğünler burada görünür.',
    'items': 'öğe',
    'Copy to today': 'Bugüne kopyala',
    'Meal copied to today.': 'Öğün bugüne kopyalandı.',
    'This meal is already present today.': 'Bu öğün bugün zaten mevcut.',
    'Create recipe': 'Tarif oluştur',
    'Discover': 'Keşfet',
    'Import': 'İçe aktar',
    'Build your recipe collection': 'Tarif koleksiyonunuzu oluşturun',
    'Discover local recipes and save favorites. Calculated nutrition is labeled and never invented.':
        'Yerel tarifleri keşfedin ve favorilerinizi kaydedin. Hesaplanan beslenme açıkça etiketlenir.',
    'Import recipe': 'Tarif içe aktar',
    'Recipe files require review before foods or nutrition values are added. Use Create recipe to review ingredients locally.':
        'Tarif dosyaları veri eklenmeden önce incelenmelidir.',
    'Close': 'Kapat',
  },
};
