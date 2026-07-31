import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/database/app_database.dart';
import '../../data/database/nutrient_evidence.dart';
import '../../app/localization/app_localizations.dart';
import '../../app/theme/premium_design_tokens.dart';
import '../../shared/widgets/actionable_error_state.dart';
import '../../shared/widgets/premium_surface.dart';
import '../foods/providers/food_provider.dart';
import 'providers/daily_log_provider.dart';

class DailyLogPage extends ConsumerStatefulWidget {
  const DailyLogPage({
    super.key,
    this.initialMealType,
    this.focusMealEntry = false,
  });

  final String? initialMealType;
  final bool focusMealEntry;

  @override
  ConsumerState<DailyLogPage> createState() => _DailyLogPageState();
}

class _DailyLogPageState extends ConsumerState<DailyLogPage> {
  final notes = TextEditingController();
  final water = TextEditingController(text: '250');
  final quantity = TextEditingController(text: '100');
  final foodSearch = SearchController();
  final otherContext = TextEditingController();
  final scrollController = ScrollController();
  final mealEntryKey = GlobalKey();
  bool mealFocusApplied = false;
  Food? selectedFood;
  String mealType = 'breakfast';
  final Set<String> selectedContexts = {};
  String? loadedNotes;

  static const contextOptions = <String>[
    'poorSleep',
    'greatSleep',
    'travel',
    'fasting',
    'highSodiumMeal',
    'hardWorkout',
    'psychologicalStress',
    'illnessSymptoms',
    'medication',
    'lessWater',
    'moreWater',
    'constipation',
    'nothingNotable',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    if (const {
      'breakfast',
      'lunch',
      'dinner',
      'snack',
    }.contains(widget.initialMealType)) {
      mealType = widget.initialMealType!;
    }
    if (widget.focusMealEntry) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusMealEntry());
    }
  }

  void _focusMealEntry() {
    final mealContext = mealEntryKey.currentContext;
    if (!mounted || mealContext == null) return;
    mealFocusApplied = true;
    Scrollable.ensureVisible(
      mealContext,
      alignment: 0,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    notes.dispose();
    water.dispose();
    quantity.dispose();
    foodSearch.dispose();
    otherContext.dispose();
    scrollController.dispose();
    super.dispose();
  }

  bool get _arabic =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

  String _tr(String en, String ar) => _arabic ? ar : en;

  String _unit(String value) {
    if (!_arabic) return value;
    return switch (value.toLowerCase()) {
      'g' => 'جم',
      'mg' => 'مجم',
      'ml' => 'مل',
      'kcal' => 'سعرة',
      _ => value,
    };
  }

  String _contextLabel(String value) => switch (value) {
    'poorSleep' => _tr('Less sleep than usual', 'نوم أقل من المعتاد'),
    'greatSleep' => _tr('Excellent sleep', 'نوم ممتاز'),
    'travel' => _tr('Travel', 'سفر'),
    'fasting' => _tr('Fasting', 'صيام'),
    'highSodiumMeal' => _tr('High-sodium meal', 'وجبة عالية الصوديوم'),
    'hardWorkout' => _tr('Hard workout', 'تمرين قوي'),
    'psychologicalStress' => _tr('Psychological stress', 'إجهاد نفسي'),
    'illnessSymptoms' => _tr('Illness or symptoms', 'مرض أو أعراض'),
    'medication' => _tr('Medication', 'تناول دواء'),
    'lessWater' => _tr('Less water than usual', 'شرب ماء أقل من المعتاد'),
    'moreWater' => _tr('More water than usual', 'شرب ماء أكثر من المعتاد'),
    'constipation' => _tr('Constipation', 'إمساك'),
    'nothingNotable' => _tr('Nothing notable', 'لا يوجد شيء مميز'),
    'other' => _tr('Other', 'أخرى'),
    _ => value,
  };

  void _loadContextSelection(String value) {
    if (loadedNotes == value) return;
    loadedNotes = value;
    selectedContexts.clear();
    otherContext.clear();
    if (value.isEmpty) return;
    final matches = RegExp(r'\[([A-Za-z]+)\]').allMatches(value).toList();
    if (matches.isEmpty) {
      selectedContexts.add('other');
      otherContext.text = value;
      return;
    }
    selectedContexts.addAll(
      matches
          .map((match) => match.group(1))
          .whereType<String>()
          .where(contextOptions.contains),
    );
    final otherMatch = RegExp(r'\[other\]\s*(.*)$').firstMatch(value);
    if (otherMatch != null) otherContext.text = otherMatch.group(1) ?? '';
  }

  void _syncContextNotes() {
    final ordered = contextOptions.where(selectedContexts.contains).toList();
    final encoded = ordered
        .where((value) => value != 'other')
        .map((value) => '[$value]')
        .toList();
    if (selectedContexts.contains('other')) {
      encoded.add('[other] ${otherContext.text.trim()}'.trim());
    }
    notes.text = encoded.join(' ');
    loadedNotes = notes.text;
  }

  Future<void> _save() async {
    final date = ref.read(selectedLogDateProvider);
    final repository = ref.read(dailyLogRepositoryProvider);
    await repository.save(
      date: date,
      notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
    );
    if (!mounted) return;
    context.go('/dashboard');
  }

  Future<void> _saveMeal() async {
    if (selectedFood == null) {
      return;
    }

    final mealRepository = ref.read(mealRepositoryProvider);
    final date = ref.read(selectedLogDateProvider);
    final mealId = await mealRepository.createMeal(
      date: date,
      name: mealType,
      type: mealType,
    );

    final quantityValue = _parsePositiveQuantity(quantity.text);
    if (quantityValue == null) {
      _message('Enter a quantity from 0.1 to 100000.');
      return;
    }

    await mealRepository.addMealItem(
      mealId: mealId,
      foodId: selectedFood!.id,
      quantity: quantityValue,
    );
    await ref.read(foodRepositoryProvider).recordRecent(selectedFood!.id);
    quantity.text = quantityValue.toStringAsFixed(
      quantityValue.truncateToDouble() == quantityValue ? 0 : 1,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.strings.text('Meal saved locally.'))),
    );
  }

  Future<void> _addWater([int? quickAmount]) async {
    final amount = quickAmount ?? int.tryParse(water.text);
    if (amount == null || amount <= 0 || amount > 5000) {
      _message('Enter a water amount from 1 to 5000 ml.');
      return;
    }
    final date = ref.read(selectedLogDateProvider);
    final now = DateTime.now();
    await ref
        .read(waterRepositoryProvider)
        .add(
          occurredAt: DateTime(
            date.year,
            date.month,
            date.day,
            now.hour,
            now.minute,
          ),
          amountMl: amount,
        );
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.strings.text(message))));
  }

  Future<void> _deleteMealItem(MealItem item, String foodName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.strings.text('Remove meal item?')),
        content: Text(
          '${context.strings.text('Remove')} $foodName ${context.strings.text('from this meal?')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.strings.text('Remove')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(mealRepositoryProvider).deleteMealItem(item.id);
    }
  }

  Future<void> _editMealItem(MealItem item, Food food) async {
    final controller = TextEditingController(text: item.quantity.toString());
    final updated = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${context.strings.text('Edit')} ${food.name}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText:
                '${context.strings.text('Quantity')} (${food.servingUnit})',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              double.tryParse(controller.text.replaceAll(',', '.')),
            ),
            child: Text(context.strings.text('Update')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (updated == null) return;
    final normalizedUpdated = _parsePositiveQuantity(updated.toString());
    if (normalizedUpdated == null) return;
    await ref
        .read(mealRepositoryProvider)
        .updateMealItem(id: item.id, quantity: normalizedUpdated);
  }

  Future<void> _showItemActions(MealItem item, Food? food) async {
    final foodName = food?.name ?? context.strings.text('Historical food');
    final activeFood = food != null && food.deletedAt == null;
    final favorite = activeFood
        ? await ref.read(foodRepositoryProvider).isFavorite(food.id)
        : false;
    if (!mounted) return;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              enabled: activeFood,
              title: Text(arabic ? 'تعديل الكمية' : 'Edit quantity'),
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: Text(arabic ? 'تكرار العنصر' : 'Duplicate item'),
              subtitle: Text(
                arabic
                    ? 'يُنسخ نفس المقدار ولقطة التغذية المحفوظة.'
                    : 'Copies the same quantity and saved nutrition snapshot.',
              ),
              onTap: () => Navigator.pop(sheetContext, 'duplicate'),
            ),
            ListTile(
              leading: Icon(favorite ? Icons.favorite : Icons.favorite_border),
              enabled: activeFood,
              title: Text(
                favorite
                    ? (arabic ? 'إزالة من المفضلة' : 'Remove favorite')
                    : (arabic ? 'إضافة إلى المفضلة' : 'Add favorite'),
              ),
              onTap: () => Navigator.pop(sheetContext, 'favorite'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(arabic ? 'حذف من الوجبة' : 'Delete from meal'),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ],
        ),
      ),
    );
    switch (action) {
      case 'edit':
        await _editMealItem(item, food!);
      case 'duplicate':
        await ref.read(mealRepositoryProvider).duplicateMealItem(item.id);
      case 'favorite':
        await ref.read(foodRepositoryProvider).setFavorite(food!.id, !favorite);
      case 'delete':
        await _deleteMealItem(item, foodName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foods = ref.watch(foodsProvider);
    final date = ref.watch(selectedLogDateProvider);
    final meals = ref.watch(dailyMealsProvider);
    final waterEntries = ref.watch(dailyWaterProvider);
    final usualMeals = ref.watch(usualMealsProvider(mealType));
    ref.listen(selectedDailyLogProvider, (_, next) {
      next.whenData((log) {
        final value = log?.notes ?? '';
        if (notes.text != value) notes.text = value;
        _loadContextSelection(value);
      });
    });

    return Scaffold(
      appBar: AppBar(title: Text(context.strings.text('Diary'))),
      body: Semantics(
        container: true,
        child: foods.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ActionableErrorState(
            title: context.strings.text('Could not load the food catalog.'),
            onRetry: () => ref.invalidate(foodsProvider),
          ),
          data: (items) {
            if (widget.focusMealEntry && !mealFocusApplied) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _focusMealEntry(),
              );
            }
            return ListView(
              controller: scrollController,
              padding: PremiumDesignTokens.screenPadding,
              children: [
                if (!widget.focusMealEntry) ...[
                  Semantics(
                    header: true,
                    child: Text(
                      _tr('Record your day', 'سجّل يومك'),
                      style: PremiumDesignTokens.screenHeading(context),
                    ),
                  ),
                  const SizedBox(height: PremiumDesignTokens.spaceSm),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text(
                      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) {
                        ref.read(selectedLogDateProvider.notifier).state =
                            picked;
                      }
                    },
                  ),
                ],
                PremiumSurface(
                  key: mealEntryKey,
                  child: Column(
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          context.strings.text('Meal type'),
                          style: PremiumDesignTokens.cardHeading(context),
                        ),
                      ),
                      const SizedBox(height: PremiumDesignTokens.spaceXs),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final type in const [
                            'breakfast',
                            'lunch',
                            'dinner',
                            'snack',
                          ])
                            ChoiceChip(
                              avatar: Icon(switch (type) {
                                'breakfast' => Icons.free_breakfast_outlined,
                                'lunch' => Icons.lunch_dining_outlined,
                                'dinner' => Icons.dinner_dining_outlined,
                                _ => Icons.cookie_outlined,
                              }, size: 18),
                              label: Text(
                                context.strings.text(
                                  '${type[0].toUpperCase()}${type.substring(1)}',
                                ),
                              ),
                              selected: mealType == type,
                              onSelected: (_) =>
                                  setState(() => mealType = type),
                            ),
                        ],
                      ),
                      usualMeals.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => ActionableErrorState(
                          title: context.strings.text(
                            'Your usual meals could not be loaded.',
                          ),
                          onRetry: () =>
                              ref.invalidate(usualMealsProvider(mealType)),
                        ),
                        data: (candidates) {
                          if (candidates.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(
                                height: PremiumDesignTokens.spaceSm,
                              ),
                              Text(
                                Localizations.localeOf(context).languageCode ==
                                        'ar'
                                    ? 'وجباتك المعتادة — لن تتم الإضافة دون تأكيدك'
                                    : 'Your usual meals — nothing is added without your confirmation',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(
                                height: PremiumDesignTokens.spaceXs,
                              ),
                              for (final candidate in candidates)
                                Card.outlined(
                                  child: ListTile(
                                    leading: const Icon(Icons.replay_outlined),
                                    title: Text(
                                      candidate.source.items
                                          .map(
                                            (item) => candidate
                                                .source
                                                .foodsById[item.foodId]
                                                ?.name,
                                          )
                                          .whereType<String>()
                                          .join(' + '),
                                    ),
                                    subtitle: Text(
                                      Localizations.localeOf(
                                                context,
                                              ).languageCode ==
                                              'ar'
                                          ? 'سجلتها ${candidate.occurrences} مرات'
                                          : 'Logged ${candidate.occurrences} times',
                                    ),
                                    trailing: FilledButton.tonal(
                                      onPressed: () async {
                                        await ref
                                            .read(mealRepositoryProvider)
                                            .repeatMeal(
                                              candidate: candidate,
                                              date: date,
                                            );
                                        ref.invalidate(
                                          usualMealsProvider(mealType),
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                context.strings.text(
                                                  'Meal saved locally.',
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: Text(
                                        Localizations.localeOf(
                                                  context,
                                                ).languageCode ==
                                                'ar'
                                            ? 'أضف'
                                            : 'Add',
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: PremiumDesignTokens.spaceSm),
                      SearchAnchor(
                        searchController: foodSearch,
                        viewHintText:
                            Localizations.localeOf(context).languageCode == 'ar'
                            ? 'ابحث بالاسم العربي أو الإنجليزي أو الباركود'
                            : 'Search English, Arabic, keyword, or barcode',
                        builder: (context, controller) => SearchBar(
                          controller: controller,
                          leading: const Icon(Icons.search),
                          hintText:
                              Localizations.localeOf(context).languageCode ==
                                  'ar'
                              ? 'ابحث عن طعام'
                              : 'Search foods',
                          onTap: controller.openView,
                          onChanged: (_) => controller.openView(),
                        ),
                        suggestionsBuilder: (context, controller) async {
                          final arabic =
                              Localizations.localeOf(context).languageCode ==
                              'ar';
                          final results = await ref
                              .read(foodRepositoryProvider)
                              .search(controller.text, limit: 20);
                          if (results.isEmpty) {
                            return [
                              ListTile(
                                leading: const Icon(Icons.search_off),
                                title: Text(
                                  arabic
                                      ? 'لا توجد نتائج محلية. يمكنك إنشاء طعام مخصص من دليل الأطعمة.'
                                      : 'No local result. Create a custom food from the food catalog.',
                                ),
                              ),
                            ];
                          }
                          return results.map(
                            (food) => ListTile(
                              leading: Icon(
                                food.isCustom
                                    ? Icons.person_outline
                                    : Icons.verified_outlined,
                              ),
                              title: Text(
                                !arabic || food.arabicName == null
                                    ? food.name
                                    : food.arabicName!,
                              ),
                              subtitle: Text(
                                arabic
                                    ? '${food.calories.toStringAsFixed(0)} سعرة / '
                                          '${food.servingSize.toStringAsFixed(0)} ${_unit(food.servingUnit)}'
                                    : '${food.calories.toStringAsFixed(0)} kcal / '
                                          '${food.servingSize.toStringAsFixed(0)} ${food.servingUnit} · ${food.source}',
                              ),
                              onTap: () {
                                setState(() => selectedFood = food);
                                controller.closeView(food.name);
                              },
                            ),
                          );
                        },
                      ),
                      if (selectedFood != null)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.check_circle),
                          title: Text(
                            _arabic && selectedFood!.arabicName != null
                                ? selectedFood!.arabicName!
                                : selectedFood!.name,
                          ),
                          subtitle: Text(
                            _arabic
                                ? context.strings.text(
                                    selectedFood!.verified
                                        ? 'Verified'
                                        : 'Unverified',
                                  )
                                : '${selectedFood!.source} · ${context.strings.text(selectedFood!.verified ? 'Verified' : 'Unverified')}',
                          ),
                          trailing: IconButton(
                            onPressed: () =>
                                setState(() => selectedFood = null),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      const SizedBox(height: PremiumDesignTokens.spaceXs),
                      TextField(
                        controller: quantity,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText:
                              '${context.strings.text('Quantity')} '
                              '(${_unit(selectedFood?.servingUnit ?? 'g')})',
                        ),
                        onSubmitted: (_) => _saveMeal(),
                      ),
                      const SizedBox(height: PremiumDesignTokens.spaceSm),
                      FilledButton.tonalIcon(
                        onPressed: selectedFood == null ? null : _saveMeal,
                        icon: const Icon(Icons.restaurant_menu),
                        label: Text(context.strings.text('Save meal')),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: PremiumDesignTokens.spaceSm),
                meals.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => ActionableErrorState(
                    title: context.strings.text('Meals unavailable'),
                    onRetry: () => ref.invalidate(dailyMealsProvider),
                  ),
                  data: (rows) {
                    if (rows.isEmpty) {
                      return Text(
                        context.strings.text('No meals for this day.'),
                      );
                    }
                    final allItems = rows.expand((meal) => meal.items).toList();
                    return Column(
                      children: [
                        ListTile(
                          title: Text(
                            context.strings.text('Calculated nutrition'),
                          ),
                          subtitle: Text(
                            _arabic
                                ? '${allItems.fold<double>(0, (sum, item) => sum + item.calories).toStringAsFixed(0)} سعرة · '
                                      '${allItems.fold<double>(0, (sum, item) => sum + item.protein).toStringAsFixed(1)} جم بروتين · '
                                      '${allItems.fold<double>(0, (sum, item) => sum + item.carbs).toStringAsFixed(1)} جم كربوهيدرات · '
                                      '${allItems.fold<double>(0, (sum, item) => sum + item.fats).toStringAsFixed(1)} جم دهون'
                                : '${allItems.fold<double>(0, (sum, item) => sum + item.calories).toStringAsFixed(0)} kcal · '
                                      '${allItems.fold<double>(0, (sum, item) => sum + item.protein).toStringAsFixed(1)} g protein · '
                                      '${allItems.fold<double>(0, (sum, item) => sum + item.carbs).toStringAsFixed(1)} g carbs · '
                                      '${allItems.fold<double>(0, (sum, item) => sum + item.fats).toStringAsFixed(1)} g fat',
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _NutrientMetric(
                              label: 'Fiber',
                              value: _knownNutrientTotal(
                                allItems,
                                TrackedNutrient.fiber,
                                (item) => item.fiber,
                              ),
                              unit: 'g',
                            ),
                            _NutrientMetric(
                              label: 'Sodium',
                              value: _knownNutrientTotal(
                                allItems,
                                TrackedNutrient.sodium,
                                (item) => item.sodium,
                              ),
                              unit: 'mg',
                            ),
                            _NutrientMetric(
                              label: 'Potassium',
                              value: _knownNutrientTotal(
                                allItems,
                                TrackedNutrient.potassium,
                                (item) => item.potassium,
                              ),
                              unit: 'mg',
                            ),
                            _NutrientMetric(
                              label: 'Magnesium',
                              value: _knownNutrientTotal(
                                allItems,
                                TrackedNutrient.magnesium,
                                (item) => item.magnesium,
                              ),
                              unit: 'mg',
                            ),
                            _NutrientMetric(
                              label: 'Calcium',
                              value: _knownNutrientTotal(
                                allItems,
                                TrackedNutrient.calcium,
                                (item) => item.calcium,
                              ),
                              unit: 'mg',
                            ),
                            _NutrientMetric(
                              label: 'Sugar',
                              value: _knownNutrientTotal(
                                allItems,
                                TrackedNutrient.sugar,
                                (item) => item.sugar,
                              ),
                              unit: 'g',
                            ),
                          ],
                        ),
                        ...rows.expand(
                          (meal) => meal.items.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            final food = meal.foodsById[item.foodId];
                            return ListTile(
                              title: Text(
                                food?.name ??
                                    context.strings.text('Historical food'),
                              ),
                              subtitle: Text(
                                '${context.strings.text('${meal.meal.type[0].toUpperCase()}${meal.meal.type.substring(1)}')} · '
                                '${item.quantity.toStringAsFixed(0)} ${_unit(food?.servingUnit ?? 'g')}',
                              ),
                              onTap: food == null || food.deletedAt != null
                                  ? null
                                  : () => _editMealItem(item, food),
                              onLongPress: () => _showItemActions(item, food),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip:
                                        Localizations.localeOf(
                                              context,
                                            ).languageCode ==
                                            'ar'
                                        ? 'حرّك لأعلى'
                                        : 'Move up',
                                    onPressed: index == 0
                                        ? null
                                        : () => ref
                                              .read(mealRepositoryProvider)
                                              .moveMealItem(
                                                id: item.id,
                                                offset: -1,
                                              ),
                                    icon: const Icon(Icons.arrow_upward),
                                  ),
                                  IconButton(
                                    tooltip:
                                        Localizations.localeOf(
                                              context,
                                            ).languageCode ==
                                            'ar'
                                        ? 'حرّك لأسفل'
                                        : 'Move down',
                                    onPressed: index == meal.items.length - 1
                                        ? null
                                        : () => ref
                                              .read(mealRepositoryProvider)
                                              .moveMealItem(
                                                id: item.id,
                                                offset: 1,
                                              ),
                                    icon: const Icon(Icons.arrow_downward),
                                  ),
                                  IconButton(
                                    tooltip:
                                        Localizations.localeOf(
                                              context,
                                            ).languageCode ==
                                            'ar'
                                        ? 'إجراءات العنصر'
                                        : 'Item actions',
                                    icon: const Icon(Icons.more_vert),
                                    onPressed: () =>
                                        _showItemActions(item, food),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: PremiumDesignTokens.spaceLg),
                _waterSection(waterEntries),
                const SizedBox(height: PremiumDesignTokens.spaceLg),
                _bodyContextSection(),
                const SizedBox(height: PremiumDesignTokens.spaceLg),
                Semantics(
                  button: true,
                  label: context.strings.text('Save log'),
                  child: FilledButton(
                    key: const Key('daily_log_save_primary_action'),
                    onPressed: _save,
                    child: Text(context.strings.text('Save log')),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  double? _parsePositiveQuantity(String raw) {
    final value = double.tryParse(raw.replaceAll(',', '.'));
    if (value == null || value <= 0 || value > 100000) return null;
    return value;
  }

  Widget _waterSection(AsyncValue<List<WaterEntry>> waterEntries) {
    final unit = _arabic ? 'مل' : 'ml';
    return PremiumSurface(
      key: const Key('daily-log-water-section'),
      padding: PremiumDesignTokens.cardPaddingLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _tr('Water', 'الماء'),
            style: PremiumDesignTokens.cardHeading(context),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          Row(
            children: [
              Expanded(
                child: _field(
                  water,
                  _tr('Water amount (ml)', 'كمية الماء (مل)'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _addWater,
                icon: const Icon(Icons.water_drop_outlined),
                label: Text(_tr('Add water', 'إضافة ماء')),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final amount in const [250, 350, 500])
                ActionChip(
                  avatar: const Icon(Icons.water_drop_outlined, size: 18),
                  label: Text('+$amount $unit'),
                  onPressed: () => _addWater(amount),
                ),
            ],
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          waterEntries.when(
            data: (rows) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${_tr('Water total', 'إجمالي الماء')}: '
                  '${rows.fold<int>(0, (sum, row) => sum + row.amountMl)} $unit',
                ),
                for (final entry in rows)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.water_drop_outlined),
                    title: Text('${entry.amountMl} $unit'),
                    subtitle: Text(
                      '${entry.occurredAt.hour.toString().padLeft(2, '0')}:'
                      '${entry.occurredAt.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: IconButton(
                      tooltip: _tr('Remove water entry', 'حذف تسجيل الماء'),
                      onPressed: () =>
                          ref.read(waterRepositoryProvider).delete(entry.id),
                      icon: const Icon(Icons.close),
                    ),
                  ),
              ],
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => ActionableErrorState(
              title: _tr('Water data unavailable', 'بيانات الماء غير متاحة'),
              onRetry: () => ref.invalidate(dailyWaterProvider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bodyContextSection() {
    final scheme = Theme.of(context).colorScheme;
    return PremiumSurface(
      key: const Key('daily-log-body-context'),
      padding: PremiumDesignTokens.cardPaddingLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _tr('Body context', 'سياق الجسم'),
            style: PremiumDesignTokens.cardHeading(context),
          ),
          const SizedBox(height: 4),
          Text(
            _tr(
              'Select anything that may help explain today’s measurements.',
              'اختر ما قد يساعد في تفسير قياسات اليوم.',
            ),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          Wrap(
            alignment: _arabic ? WrapAlignment.end : WrapAlignment.start,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in contextOptions)
                FilterChip(
                  key: Key('body-context-$option'),
                  selected: selectedContexts.contains(option),
                  showCheckmark: true,
                  avatar: Icon(
                    _contextIcon(option),
                    size: 17,
                    color: selectedContexts.contains(option)
                        ? scheme.onPrimaryContainer
                        : scheme.primary,
                  ),
                  label: Text(_contextLabel(option)),
                  backgroundColor: Colors.white.withValues(alpha: .055),
                  selectedColor: scheme.primaryContainer.withValues(alpha: .82),
                  side: BorderSide(
                    color: selectedContexts.contains(option)
                        ? scheme.primary.withValues(alpha: .78)
                        : Colors.white.withValues(alpha: .14),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (option == 'nothingNotable' && selected) {
                        selectedContexts
                          ..clear()
                          ..add(option);
                      } else {
                        selectedContexts.remove('nothingNotable');
                        if (selected) {
                          selectedContexts.add(option);
                        } else {
                          selectedContexts.remove(option);
                        }
                      }
                      if (!selectedContexts.contains('other')) {
                        otherContext.clear();
                      }
                      _syncContextNotes();
                    });
                  },
                ),
            ],
          ),
          if (selectedContexts.contains('other')) ...[
            const SizedBox(height: PremiumDesignTokens.spaceSm),
            TextField(
              key: const Key('body-context-other-field'),
              controller: otherContext,
              maxLines: 2,
              onChanged: (_) => _syncContextNotes(),
              decoration: InputDecoration(
                labelText: _tr('Other context', 'سياق آخر'),
                hintText: _tr(
                  'Add a short optional note',
                  'أضف ملاحظة قصيرة اختيارية',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _contextIcon(String value) => switch (value) {
    'poorSleep' => Icons.bedtime_outlined,
    'greatSleep' => Icons.hotel_class_outlined,
    'travel' => Icons.flight_outlined,
    'fasting' => Icons.nights_stay_outlined,
    'highSodiumMeal' => Icons.soup_kitchen_outlined,
    'hardWorkout' => Icons.fitness_center_outlined,
    'psychologicalStress' => Icons.psychology_outlined,
    'illnessSymptoms' => Icons.sick_outlined,
    'medication' => Icons.medication_outlined,
    'lessWater' => Icons.water_drop_outlined,
    'moreWater' => Icons.water_outlined,
    'constipation' => Icons.health_and_safety_outlined,
    'nothingNotable' => Icons.check_circle_outline,
    _ => Icons.more_horiz,
  };

  Widget _field(
    TextEditingController controller,
    String label, {
    int lines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        maxLines: lines,
        keyboardType: lines == 1 ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _NutrientMetric extends StatelessWidget {
  const _NutrientMetric({
    required this.label,
    required this.value,
    required this.unit,
  });
  final String label;
  final double? value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final localizedUnit = arabic
        ? switch (unit) {
            'g' => 'جم',
            'mg' => 'مجم',
            _ => unit,
          }
        : unit;
    return Chip(
      avatar: const Icon(Icons.science_outlined, size: 17),
      label: Text(
        value == null
            ? '${context.strings.text(label)}: ${context.strings.text('Unavailable')}'
            : '${context.strings.text(label)} ${value!.toStringAsFixed(1)} $localizedUnit',
      ),
    );
  }
}

double? _knownNutrientTotal(
  List<MealItem> items,
  TrackedNutrient nutrient,
  double Function(MealItem item) valueOf,
) {
  if (items.isEmpty ||
      items.any(
        (item) =>
            !NutrientEvidenceMask.contains(item.nutrientEvidenceMask, nutrient),
      )) {
    return null;
  }
  return items.fold<double>(0, (total, item) => total + valueOf(item));
}
