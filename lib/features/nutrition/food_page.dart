import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/database/nutrient_evidence.dart';
import '../../app/localization/app_localizations.dart';
import '../foods/providers/food_provider.dart';
import '../../shared/widgets/actionable_empty_state.dart';
import '../../shared/widgets/actionable_error_state.dart';

enum _CatalogView { all, favorites, recent }

class FoodPage extends ConsumerStatefulWidget {
  const FoodPage({super.key});

  @override
  ConsumerState<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends ConsumerState<FoodPage> {
  final search = TextEditingController();
  List<Food>? results;
  Timer? debounce;
  int searchGeneration = 0;
  _CatalogView catalogView = _CatalogView.all;

  @override
  void dispose() {
    search.dispose();
    debounce?.cancel();
    super.dispose();
  }

  Future<void> _runSearch(String value) async {
    final generation = ++searchGeneration;
    final rows = await ref.read(foodRepositoryProvider).search(value);
    if (mounted && generation == searchGeneration) {
      setState(() => results = rows);
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
      builder: (_) => _CustomFoodDialog(initialBarcode: initialBarcode),
    );
    if (created == null) return;
    await ref
        .read(foodRepositoryProvider)
        .addFood(
          name: created.name,
          arabicName: created.arabicName,
          barcode: created.barcode,
          category: 'custom',
          servingSize: created.servingSize,
          servingUnit: created.servingUnit,
          calories: created.calories,
          protein: created.protein,
          carbs: created.carbs,
          fats: created.fats,
          fiber: created.fiber,
          sodium: created.sodium,
          potassium: created.potassium,
          calcium: created.calcium,
          magnesium: created.magnesium,
          sugar: created.sugar,
        );
    await _runSearch(search.text);
  }

  Future<void> _barcodeLookup() async {
    final t = context.strings.text;
    final controller = TextEditingController();
    final barcode = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('Manual barcode lookup')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: t('Barcode digits'),
            helperText: t(
              'Camera scanning is unavailable until a verified scanner adapter and permissions are configured.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(t('Search')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (barcode == null || barcode.isEmpty) return;
    final matches = await ref.read(foodRepositoryProvider).search(barcode);
    if (!mounted) return;
    if (matches.isNotEmpty) {
      search.text = barcode;
      setState(() => results = matches);
      return;
    }
    final create = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('Barcode not found locally')),
        content: Text(
          t(
            'BIL will not invent nutrition values. You can create a food from the product label and this barcode will be prefilled.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('Not now')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('Create custom food')),
          ),
        ],
      ),
    );
    if (create == true) await _createFood(barcode);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.strings.text;
    final allFoods = ref.watch(foodsProvider);
    final favorites = ref.watch(favoriteFoodsProvider);
    final recent = ref.watch(recentFoodsProvider);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      appBar: AppBar(
        title: Text(context.strings.text('Food catalog')),
        actions: [
          IconButton(
            tooltip: t('Manual barcode lookup'),
            onPressed: _barcodeLookup,
            icon: const Icon(Icons.qr_code_scanner),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createFood,
        icon: const Icon(Icons.add),
        label: Text(context.strings.text('Custom food')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SearchBar(
                  controller: search,
                  hintText: t('English, Arabic, keyword, or barcode'),
                  leading: const Icon(Icons.search),
                  onChanged: _scheduleSearch,
                ),
                const SizedBox(height: 12),
                SegmentedButton<_CatalogView>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: _CatalogView.all,
                      label: Text(arabic ? 'الكل' : 'All'),
                    ),
                    ButtonSegment(
                      value: _CatalogView.favorites,
                      label: Text(arabic ? 'المفضلة' : 'Favorites'),
                      icon: const Icon(Icons.favorite_outline),
                    ),
                    ButtonSegment(
                      value: _CatalogView.recent,
                      label: Text(arabic ? 'الأخيرة' : 'Recent'),
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
                    title: arabic
                        ? 'تعذر تحميل هذه القائمة المحلية.'
                        : 'This local food list could not be loaded.',
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
                  return ActionableEmptyState(
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
                      favoritesEmpty || recentEmpty
                          ? 'Browse all foods'
                          : 'Add food from label',
                    ),
                    onAction: favoritesEmpty || recentEmpty
                        ? () => setState(() => catalogView = _CatalogView.all)
                        : _createFood,
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

class _FoodTile extends ConsumerStatefulWidget {
  const _FoodTile({required this.food, required this.onChanged});
  final Food food;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<_FoodTile> createState() => _FoodTileState();
}

class _FoodTileState extends ConsumerState<_FoodTile> {
  bool favorite = false;

  @override
  void initState() {
    super.initState();
    Future<void>(() async {
      final rows = await ref
          .read(foodRepositoryProvider)
          .watchFavorites()
          .first;
      if (mounted) {
        setState(
          () => favorite = rows.any((food) => food.id == widget.food.id),
        );
      }
    });
  }

  Future<void> _edit() async {
    final draft = await showDialog<_FoodDraft>(
      context: context,
      builder: (_) => _CustomFoodDialog(food: widget.food),
    );
    if (draft == null) return;
    await ref
        .read(foodRepositoryProvider)
        .updateCustomFood(
          id: widget.food.id,
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
          fiber: draft.fiber,
          sodium: draft.sodium,
          potassium: draft.potassium,
          calcium: draft.calcium,
          magnesium: draft.magnesium,
          sugar: draft.sugar,
        );
    await widget.onChanged();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.strings.text('Delete custom food?')),
        content: Text(
          context.strings.text(
            'Existing meal history keeps its nutrition snapshot. This food will no longer appear in search.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.strings.text('Delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(foodRepositoryProvider).deleteCustomFood(widget.food.id);
      await widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.strings.text;
    final food = widget.food;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: ListTile(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    food.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (food.arabicName != null) Text(food.arabicName!),
                  const SizedBox(height: 12),
                  Text('${t('Source')}: ${t(food.source)}'),
                  Text(
                    food.verified
                        ? t('Verified catalog record')
                        : t('Not independently verified'),
                  ),
                  Text(
                    '${t('Normalized serving')}: ${food.servingSize.toStringAsFixed(0)} ${food.servingUnit}',
                  ),
                  Text('${t('Updated locally')}: ${food.updatedAt.toLocal()}'),
                  const SizedBox(height: 12),
                  Text(
                    '${food.calories.toStringAsFixed(0)} kcal · ${food.protein.toStringAsFixed(1)} g protein · '
                    '${food.carbs.toStringAsFixed(1)} g carbs · ${food.fats.toStringAsFixed(1)} g fat',
                  ),
                  if (food.isCustom) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _edit();
                            },
                            icon: const Icon(Icons.edit_outlined),
                            label: Text(t('Edit custom food')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _delete();
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: Text(t('Delete')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        title: Text(
          food.arabicName == null
              ? food.name
              : '${food.arabicName} • ${food.name}',
        ),
        subtitle: Text(
          '${food.calories.toStringAsFixed(0)} kcal · ${food.protein.toStringAsFixed(1)} g protein / '
          '${food.servingSize.toStringAsFixed(0)} ${food.servingUnit}\n${t(food.source)} · ${t(food.verified ? 'verified' : 'unverified')}',
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: t(favorite ? 'Remove favorite' : 'Add favorite'),
          icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
          onPressed: () async {
            final next = !favorite;
            await ref.read(foodRepositoryProvider).setFavorite(food.id, next);
            if (mounted) setState(() => favorite = next);
          },
        ),
      ),
    );
  }
}

class _FoodDraft {
  const _FoodDraft({
    required this.name,
    required this.arabicName,
    required this.barcode,
    required this.servingSize,
    required this.servingUnit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.fiber,
    required this.sodium,
    required this.potassium,
    required this.calcium,
    required this.magnesium,
    required this.sugar,
  });
  final String name;
  final String? arabicName;
  final String? barcode;
  final double servingSize;
  final String servingUnit;
  final double calories;
  final double protein;
  final double carbs;
  final double fats;
  final double? fiber;
  final double? sodium;
  final double? potassium;
  final double? calcium;
  final double? magnesium;
  final double? sugar;
}

class _CustomFoodDialog extends StatefulWidget {
  const _CustomFoodDialog({this.initialBarcode, this.food});

  final String? initialBarcode;
  final Food? food;

  @override
  State<_CustomFoodDialog> createState() => _CustomFoodDialogState();
}

class _CustomFoodDialogState extends State<_CustomFoodDialog> {
  final formKey = GlobalKey<FormState>();
  final controllers = List.generate(15, (_) => TextEditingController());

  @override
  void initState() {
    super.initState();
    final food = widget.food;
    if (food == null) {
      controllers[2].text = widget.initialBarcode ?? '';
      controllers[3].text = '100';
      controllers[4].text = 'g';
      for (var index = 5; index <= 8; index++) {
        controllers[index].text = '0';
      }
      return;
    }
    final values = <String>[
      food.name,
      food.arabicName ?? '',
      food.barcode ?? '',
      food.servingSize.toString(),
      food.servingUnit,
      food.calories.toString(),
      food.protein.toString(),
      food.carbs.toString(),
      food.fats.toString(),
      NutrientEvidenceMask.contains(
            food.nutrientEvidenceMask,
            TrackedNutrient.fiber,
          )
          ? food.fiber.toString()
          : '',
      NutrientEvidenceMask.contains(
            food.nutrientEvidenceMask,
            TrackedNutrient.sodium,
          )
          ? food.sodium.toString()
          : '',
      NutrientEvidenceMask.contains(
            food.nutrientEvidenceMask,
            TrackedNutrient.potassium,
          )
          ? food.potassium.toString()
          : '',
      NutrientEvidenceMask.contains(
            food.nutrientEvidenceMask,
            TrackedNutrient.calcium,
          )
          ? food.calcium.toString()
          : '',
      NutrientEvidenceMask.contains(
            food.nutrientEvidenceMask,
            TrackedNutrient.magnesium,
          )
          ? food.magnesium.toString()
          : '',
      NutrientEvidenceMask.contains(
            food.nutrientEvidenceMask,
            TrackedNutrient.sugar,
          )
          ? food.sugar.toString()
          : '',
    ];
    for (var index = 0; index < values.length; index++) {
      controllers[index].text = values[index];
    }
  }

  @override
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.strings.text;
    const labels = <String>[
      'English name',
      'Arabic name',
      'Barcode',
      'Serving size',
      'Serving unit',
      'Calories',
      'Protein',
      'Carbohydrates',
      'Fat',
      'Fiber',
      'Sodium',
      'Potassium',
      'Calcium',
      'Magnesium',
      'Sugar',
    ];
    return AlertDialog(
      title: Text(
        t(widget.food == null ? 'Create custom food' : 'Edit custom food'),
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(labels.length, (index) {
                return TextFormField(
                  controller: controllers[index],
                  decoration: InputDecoration(labelText: t(labels[index])),
                  keyboardType: index >= 3 && index != 4
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.text,
                  validator: (value) {
                    if (index == 0 && (value == null || value.trim().isEmpty)) {
                      return t('Required');
                    }
                    if (index >= 3 && index != 4) {
                      if (index >= 9 && (value == null || value.isEmpty)) {
                        return null;
                      }
                      final number = double.tryParse(
                        (value ?? '').replaceAll(',', '.'),
                      );
                      if (number == null ||
                          !number.isFinite ||
                          number < 0 ||
                          (index == 3 && number <= 0)) {
                        return t('Enter a non-negative number');
                      }
                    }
                    return null;
                  },
                );
              }),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('Cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            double number(int index) =>
                double.parse(controllers[index].text.replaceAll(',', '.'));
            double? optionalNumber(int index) =>
                controllers[index].text.trim().isEmpty ? null : number(index);
            Navigator.pop(
              context,
              _FoodDraft(
                name: controllers[0].text.trim(),
                arabicName: controllers[1].text.trim().isEmpty
                    ? null
                    : controllers[1].text.trim(),
                barcode: controllers[2].text.trim().isEmpty
                    ? null
                    : controllers[2].text.trim(),
                servingSize: number(3),
                servingUnit: controllers[4].text.trim().isEmpty
                    ? 'g'
                    : controllers[4].text.trim(),
                calories: number(5),
                protein: number(6),
                carbs: number(7),
                fats: number(8),
                fiber: optionalNumber(9),
                sodium: optionalNumber(10),
                potassium: optionalNumber(11),
                calcium: optionalNumber(12),
                magnesium: optionalNumber(13),
                sugar: optionalNumber(14),
              ),
            );
          },
          child: Text(t('Save')),
        ),
      ],
    );
  }
}
