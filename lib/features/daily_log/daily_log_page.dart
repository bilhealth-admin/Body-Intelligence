import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/database/app_database.dart';
import '../../app/localization/app_localizations.dart';
import '../../app/theme/premium_design_tokens.dart';
import '../../shared/widgets/actionable_error_state.dart';
import '../../shared/widgets/premium_surface.dart';
import '../foods/providers/food_provider.dart';
import 'providers/daily_log_provider.dart';

class DailyLogPage extends ConsumerStatefulWidget {
  const DailyLogPage({super.key, this.initialMealType});

  final String? initialMealType;

  @override
  ConsumerState<DailyLogPage> createState() => _DailyLogPageState();
}

class _DailyLogPageState extends ConsumerState<DailyLogPage> {
  final notes = TextEditingController();
  final water = TextEditingController(text: '250');
  final quantity = TextEditingController(text: '100');
  final foodSearch = SearchController();
  Food? selectedFood;
  String mealType = 'breakfast';

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
  }

  @override
  void dispose() {
    notes.dispose();
    water.dispose();
    quantity.dispose();
    foodSearch.dispose();
    super.dispose();
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
            return ListView(
              padding: PremiumDesignTokens.screenPadding,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    context.strings.text('Record your day'),
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
                      ref.read(selectedLogDateProvider.notifier).state = picked;
                    }
                  },
                ),
                _field(
                  notes,
                  Localizations.localeOf(context).languageCode == 'ar'
                      ? 'هل هناك ما قد يفسر تغيرات جسمك اليوم؟ مثل السفر أو قلة النوم أو وجبة عالية الصوديوم أو الصيام أو الضغط'
                      : 'Anything that may explain today’s body changes? For example travel, poor sleep, a high-sodium meal, fasting, or stress',
                  lines: 4,
                ),
                Row(
                  children: [
                    Expanded(child: _field(water, 'Water (ml)')),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: _addWater,
                      icon: const Icon(Icons.water_drop_outlined),
                      label: Text(context.strings.text('Add water')),
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
                        label: Text('+$amount ml'),
                        onPressed: () => _addWater(amount),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                waterEntries.when(
                  data: (rows) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${context.strings.text('Water total')}: ${rows.fold<int>(0, (sum, row) => sum + row.amountMl)} ml',
                      ),
                      for (final entry in rows)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.water_drop_outlined),
                          title: Text('${entry.amountMl} ml'),
                          subtitle: Text(
                            '${entry.occurredAt.hour.toString().padLeft(2, '0')}:${entry.occurredAt.minute.toString().padLeft(2, '0')}',
                          ),
                          trailing: IconButton(
                            tooltip: context.strings.text('Remove water entry'),
                            onPressed: () => ref
                                .read(waterRepositoryProvider)
                                .delete(entry.id),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                    ],
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => ActionableErrorState(
                    title: context.strings.text('Water data unavailable'),
                    onRetry: () => ref.invalidate(dailyWaterProvider),
                  ),
                ),
                const SizedBox(height: PremiumDesignTokens.spaceLg),
                PremiumSurface(
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
                        error: (_, __) => ActionableErrorState(
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
                                food.arabicName == null
                                    ? food.name
                                    : '${food.arabicName} • ${food.name}',
                              ),
                              subtitle: Text(
                                '${food.calories.toStringAsFixed(0)} kcal / ${food.servingSize.toStringAsFixed(0)} ${food.servingUnit} · ${food.source}',
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
                          title: Text(selectedFood!.name),
                          subtitle: Text(
                            '${selectedFood!.source} · ${context.strings.text(selectedFood!.verified ? 'Verified' : 'Unverified')}',
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
                              '${context.strings.text('Quantity')} (${selectedFood?.servingUnit ?? 'g'})',
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
                  error: (_, __) => ActionableErrorState(
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
                            '${allItems.fold<double>(0, (sum, item) => sum + item.calories).toStringAsFixed(0)} kcal · '
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
                              value: allItems.fold<double>(
                                0,
                                (sum, item) => sum + item.fiber,
                              ),
                              unit: 'g',
                            ),
                            _NutrientMetric(
                              label: 'Sodium',
                              value: allItems.fold<double>(
                                0,
                                (sum, item) => sum + item.sodium,
                              ),
                              unit: 'mg',
                            ),
                            _NutrientMetric(
                              label: 'Potassium',
                              value: allItems.fold<double>(
                                0,
                                (sum, item) => sum + item.potassium,
                              ),
                              unit: 'mg',
                            ),
                            _NutrientMetric(
                              label: 'Magnesium',
                              value: allItems.fold<double>(
                                0,
                                (sum, item) => sum + item.magnesium,
                              ),
                              unit: 'mg',
                            ),
                            _NutrientMetric(
                              label: 'Calcium',
                              value: allItems.fold<double>(
                                0,
                                (sum, item) => sum + item.calcium,
                              ),
                              unit: 'mg',
                            ),
                            _NutrientMetric(
                              label: 'Sugar',
                              value: allItems.fold<double>(
                                0,
                                (sum, item) => sum + item.sugar,
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
                                '${context.strings.text('${meal.meal.type[0].toUpperCase()}${meal.meal.type.substring(1)}')} · ${item.quantity.toStringAsFixed(0)} ${food?.servingUnit ?? 'g'}',
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
  final double value;
  final String unit;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: const Icon(Icons.science_outlined, size: 17),
    label: Text(
      '${context.strings.text(label)} ${value.toStringAsFixed(1)} $unit',
    ),
  );
}
