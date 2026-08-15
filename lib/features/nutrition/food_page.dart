import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/database/app_database.dart';
import '../../data/database/nutrient_evidence.dart';
import '../../app/localization/app_localizations.dart';
import '../../app/theme/bil_flagship_tokens.dart';
import '../foods/providers/food_provider.dart';
import '../community/presentation/product_review_submission_dialog.dart';
import 'services/food_runtime_search_authority.dart';
import 'services/food_search_assistance.dart';
import 'presentation/food_barcode_scanner_page.dart';
import 'presentation/product_identity_copy.dart';
import 'presentation/barcode_runtime_copy.dart';
import 'presentation/nutrition_copy.dart';
import 'presentation/meal_image_guide_page.dart';
import '../../shared/widgets/actionable_empty_state.dart';
import '../../shared/widgets/actionable_error_state.dart';

part 'presentation/food_catalog_overview.dart';
part 'presentation/food_catalog_tile.dart';
part 'presentation/custom_food_dialog.dart';
part 'presentation/custom_food_locale_copy.dart';

enum _CatalogView { all, favorites, recent }

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
  const FoodPage({super.key, this.embedded = false});

  final bool embedded;

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

    final outcome = await ref
        .read(foodRuntimeSearchAuthorityProvider)
        .searchDetailed(value);

    if (mounted && generation == searchGeneration) {
      setState(() {
        results = outcome.foods;
        correction = outcome.foods.isEmpty
            ? _assistance.correctionFor(trimmed)
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
    debounce = Timer(
      const Duration(milliseconds: 180),
      () => _runSearch(value),
    );
  }

  Future<void> _createFood([String? initialBarcode]) async {
    final created = await showDialog<_FoodDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CustomFoodDialog(
        initialBarcode: initialBarcode,
        onSave: (draft) => ref
            .read(foodRepositoryProvider)
            .addFood(
              name: draft.name,
              arabicName: draft.arabicName,
              barcode: draft.barcode,
              category: 'custom',
              servingSize: draft.servingSize,
              servingUnit: draft.servingUnit,
              calories: draft.calories,
              protein: draft.protein,
              carbs: draft.carbs,
              fats: draft.fats,
              caloriesKnown: draft.caloriesKnown,
              proteinKnown: draft.proteinKnown,
              carbsKnown: draft.carbsKnown,
              fatsKnown: draft.fatsKnown,
              fiber: draft.fiber,
              sodium: draft.sodium,
              potassium: draft.potassium,
              calcium: draft.calcium,
              magnesium: draft.magnesium,
              sugar: draft.sugar,
            ),
      ),
    );
    if (created == null) return;
    await _runSearch(search.text);
  }

  Future<void> _cameraBarcodeLookup() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const FoodBarcodeScannerPage()),
    );
    if (barcode == null || barcode.isEmpty) return;
    await _lookupBarcodeValue(barcode);
  }

  Future<void> _lookupBarcodeValue(String barcode) async {
    final t = context.strings.text;
    final barcodeCopy = BarcodeRuntimeCopy.of(
      Localizations.localeOf(context).languageCode,
    );
    final outcome = await ref
        .read(foodRuntimeSearchAuthorityProvider)
        .lookupBarcodeJourney(barcode);

    if (!mounted) return;

    if (outcome.invalid) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(barcodeCopy.invalidTitle),
          content: Text(barcodeCopy.invalidBody),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t('OK')),
            ),
          ],
        ),
      );
      return;
    }

    if (outcome.found) {
      search.text = outcome.normalizedBarcode;
      setState(() {
        results = outcome.foods;
        runtimeSearchState = switch (outcome.source) {
          FoodRuntimeSearchSource.catalogAndLocal =>
            _RuntimeSearchUiState.catalogAndLocal,
          FoodRuntimeSearchSource.localOnly => _RuntimeSearchUiState.localOnly,
          FoodRuntimeSearchSource.localFallback =>
            _RuntimeSearchUiState.localFallback,
        };
      });
      return;
    }

    if (outcome.product != null) {
      final arabic = Localizations.localeOf(context).languageCode == 'ar';
      final submitReview = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            productKindLabel(
              outcome.product!.kind,
              arabic: arabic,
              languageCode: Localizations.localeOf(context).languageCode,
            ),
          ),
          content: Text(
            productIdentityExplanation(
              outcome.product!,
              arabic: arabic,
              languageCode: Localizations.localeOf(context).languageCode,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                nutritionText(context, 'Submit for review', 'إرسال للمراجعة'),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t('OK')),
            ),
          ],
        ),
      );
      if (submitReview == true && mounted) {
        await showProductReviewSubmissionDialog(
          context,
          barcode: outcome.normalizedBarcode,
          suggestedProduct: outcome.product,
        );
      }
      return;
    }

    setState(() {
      runtimeSearchState = outcome.degraded
          ? _RuntimeSearchUiState.localFallback
          : _RuntimeSearchUiState.localOnly;
    });

    final action = await showDialog<_UnverifiedBarcodeAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          outcome.degraded ? t('Catalog unavailable') : t('Barcode not found'),
        ),
        content: Text(
          outcome.degraded
              ? t(
                  'The verified catalog could not be reached. BIL will not invent nutrition values. You can create this product from its label, or try again later.',
                )
              : t(
                  'No verified product matched this barcode. BIL will not invent nutrition values. You can create a food from the product label and the barcode will be prefilled.',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _UnverifiedBarcodeAction.dismiss),
            child: Text(t('Not now')),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _UnverifiedBarcodeAction.submitReview),
            child: Text(
              nutritionText(context, 'Submit for review', 'إرسال للمراجعة'),
            ),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(
              context,
              _UnverifiedBarcodeAction.scanProductLabel,
            ),
            icon: const Icon(Icons.document_scanner_rounded),
            label: Text(
              nutritionText(context, 'Scan product label', 'امسح ملصق المنتج'),
            ),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, _UnverifiedBarcodeAction.createFood),
            child: Text(t('Create custom food')),
          ),
        ],
      ),
    );

    if (action == _UnverifiedBarcodeAction.submitReview && mounted) {
      await showProductReviewSubmissionDialog(
        context,
        barcode: outcome.normalizedBarcode,
      );
    } else if (action == _UnverifiedBarcodeAction.createFood) {
      await _createFood(outcome.normalizedBarcode);
    } else if (action == _UnverifiedBarcodeAction.scanProductLabel && mounted) {
      // Barcode entitlement was enforced upstream. This screen is the
      // authoritative weekly AI Coach and paid AI Boost allowance gate; its
      // capture route is review-first and never auto-logs.
      final accepted = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => const MealImageGuidePage(),
          fullscreenDialog: true,
        ),
      );
      if (accepted == true && mounted) {
        await context.push(
          '/intelligence-center?vision=capture&barcode=${Uri.encodeQueryComponent(outcome.normalizedBarcode)}',
        );
      }
    }
  }

  Future<void> _barcodeLookup() async {
    final t = context.strings.text;
    final barcode = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _ManualBarcodeDialog(
        t: t,
        onCancel: () => Navigator.pop(dialogContext),
        onSubmit: (value) => Navigator.pop(dialogContext, value),
      ),
    );

    if (barcode == null) return;

    await _lookupBarcodeValue(barcode);
  }

  Future<void> _openOfficialUsdaDownloads() async {
    final uri = Uri.parse('https://fdc.nal.usda.gov/download-datasets/');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (Localizations.localeOf(context).languageCode) {
            'ar' => 'تعذّر فتح تنزيلات USDA.',
            'fr' => 'Impossible d’ouvrir les téléchargements USDA.',
            'es' => 'No se pudieron abrir las descargas de USDA.',
            'tr' => 'USDA indirmeleri açılamadı.',
            _ => 'Could not open USDA downloads.',
          }),
        ),
      );
    }
  }

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
              onPressed: _createFood,
              elevation: 0,
              highlightElevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              icon: const Icon(Icons.add),
              label: Text(context.strings.text('Custom food')),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (search.text.trim().isEmpty) ...[
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
                SearchBar(
                  controller: search,
                  hintText: t('English, Arabic, keyword, or barcode'),
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
                  onChanged: _scheduleSearch,
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
                const SizedBox(height: 12),
                SegmentedButton<_CatalogView>(
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
                final selectedRows = switch (catalogView) {
                  _CatalogView.all => foods,
                  _CatalogView.favorites => favorites.value ?? const <Food>[],
                  _CatalogView.recent => recent.value ?? const <Food>[],
                };
                final visible = search.text.trim().isNotEmpty
                    ? (results ?? const <Food>[])
                    : selectedRows;
                if (visible.isEmpty) {
                  final favoritesEmpty = catalogView == _CatalogView.favorites;
                  final recentEmpty = catalogView == _CatalogView.recent;
                  return Padding(
                    padding: EdgeInsets.only(bottom: widget.embedded ? 0 : 96),
                    child: ActionableEmptyState(
                      compact: widget.embedded,
                      icon: favoritesEmpty
                          ? Icons.favorite_outline
                          : recentEmpty
                          ? Icons.history
                          : Icons.search_off,
                      title: t(
                        favoritesEmpty
                            ? 'Your favorites will stay one tap away'
                            : recentEmpty
                            ? 'Recent foods appear after your first log'
                            : 'No local food matches this search',
                      ),
                      body: t(
                        favoritesEmpty
                            ? 'Favorite any food you trust to make future logging faster.'
                            : recentEmpty
                            ? 'BIL ranks foods you actually use without uploading your history.'
                            : 'BIL will not invent a match. Create a custom food from verified label evidence.',
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
                          : _openOfficialUsdaDownloads,
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
