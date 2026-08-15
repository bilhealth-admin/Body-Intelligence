import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../profile/providers/user_profile_provider.dart';
import '../../recipe_import/domain/trusted_recipe.dart';
import '../../recipe_import/presentation/trusted_recipe_import_page.dart';
import '../repositories/recipe_favorites_repository.dart';
import '../repositories/recipe_release_repository.dart';
import 'wellness_copy.dart';

class RecipeLibraryPage extends ConsumerStatefulWidget {
  const RecipeLibraryPage({super.key, this.initialCatalog, this.repository});

  final List<RecipeCatalogSummary>? initialCatalog;
  final RecipeReleaseRepository? repository;

  @override
  ConsumerState<RecipeLibraryPage> createState() => _RecipeLibraryPageState();
}

class _RecipeLibraryPageState extends ConsumerState<RecipeLibraryPage> {
  late final RecipeReleaseRepository _repository;
  final _search = TextEditingController();
  late Future<List<RecipeCatalogSummary>> _catalog;
  Set<String> _favorites = const {};
  final Set<String> _favoriteBusy = <String>{};
  bool _favoritesLoading = true;
  Object? _favoritesError;
  String _category = 'all';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? RecipeReleaseRepository();
    _catalog = widget.initialCatalog == null
        ? _repository.loadIndex()
        : Future.value(widget.initialCatalog);
    _loadFavorites();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    if (mounted) {
      setState(() {
        _favoritesLoading = true;
        _favoritesError = null;
      });
    }
    try {
      final values = await RecipeFavoritesRepository(
        ref.read(preferencesRepositoryProvider),
      ).load();
      if (mounted) setState(() => _favorites = values);
    } catch (error) {
      if (mounted) setState(() => _favoritesError = error);
    } finally {
      if (mounted) setState(() => _favoritesLoading = false);
    }
  }

  Future<void> _toggleFavorite(String id) async {
    if (_favoritesLoading ||
        _favoritesError != null ||
        _favoriteBusy.contains(id)) {
      return;
    }
    setState(() => _favoriteBusy.add(id));
    try {
      final values = await RecipeFavoritesRepository(
        ref.read(preferencesRepositoryProvider),
      ).toggle(id);
      if (mounted) setState(() => _favorites = values);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wellnessCopy(
              context,
              'Saved recipes could not be updated. Try again.',
              'تعذر تحديث الوصفات المحفوظة. حاول مرة أخرى.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _favoriteBusy.remove(id));
    }
  }

  void _retry() => setState(() => _catalog = _repository.loadIndex());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(wellnessCopy(context, 'BIL recipes', 'وصفات BIL')),
        actions: [
          IconButton(
            tooltip: wellnessCopy(context, 'Saved recipes', 'الوصفات المحفوظة'),
            onPressed: () => setState(() => _category = 'saved'),
            icon: const Icon(Icons.bookmark_outline_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<RecipeCatalogSummary>>(
        future: _catalog,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _CatalogUnavailable(onRetry: _retry);
          }
          return _buildCatalog(snapshot.requireData);
        },
      ),
    );
  }

  Widget _buildCatalog(List<RecipeCatalogSummary> source) {
    if (_favoritesLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_favoritesError != null) {
      return _CatalogUnavailable(onRetry: _loadFavorites);
    }
    final query = _search.text.trim().toLowerCase();
    final locale = Localizations.localeOf(context).languageCode;
    final visible =
        source.where((recipe) {
          final categoryMatches = switch (_category) {
            'all' => true,
            'saved' => _favorites.contains(recipe.id),
            _ => recipe.category == _category,
          };
          if (!categoryMatches) return false;
          if (query.isEmpty) return true;
          return recipe.localizedTitles.values.any(
                (title) => title.toLowerCase().contains(query),
              ) ||
              recipe.id.contains(query) ||
              recipe.mealTypes.any(
                (value) => value.toLowerCase().contains(query),
              ) ||
              recipe.dietTags.any(
                (value) => value.toLowerCase().contains(query),
              );
        }).toList()..sort((a, b) {
          final aFallback = a.resolveTitle(locale).isFallback ? 1 : 0;
          final bFallback = b.resolveTitle(locale).isFallback ? 1 : 0;
          final byAvailability = aFallback.compareTo(bFallback);
          return byAvailability != 0 ? byAvailability : a.id.compareTo(b.id);
        });
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: wellnessCopy(
                      context,
                      'Search recipes or tags',
                      'ابحث عن وصفة أو وسم',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _chip('all', wellnessCopy(context, 'All', 'الكل')),
                      _chip(
                        'regional',
                        wellnessCopy(context, 'Regional', 'إقليمية'),
                      ),
                      _chip('quick', wellnessCopy(context, 'Quick', 'سريعة')),
                      _chip(
                        'plant',
                        wellnessCopy(context, 'Plant-forward', 'نباتية'),
                      ),
                      _chip('saved', wellnessCopy(context, 'Saved', 'محفوظة')),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  wellnessCopy(
                    context,
                    '${visible.length} of ${source.length} recipes',
                    '${visible.length} من ${source.length} وصفة',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        if (visible.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                wellnessCopy(
                  context,
                  'No matching recipes.',
                  'لا توجد وصفات مطابقة.',
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: .78,
              ),
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final recipe = visible[index];
                final resolvedTitle = recipe.resolveTitle(locale);
                return _RecipeCard(
                  recipe: recipe,
                  title: resolvedTitle.text,
                  titleLocale: resolvedTitle.locale,
                  isFallback: resolvedTitle.isFallback,
                  favorite: _favorites.contains(recipe.id),
                  onFavorite: _favoriteBusy.contains(recipe.id)
                      ? null
                      : () => _toggleFavorite(recipe.id),
                  onOpen: () => _open(recipe),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _chip(String value, String label) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _category == value,
      onSelected: (_) => setState(() => _category = value),
    ),
  );

  Future<void> _open(RecipeCatalogSummary summary) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => FutureBuilder<RecipeCatalogDetail>(
        future: _repository.loadDetail(summary),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 320,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return SizedBox(
              height: 320,
              child: Center(
                child: Text(
                  wellnessCopy(
                    context,
                    'Recipe details are unavailable.',
                    'تفاصيل الوصفة غير متاحة.',
                  ),
                ),
              ),
            );
          }
          return _RecipeDetails(detail: snapshot.requireData);
        },
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.recipe,
    required this.title,
    required this.titleLocale,
    required this.isFallback,
    required this.favorite,
    required this.onFavorite,
    required this.onOpen,
  });

  final RecipeCatalogSummary recipe;
  final String title;
  final String titleLocale;
  final bool isFallback;
  final bool favorite;
  final VoidCallback? onFavorite;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _RecipePlaceholder(seed: recipe.id),
                  PositionedDirectional(
                    top: 4,
                    end: 4,
                    child: IconButton.filledTonal(
                      tooltip: wellnessCopy(
                        context,
                        favorite ? 'Remove saved recipe' : 'Save recipe',
                        favorite ? 'إزالة الوصفة المحفوظة' : 'حفظ الوصفة',
                      ),
                      onPressed: onFavorite,
                      icon: Icon(
                        favorite
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_outline_rounded,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
              child: Text(
                title,
                locale: Locale(titleLocale),
                textDirection: _directionForLocale(titleLocale),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontFamily:
                      _directionForLocale(titleLocale) == TextDirection.rtl
                      ? 'BILArabic'
                      : null,
                ),
              ),
            ),
            if (isFallback)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 2),
                child: Text(
                  wellnessCopy(
                    context,
                    'Original · ${titleLocale.toUpperCase()}',
                    'الأصلية · ${titleLocale.toUpperCase()}',
                  ),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Text(
                wellnessCopy(
                  context,
                  '${recipe.totalMinutes} min',
                  '${recipe.totalMinutes} دقيقة',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeDetails extends StatelessWidget {
  const _RecipeDetails({required this.detail});

  final RecipeCatalogDetail detail;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final resolved = detail.resolveLocalization(locale);
    final localization = resolved.value;
    final record = detail.record;
    final ingredients = (localization['ingredients'] as List).cast<String>();
    final steps = (localization['steps'] as List).cast<String>();
    final contentLanguageMismatch = [...ingredients, ...steps].any(
      (value) =>
          _directionForText(value) != _directionForLocale(resolved.locale),
    );
    final nutrition = record['nutrition'] as Map<String, dynamic>;
    final ingredientsEvidenceComplete = (record['ingredients'] as List).every((
      value,
    ) {
      final ingredient = value as Map<String, dynamic>;
      final recordId = ingredient['recordId'];
      final refs = ingredient['sourceRefs'];
      return recordId is String && refs is List && refs.contains(recordId);
    });
    final perServing = nutrition['perServing'] as Map<String, dynamic>;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .9,
      minChildSize: .6,
      maxChildSize: .96,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _RecipePlaceholder(seed: detail.summary.id),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            localization['title'] as String,
            locale: Locale(resolved.locale),
            textDirection: _directionForLocale(resolved.locale),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (resolved.isFallback || contentLanguageMismatch) ...[
            const SizedBox(height: 6),
            Text(
              wellnessCopy(
                context,
                contentLanguageMismatch
                    ? 'Some recipe details remain in their source language; each line is displayed in its correct reading direction.'
                    : 'Shown in the original language (${resolved.locale.toUpperCase()}); this recipe is not translated into your app language.',
                contentLanguageMismatch
                    ? 'بعض تفاصيل الوصفة ما زالت بلغتها المصدرية؛ يُعرض كل سطر باتجاه القراءة الصحيح.'
                    : 'تُعرض باللغة الأصلية (${resolved.locale.toUpperCase()})؛ هذه الوصفة غير مترجمة إلى لغة التطبيق.',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            wellnessCopy(context, 'Ingredients', 'المكوّنات'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          for (final ingredient in ingredients)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Directionality(
                textDirection: _directionForText(ingredient),
                child: Text(
                  '• $ingredient',
                  locale: Locale(_localeForText(ingredient, resolved.locale)),
                ),
              ),
            ),
          const SizedBox(height: 18),
          Text(
            wellnessCopy(context, 'Method', 'الطريقة'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          for (var index = 0; index < steps.length; index++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Directionality(
                textDirection: _directionForText(steps[index]),
                child: Text(
                  '${index + 1}. ${steps[index]}',
                  locale: Locale(_localeForText(steps[index], resolved.locale)),
                ),
              ),
            ),
          const SizedBox(height: 18),
          Text(
            wellnessCopy(
              context,
              ingredientsEvidenceComplete
                  ? 'Calculated values with complete ingredient record links'
                  : 'Calculated values; some ingredient record links need review',
              ingredientsEvidenceComplete
                  ? 'قيم محسوبة مع اكتمال روابط سجلات المكوّنات'
                  : 'قيم محسوبة؛ بعض روابط سجلات المكوّنات تحتاج مراجعة',
            ),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(_nutritionLine(perServing), textAlign: TextAlign.start),
          ),
          const SizedBox(height: 6),
          Text(
            wellnessCopy(
              context,
              'Review ingredients and serving size before logging. User confirmation is not professional nutrition verification.',
              'راجع المكوّنات وحجم الحصة قبل التسجيل. تأكيد المستخدم ليس تحققًا غذائيًا مهنيًا.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              final timing = record['timing'] as Map<String, dynamic>;
              final serving = record['serving'] as Map<String, dynamic>;
              final canonicalIngredients = (record['ingredients'] as List)
                  .cast<Map<String, dynamic>>();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TrustedRecipeImportPage(
                    initialDraft: TrustedRecipeDraft(
                      name: localization['title'] as String,
                      servings: serving['count'] as int,
                      prepMinutes: timing['prepMinutes'] as int,
                      cookMinutes: timing['cookMinutes'] as int,
                      ingredients: [
                        for (
                          var index = 0;
                          index < canonicalIngredients.length;
                          index++
                        )
                          TrustedRecipeIngredient(
                            name:
                                canonicalIngredients[index]['itemId'] as String,
                            quantity:
                                (canonicalIngredients[index]['quantity'] as num)
                                    .toDouble(),
                            unit: canonicalIngredients[index]['unit'] as String,
                            sourceRecordId:
                                canonicalIngredients[index]['recordId']
                                    as String?,
                          ),
                      ],
                      steps: steps,
                      sourceUrl: null,
                    ),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.fact_check_outlined),
            label: Text(
              wellnessCopy(
                context,
                'Review and save recipe',
                'راجع الوصفة واحفظها',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipePlaceholder extends StatelessWidget {
  const _RecipePlaceholder({required this.seed});

  final String seed;

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xffdcefe4),
      const Color(0xffffe5cc),
      const Color(0xffdce9fa),
      const Color(0xfff4dfeb),
    ];
    final color =
        colors[seed.codeUnits.fold<int>(0, (a, b) => a + b) % colors.length];
    return ColoredBox(
      color: color,
      child: Center(
        child: Icon(
          Icons.restaurant_rounded,
          size: 44,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

TextDirection _directionForLocale(String locale) {
  final language = locale.split(RegExp('[-_]')).first.toLowerCase();
  return const {'ar', 'fa', 'ur'}.contains(language)
      ? TextDirection.rtl
      : TextDirection.ltr;
}

TextDirection _directionForText(String value) =>
    RegExp(r'[\u0600-\u06ff]').hasMatch(value)
    ? TextDirection.rtl
    : TextDirection.ltr;

String _localeForText(String value, String declaredLocale) {
  final declaredDirection = _directionForLocale(declaredLocale);
  return _directionForText(value) == declaredDirection ? declaredLocale : 'en';
}

String _nutritionLine(Map<String, Object?> nutrients) {
  String value(String key, {String? fallbackKey}) {
    final raw =
        nutrients[key] ?? (fallbackKey == null ? null : nutrients[fallbackKey]);
    if (raw is! num || !raw.isFinite) return '—';
    return raw == raw.roundToDouble()
        ? raw.toInt().toString()
        : raw.toStringAsFixed(1);
  }

  return '${value('kcal')} kcal · '
      '${value('proteinG')} g protein · '
      '${value('carbsG', fallbackKey: 'carbohydrateG')} g carbs · '
      '${value('fatG')} g fat';
}

class _CatalogUnavailable extends StatelessWidget {
  const _CatalogUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 42),
            const SizedBox(height: 12),
            Text(
              wellnessCopy(
                context,
                'The recipe catalog is unavailable.',
                'دليل الوصفات غير متاح.',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(wellnessCopy(context, 'Retry', 'إعادة المحاولة')),
            ),
          ],
        ),
      ),
    );
  }
}
