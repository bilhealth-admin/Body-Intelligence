import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../data/database/app_database.dart';
import '../../data/database/nutrient_evidence.dart';
import '../../app/localization/app_localizations.dart';
import '../../app/services/runtime_permission_policy.dart';
import '../../app/theme/bil_flagship_tokens.dart';
import '../foods/providers/food_provider.dart';
import '../community/presentation/product_review_submission_dialog.dart';
import '../commerce/presentation/premium_barcode_access.dart';
import '../commerce/presentation/premium_nutrition_glass.dart';
import 'services/food_runtime_search_authority.dart';
import 'services/food_search_assistance.dart';
import 'domain/unified_food.dart';
import 'presentation/food_barcode_scanner_page.dart';
import 'presentation/product_identity_copy.dart';
import 'presentation/barcode_runtime_copy.dart';
import 'presentation/nutrition_copy.dart';
import 'presentation/meal_image_guide_page.dart';
import '../../shared/widgets/actionable_empty_state.dart';
import '../../shared/widgets/actionable_error_state.dart';

part 'presentation/food_catalog_overview.dart';
part 'presentation/food_catalog_tile.dart';
part 'presentation/food_nutrient_values.dart';
part 'presentation/food_nutrient_locale_copy.dart';
part 'presentation/custom_food_dialog.dart';
part 'presentation/custom_food_locale_copy.dart';
part 'presentation/food_search_locale_copy.dart';
part 'presentation/food_page_actions.dart';

enum _CatalogView { all, favorites, recent }

enum _FoodAddMethod { scanBarcode, manualBarcode, mealPhoto, customFood }

enum _UnverifiedBarcodeAction {
  dismiss,
  createFood,
  submitReview,
  scanProductLabel,
}

enum _RuntimeSearchUiState {
  idle,
  searching,
  catalogAndLocal,
  localOnly,
  localFallback,
}

class FoodPage extends ConsumerStatefulWidget {
  const FoodPage({
    super.key,
    this.embedded = false,
    this.userOwnedOnly = false,
  });

  final bool embedded;
  final bool userOwnedOnly;

  @override
  ConsumerState<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends ConsumerState<FoodPage> {
  final search = TextEditingController();
  List<Food>? results;
  Timer? debounce;
  int searchGeneration = 0;
  _CatalogView catalogView = _CatalogView.all;
  _RuntimeSearchUiState runtimeSearchState = _RuntimeSearchUiState.idle;
  static const FoodSearchAssistance _assistance = FoodSearchAssistance();
  String? correction;

  /// Keeps state mutations owned by the [State] subclass when presentation
  /// actions are split into a part-file extension.
  void _mutateFoodPage(VoidCallback mutation) {
    if (mounted) setState(mutation);
  }

  @override
  void dispose() {
    debounce?.cancel();
    // Let the current detach frame finish before disposing the controller.
    // A wall-clock delay leaked a pending timer into widget tests and kept the
    // controller alive needlessly after the route had settled.
    final retiredSearch = search;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => retiredSearch.dispose(),
    );
    super.dispose();
  }

  Future<void> _runSearch(String value) async {
    final generation = ++searchGeneration;
    final trimmed = value.trim();

    if (mounted) {
      setState(
        () => runtimeSearchState = trimmed.isEmpty
            ? _RuntimeSearchUiState.idle
            : _RuntimeSearchUiState.searching,
      );
    }

    final outcome = widget.userOwnedOnly
        ? FoodRuntimeSearchResult(
            foods: _foodsInScope(
              await ref.read(foodRepositoryProvider).searchCustomFoods(value),
            ),
            source: FoodRuntimeSearchSource.localOnly,
          )
        : await ref
              .read(foodRuntimeSearchAuthorityProvider)
              .searchDetailed(value);

    if (mounted && generation == searchGeneration) {
      setState(() {
        results = _foodsInScope(outcome.foods);
        // Empty-state suggestions must be authored synonyms/translations only.
        // A fuzzy nearest-neighbour can turn a misspelling into a different
        // food, which is unsafe and confusing in a nutrition log.
        correction = results!.isEmpty
            ? _assistance.explicitCorrectionFor(trimmed)
            : null;
        runtimeSearchState = switch (outcome.source) {
          FoodRuntimeSearchSource.catalogAndLocal =>
            _RuntimeSearchUiState.catalogAndLocal,
          FoodRuntimeSearchSource.localOnly =>
            trimmed.isEmpty
                ? _RuntimeSearchUiState.idle
                : _RuntimeSearchUiState.localOnly,
          FoodRuntimeSearchSource.localFallback =>
            _RuntimeSearchUiState.localFallback,
        };
      });
    }
  }

  void _scheduleSearch(String value) {
    debounce?.cancel();
    final trimmed = value.trim();
    // Rebuild immediately. Waiting for the debounce left the browse filters
    // and a false empty state visible underneath an active search.
    setState(() {
      runtimeSearchState = trimmed.isEmpty
          ? _RuntimeSearchUiState.idle
          : _RuntimeSearchUiState.searching;
      results = null;
      correction = null;
    });
    if (trimmed.isEmpty) {
      searchGeneration++;
      return;
    }
    debounce = Timer(
      const Duration(milliseconds: 180),
      () => _runSearch(value),
    );
  }

  List<Food> _foodsInScope(Iterable<Food> foods) => widget.userOwnedOnly
      ? foods.where((food) => food.isCustom).toList(growable: false)
      : foods.toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final t = context.strings.text;
    final allFoods = ref.watch(foodsProvider);
    final favorites = ref.watch(favoriteFoodsProvider);
    final recent = ref.watch(recentFoodsProvider);
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: Text(nutritionText(context, 'Food', 'الغذاء'))),
      floatingActionButton: widget.embedded
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddFoodActions,
              elevation: 0,
              highlightElevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              icon: const Icon(Icons.add),
              label: Text(context.strings.text('Add food')),
            ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              widget.embedded ? 16 : 20,
              widget.embedded ? 10 : 12,
              widget.embedded ? 16 : 20,
              8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.embedded && search.text.trim().isEmpty) ...[
                  _NutritionHero(
                    languageCode: Localizations.localeOf(context).languageCode,
                  ),
                  const SizedBox(height: 14),
                  _NutritionQuickActions(
                    languageCode: Localizations.localeOf(context).languageCode,
                    onScan: _cameraBarcodeLookup,
                    onManualBarcode: _barcodeLookup,
                    onCustomFood: _createFood,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/wellness-library'),
                    icon: const Icon(Icons.explore_outlined),
                    label: Text(
                      nutritionText(
                        context,
                        'Explore sleep, movement, and daily rhythm',
                        'استكشف النوم والحركة والإيقاع اليومي',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _NutritionTaskBar(
                  searchField: SearchBar(
                    key: const Key('food-primary-search'),
                    controller: search,
                    hintText: nutritionText(
                      context,
                      'Search foods',
                      'البحث عن الأطعمة',
                    ),
                    leading: const Icon(Icons.search),
                    elevation: const WidgetStatePropertyAll(0),
                    backgroundColor: WidgetStatePropertyAll(
                      Theme.of(context).colorScheme.surface,
                    ),
                    side: WidgetStatePropertyAll(
                      BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    trailing: search.text.trim().isEmpty
                        ? const <Widget>[]
                        : <Widget>[
                            IconButton(
                              key: const Key('food-search-clear'),
                              tooltip: t('Clear'),
                              onPressed: () {
                                search.clear();
                                _scheduleSearch('');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                    onChanged: _scheduleSearch,
                  ),
                  onAddFood: _showAddFoodActions,
                ),
                if (runtimeSearchState != _RuntimeSearchUiState.idle) ...[
                  const SizedBox(height: 8),
                  _RuntimeSearchStatus(
                    state: runtimeSearchState,
                    languageCode: Localizations.localeOf(context).languageCode,
                  ),
                ],
                if (correction != null) ...[
                  const SizedBox(height: 8),
                  ActionChip(
                    avatar: const Icon(Icons.auto_fix_high, size: 18),
                    label: Text(
                      '${nutritionText(context, 'Did you mean:', 'هل تقصد:')} $correction?',
                    ),
                    onPressed: () {
                      search.text = correction!;
                      _runSearch(correction!);
                    },
                  ),
                ],
                if (search.text.trim().isEmpty) ...[
                  const SizedBox(height: 12),
                  SegmentedButton<_CatalogView>(
                    key: const Key('food-browse-filters'),
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: _CatalogView.all,
                        label: Text(nutritionText(context, 'All', 'الكل')),
                      ),
                      ButtonSegment(
                        value: _CatalogView.favorites,
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            nutritionText(context, 'Favorites', 'المفضلة'),
                            maxLines: 1,
                          ),
                        ),
                        icon: const Icon(Icons.favorite_outline),
                      ),
                      ButtonSegment(
                        value: _CatalogView.recent,
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            nutritionText(context, 'Recent', 'الأخيرة'),
                            maxLines: 1,
                          ),
                        ),
                        icon: const Icon(Icons.history),
                      ),
                    ],
                    selected: {catalogView},
                    onSelectionChanged: (selection) =>
                        setState(() => catalogView = selection.first),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: allFoods.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => ActionableErrorState(
                title: t('Could not load foods'),
                onRetry: () => ref.invalidate(foodsProvider),
              ),
              data: (foods) {
                final selectedAsync = switch (catalogView) {
                  _CatalogView.all => allFoods,
                  _CatalogView.favorites => favorites,
                  _CatalogView.recent => recent,
                };
                if (search.text.trim().isEmpty && selectedAsync.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (search.text.trim().isEmpty && selectedAsync.hasError) {
                  return ActionableErrorState(
                    title: nutritionText(
                      context,
                      'This local food list could not be loaded.',
                      'تعذر تحميل هذه القائمة المحلية.',
                    ),
                    onRetry: () {
                      ref.invalidate(foodsProvider);
                      ref.invalidate(favoriteFoodsProvider);
                      ref.invalidate(recentFoodsProvider);
                    },
                  );
                }
                final selectedRows = _foodsInScope(switch (catalogView) {
                  _CatalogView.all => foods,
                  _CatalogView.favorites => favorites.value ?? const <Food>[],
                  _CatalogView.recent => recent.value ?? const <Food>[],
                });
                final visible = search.text.trim().isNotEmpty
                    ? _foodsInScope(results ?? const <Food>[])
                    : selectedRows;
                if (search.text.trim().isNotEmpty &&
                    runtimeSearchState == _RuntimeSearchUiState.searching) {
                  return const Center(
                    key: Key('food-search-results-loading'),
                    child: CircularProgressIndicator(),
                  );
                }
                if (visible.isEmpty) {
                  final favoritesEmpty = catalogView == _CatalogView.favorites;
                  final recentEmpty = catalogView == _CatalogView.recent;
                  return Padding(
                    padding: EdgeInsets.only(bottom: widget.embedded ? 0 : 96),
                    child: ActionableEmptyState(
                      key: const Key('food-search-empty-state'),
                      compact: widget.embedded,
                      icon: favoritesEmpty
                          ? Icons.favorite_outline
                          : recentEmpty
                          ? Icons.history
                          : Icons.search_off,
                      title: favoritesEmpty || recentEmpty
                          ? t(
                              favoritesEmpty
                                  ? 'Your favorites will stay one tap away'
                                  : 'Recent foods appear after your first log',
                            )
                          : _foodSearchText(
                              context,
                              'No local food matches this search',
                            ),
                      body: favoritesEmpty || recentEmpty
                          ? t(
                              favoritesEmpty
                                  ? 'Favorite any food you trust to make future logging faster.'
                                  : 'BIL ranks foods you actually use without uploading your history.',
                            )
                          : _foodSearchText(
                              context,
                              'BIL will not invent a match. Create a custom food from verified label evidence.',
                            ),
                      actionLabel: t(
                        widget.embedded
                            ? 'Custom food'
                            : favoritesEmpty || recentEmpty
                            ? 'Browse all foods'
                            : 'Download more foods',
                      ),
                      onAction: widget.embedded
                          ? _createFood
                          : favoritesEmpty || recentEmpty
                          ? () => setState(() => catalogView = _CatalogView.all)
                          : () => context.push('/food-libraries'),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: visible.length,
                  itemBuilder: (_, index) => _FoodTile(
                    food: visible[index],
                    onChanged: () => _runSearch(search.text),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualBarcodeDialog extends StatefulWidget {
  const _ManualBarcodeDialog({
    required this.t,
    required this.onCancel,
    required this.onSubmit,
  });

  final String Function(String) t;
  final VoidCallback onCancel;
  final ValueChanged<String> onSubmit;

  @override
  State<_ManualBarcodeDialog> createState() => _ManualBarcodeDialogState();
}

class _ManualBarcodeDialogState extends State<_ManualBarcodeDialog> {
  String _value = '';
  String? _validationMessage;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.t('Manual barcode lookup')),
    content: TextField(
      autofocus: true,
      keyboardType: TextInputType.number,
      maxLength: 14,
      decoration: InputDecoration(
        labelText: widget.t('Barcode digits'),
        errorText: _validationMessage,
        helperText: widget.t(
          'Enter an 8, 12, 13, or 14 digit GTIN. You can also use the camera scanner from the quick actions above.',
        ),
      ),
      onChanged: (value) {
        _value = value;
        if (_validationMessage != null) {
          setState(() => _validationMessage = null);
        }
      },
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(onPressed: widget.onCancel, child: Text(widget.t('Cancel'))),
      FilledButton(
        onPressed: _submitting ? null : _submit,
        child: Text(widget.t('Search')),
      ),
    ],
  );

  Future<void> _submit() async {
    final value = _value.trim();
    if (value.isEmpty) {
      setState(() => _validationMessage = widget.t('Enter a barcode first'));
      return;
    }
    setState(() => _submitting = true);
    FocusManager.instance.primaryFocus?.unfocus();
    // Keep the dialog alive while Android detaches the numeric IME from
    // TextField's internal controller. Closing both in the same frame races
    // Flutter's transition listeners and can trigger `_dependents.isEmpty`.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    widget.onSubmit(value);
  }
}
