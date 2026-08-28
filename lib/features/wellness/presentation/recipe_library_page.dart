import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../commerce/domain/commerce_plan.dart';
import '../../commerce/presentation/premium_collection_item_gate.dart';
import '../../commerce/providers/commerce_providers.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../nutrition/domain/dietary_preferences.dart';
import '../../recipe_import/domain/trusted_recipe.dart';
import '../../recipe_import/presentation/trusted_recipe_import_page.dart';
import '../repositories/recipe_favorites_repository.dart';
import '../repositories/recipe_release_repository.dart';
import '../services/recipe_image_delivery_client.dart';
import '../services/wellness_media_cache.dart';
import 'recipe_artwork_registry.dart';
import 'recipe_cuisine.dart';
import 'wellness_copy.dart';

part 'recipe_library_helpers.dart';
part 'recipe_library_card.dart';

class RecipeLibraryPage extends ConsumerStatefulWidget {
  const RecipeLibraryPage({
    super.key,
    this.initialCatalog,
    this.initialCardFacts = const {},
    this.repository,
    this.imageClient,
    this.remoteImageDeliveryEnabled = const bool.fromEnvironment(
      'BIL_RECIPE_IMAGE_DELIVERY_ENABLED',
      // The digest-pinned Cloudflare route passed staging and production
      // smoke tests on 2026-08-24. Keep an explicit build-time kill switch,
      // while shipping the verified delivery path in normal release builds.
      defaultValue: true,
    ),
    this.initialRecipeId,
  });

  final List<RecipeCatalogSummary>? initialCatalog;
  final Map<String, RecipeCatalogCardFacts> initialCardFacts;
  final RecipeReleaseRepository? repository;
  final RecipeImageResolver? imageClient;
  final bool remoteImageDeliveryEnabled;
  final String? initialRecipeId;

  @override
  ConsumerState<RecipeLibraryPage> createState() => _RecipeLibraryPageState();
}

class _RecipeLibraryPageState extends ConsumerState<RecipeLibraryPage> {
  static const _sectionPreviewCount = 4;
  static const _filteredPageSize = 24;

  late final RecipeReleaseRepository _repository;
  RecipeImageResolver? _imageClient;
  RecipeImageDeliveryClient? _ownedImageClient;
  final _search = TextEditingController();
  late Future<List<RecipeCatalogSummary>> _catalog;
  Set<String> _favorites = const {};
  final Set<String> _favoriteBusy = <String>{};
  bool _favoritesLoading = true;
  Object? _favoritesError;
  String _category = 'all';
  String _cuisine = 'all';
  int _visibleLimit = _filteredPageSize;
  final Map<String, Future<RecipeCatalogCardFacts>> _cardFacts = {};
  final Map<String, Future<WellnessMediaCacheResult>> _recipeImages = {};
  bool _initialRecipeHandled = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? RecipeReleaseRepository();
    if (widget.remoteImageDeliveryEnabled) {
      _imageClient = widget.imageClient;
      if (_imageClient == null) {
        _ownedImageClient = RecipeImageDeliveryClient(repository: _repository);
        _imageClient = _ownedImageClient;
      }
    }
    _catalog = widget.initialCatalog == null
        ? _repository.loadIndex()
        : Future.value(widget.initialCatalog);
    _loadFavorites();
  }

  @override
  void dispose() {
    _search.dispose();
    _ownedImageClient?.dispose();
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
        centerTitle: false,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(wellnessCopy(context, 'BIL recipes', 'وصفات BIL')),
        actions: [
          IconButton(
            tooltip: wellnessCopy(context, 'Saved recipes', 'الوصفات المحفوظة'),
            onPressed: () => setState(() {
              _search.clear();
              _category = 'saved';
              _cuisine = 'all';
              _visibleLimit = _filteredPageSize;
            }),
            icon: Icon(
              _category == 'saved'
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_outline_rounded,
            ),
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
          _scheduleInitialRecipe(snapshot.requireData);
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
    final dietaryPreferences =
        ref.watch(dietaryPreferencesProvider).value ??
        const DietaryPreferences();
    final compatibleSource = source
        .where((recipe) => recipe.isCompatibleWith(dietaryPreferences))
        .toList(growable: false);
    final locale = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    final subscription = ref.watch(verifiedSubscriptionStateProvider).value;
    final premiumUnlocked =
        subscription != null && subscription.plan != CommercePlan.free;
    final storefrontPlan = ref.watch(storefrontTargetPlanProvider).value;
    final premiumTier = storefrontPlan == CommercePlan.premiumAiCoach
        ? 'BIL PREMIUM AI COACH'
        : 'BIL PREMIUM';
    void openPremium() => context.push(
      storefrontPlan == CommercePlan.premiumAiCoach
          ? '/plans?focus=boost'
          : '/plans?focus=subscription',
    );
    final availableCuisines = recipeCuisineOrder
        .where(
          (key) =>
              compatibleSource.any((recipe) => recipeCuisineKey(recipe) == key),
        )
        .toList(growable: false);
    final visible =
        compatibleSource.where((recipe) {
          if (_cuisine != 'all' && recipeCuisineKey(recipe) != _cuisine) {
            return false;
          }
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
    final groupedHome =
        query.isEmpty && _category == 'all' && _cuisine == 'all';
    final sections = groupedHome
        ? [
                for (final key in availableCuisines)
                  (
                    key: key,
                    recipes: visible
                        .where((recipe) => recipeCuisineKey(recipe) == key)
                        .take(_sectionPreviewCount)
                        .toList(growable: false),
                  ),
              ]
              .where((section) => section.recipes.isNotEmpty)
              .toList(growable: false)
        : const <({String key, List<RecipeCatalogSummary> recipes})>[];
    final homeDisplayOrder = [
      for (final section in sections) ...section.recipes,
    ];
    final homeDisplayIndex = {
      for (var index = 0; index < homeDisplayOrder.length; index++)
        homeDisplayOrder[index].id: index,
    };
    final pagedVisible = visible.take(_visibleLimit).toList(growable: false);

    Widget recipeCard(RecipeCatalogSummary recipe, int displayIndex) {
      final resolvedTitle = recipe.resolveTitle(locale);
      final initialFacts = widget.initialCardFacts[recipe.id];
      final facts =
          initialFacts == null &&
              (widget.initialCatalog == null || widget.repository != null)
          ? _cardFacts.putIfAbsent(
              recipe.id,
              () => _repository.loadCardFacts(recipe.id),
            )
          : null;
      final imageResult = _imageResultFor(recipe);
      // The first two cards remain a real, playable sample. Every following
      // recipe stays visible behind verified-plan glass.
      final locked = !premiumUnlocked && displayIndex >= 2;
      return PremiumCollectionItemGate(
        key: ValueKey('recipe-premium-gate-${recipe.id}'),
        locked: locked,
        tier: premiumTier,
        onUpgrade: openPremium,
        child: _RecipeCard(
          recipe: recipe,
          title: resolvedTitle.text,
          titleLocale: resolvedTitle.locale,
          isFallback: resolvedTitle.isFallback,
          initialFacts: initialFacts,
          facts: facts,
          imageResult: imageResult,
          favorite: _favorites.contains(recipe.id),
          onFavorite: _favoriteBusy.contains(recipe.id)
              ? null
              : () => _toggleFavorite(recipe.id),
          onOpen: () => _open(recipe),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          sliver: SliverToBoxAdapter(
            child: _RecipeDiscoveryHeader(
              searchController: _search,
              category: _category,
              cuisine: _cuisine,
              visibleCount: visible.length,
              totalCount: compatibleSource.length,
              onSearchChanged: (_) =>
                  setState(() => _visibleLimit = _filteredPageSize),
              onClearSearch: () => setState(() {
                _search.clear();
                _visibleLimit = _filteredPageSize;
              }),
              onChooseCuisine: () => _chooseCuisine(availableCuisines),
              onCategorySelected: (value) => setState(() {
                _category = value;
                _visibleLimit = _filteredPageSize;
              }),
            ),
          ),
        ),
        if (visible.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _RecipeEmptyState(
              onReset: () => setState(() {
                _search.clear();
                _category = 'all';
                _cuisine = 'all';
                _visibleLimit = _filteredPageSize;
              }),
            ),
          )
        else if (groupedHome)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList.builder(
              key: const Key('recipe-cuisine-sections'),
              itemCount: sections.length,
              itemBuilder: (context, sectionIndex) {
                final section = sections[sectionIndex];
                return Padding(
                  key: ValueKey('recipe-cuisine-section-${section.key}'),
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              recipeCuisineLabel(context, section.key),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            key: ValueKey(
                              'recipe-cuisine-section-open-${section.key}',
                            ),
                            tooltip: recipeCuisineLabel(context, section.key),
                            onPressed: () => setState(() {
                              _cuisine = section.key;
                              _visibleLimit = _filteredPageSize;
                            }),
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: _recipeCardExtent(context),
                        child: ListView.separated(
                          key: ValueKey(
                            'recipe-cuisine-section-list-${section.key}',
                          ),
                          scrollDirection: Axis.horizontal,
                          itemCount: section.recipes.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final recipe = section.recipes[index];
                            return SizedBox(
                              width: _recipePreviewWidth(context),
                              child: recipeCard(
                                recipe,
                                homeDisplayIndex[recipe.id]!,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                return SliverGrid.builder(
                  key: const Key('recipe-results-grid'),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _recipeColumnCount(
                      constraints.crossAxisExtent,
                    ),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: _recipeCardExtent(context),
                  ),
                  itemCount: pagedVisible.length,
                  itemBuilder: (context, index) {
                    final recipe = pagedVisible[index];
                    return recipeCard(recipe, index);
                  },
                );
              },
            ),
          ),
          if (pagedVisible.length < visible.length)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              sliver: SliverToBoxAdapter(
                child: OutlinedButton.icon(
                  key: const Key('recipe-show-more'),
                  onPressed: () =>
                      setState(() => _visibleLimit += _filteredPageSize),
                  icon: const Icon(Icons.expand_more_rounded),
                  label: Text(wellnessCopy(context, 'More', 'المزيد')),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _chooseCuisine(List<String> cuisines) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .72,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    wellnessCopy(sheetContext, 'Choose cuisine', 'اختر المطبخ'),
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final key in ['all', ...cuisines])
                      ListTile(
                        selected: key == _cuisine,
                        title: Text(recipeCuisineLabel(sheetContext, key)),
                        trailing: key == _cuisine
                            ? const Icon(Icons.check_circle_rounded)
                            : null,
                        onTap: () => Navigator.pop(sheetContext, key),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && selected != _cuisine && mounted) {
      setState(() {
        _cuisine = selected;
        _visibleLimit = _filteredPageSize;
      });
    }
  }

  Future<WellnessMediaCacheResult>? _imageResultFor(
    RecipeCatalogSummary recipe,
  ) {
    if (!widget.remoteImageDeliveryEnabled ||
        bundledRecipeImageAssets.containsKey(recipe.id)) {
      return null;
    }
    return _recipeImages.putIfAbsent(
      recipe.id,
      () => _imageClient!.resolve(recipe.id, online: true),
    );
  }

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
          return _RecipeDetails(
            detail: snapshot.requireData,
            imageResult: _imageResultFor(summary),
          );
        },
      ),
    );
  }

  void _scheduleInitialRecipe(List<RecipeCatalogSummary> recipes) {
    if (_initialRecipeHandled) return;
    final requested = widget.initialRecipeId?.trim();
    if (requested == null || requested.isEmpty) {
      _initialRecipeHandled = true;
      return;
    }
    final matches = recipes.where((recipe) => recipe.id == requested);
    if (matches.isEmpty) {
      _initialRecipeHandled = true;
      return;
    }
    _initialRecipeHandled = true;
    final recipe = matches.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final subscription = ref.read(verifiedSubscriptionStateProvider).value;
      if (subscription == null || subscription.plan == CommercePlan.free) {
        final storefrontPlan = ref.read(storefrontTargetPlanProvider).value;
        context.push(
          storefrontPlan == CommercePlan.premiumAiCoach
              ? '/plans?focus=boost'
              : '/plans?focus=subscription',
        );
        return;
      }
      _open(recipe);
    });
  }
}

class _RecipeDetails extends StatelessWidget {
  const _RecipeDetails({required this.detail, required this.imageResult});

  final RecipeCatalogDetail detail;
  final Future<WellnessMediaCacheResult>? imageResult;

  @override
  Widget build(BuildContext context) {
    final locale = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    final resolved = detail.resolveLocalization(locale);
    final displayTitle = detail.summary.resolveTitle(locale);
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
    final cardFacts = RecipeCatalogCardFacts.fromDetail(detail);
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
              child: _RecipeArtwork(
                recipe: detail.summary,
                title: displayTitle.text,
                imageResult: imageResult,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            displayTitle.text,
            locale: BilLocalePolicy.localeFromTag(displayTitle.locale),
            textDirection: _directionForLocale(displayTitle.locale),
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
          _RecipeDetailFacts(
            minutes: detail.summary.totalMinutes,
            facts: cardFacts,
          ),
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
                  locale: BilLocalePolicy.localeFromTag(
                    _localeForText(ingredient, resolved.locale),
                  ),
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
                  locale: BilLocalePolicy.localeFromTag(
                    _localeForText(steps[index], resolved.locale),
                  ),
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
