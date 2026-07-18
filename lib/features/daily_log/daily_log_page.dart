import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/database/app_database.dart';
import '../../app/localization/app_localizations.dart';
import '../../engine/nutrition_engine.dart';
import '../foods/providers/food_provider.dart';
import 'providers/daily_log_provider.dart';

class DailyLogPage extends ConsumerStatefulWidget {
  const DailyLogPage({super.key});

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

    final quantityValue = double.tryParse(quantity.text) ?? 100;
    final portion = NutritionEngine.calculateFoodPortion(
      quantity: quantityValue,
      servingSize: selectedFood!.servingSize,
      calories: selectedFood!.calories,
      protein: selectedFood!.protein,
      carbs: selectedFood!.carbs,
      fats: selectedFood!.fats,
    );

    await mealRepository.addMealItem(
      mealId: mealId,
      foodId: selectedFood!.id,
      quantity: quantityValue,
      calories: portion.calories,
      protein: portion.protein,
      carbs: portion.carbs,
      fats: portion.fats,
      fiber: selectedFood!.fiber * quantityValue / selectedFood!.servingSize,
      sodium: selectedFood!.sodium * quantityValue / selectedFood!.servingSize,
      potassium:
          selectedFood!.potassium * quantityValue / selectedFood!.servingSize,
      calcium:
          selectedFood!.calcium * quantityValue / selectedFood!.servingSize,
      magnesium:
          selectedFood!.magnesium * quantityValue / selectedFood!.servingSize,
      sugar: selectedFood!.sugar * quantityValue / selectedFood!.servingSize,
    );
    await ref.read(foodRepositoryProvider).recordRecent(selectedFood!.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.strings.text('Meal saved locally.'))),
    );
  }

  Future<void> _addWater([int? quickAmount]) async {
    final amount = quickAmount ?? int.tryParse(water.text);
    if (amount == null) return;
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

  Future<void> _editMealItem(MealItem item, Food food) async {
    final controller = TextEditingController(text: item.quantity.toString());
    final updated = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: Text(context.strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text)),
            child: Text(context.strings.text('Update')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (updated == null || updated <= 0) return;
    final factor = updated / food.servingSize;
    await ref
        .read(mealRepositoryProvider)
        .updateMealItem(
          id: item.id,
          quantity: updated,
          calories: food.calories * factor,
          protein: food.protein * factor,
          carbs: food.carbs * factor,
          fats: food.fats * factor,
          fiber: food.fiber * factor,
          sodium: food.sodium * factor,
          potassium: food.potassium * factor,
          calcium: food.calcium * factor,
          magnesium: food.magnesium * factor,
          sugar: food.sugar * factor,
        );
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
      body: foods.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (items) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                  FilledButton(
                    onPressed: _addWater,
                    child: Text(context.strings.text('Add water')),
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
                data: (rows) => Text(
                  '${context.strings.text('Water total')}: ${rows.fold<int>(0, (sum, row) => sum + row.amountMl)} ml',
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) =>
                    Text(context.strings.text('Water data unavailable')),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          context.strings.text('Meal type'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                        error: (_, _) => const SizedBox.shrink(),
                        data: (candidates) {
                          if (candidates.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 12),
                              Text(
                                Localizations.localeOf(context).languageCode ==
                                        'ar'
                                    ? 'وجباتك المعتادة — لن تتم الإضافة دون تأكيدك'
                                    : 'Your usual meals — nothing is added without your confirmation',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 6),
                              for (final candidate in candidates)
                                Card.outlined(
                                  child: ListTile(
                                    leading: const Icon(Icons.replay_outlined),
                                    title: Text(
                                      candidate.source.items
                                          .map(
                                            (item) => items
                                                .where(
                                                  (food) =>
                                                      food.id == item.foodId,
                                                )
                                                .map((food) => food.name)
                                                .firstOrNull,
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
                      const SizedBox(height: 12),
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
                            '${selectedFood!.source} · ${selectedFood!.verified ? 'verified' : 'unverified'}',
                          ),
                          trailing: IconButton(
                            onPressed: () =>
                                setState(() => selectedFood = null),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: quantity,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '${context.strings.text('Quantity')} (g)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _saveMeal,
                        child: Text(context.strings.text('Save meal')),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              meals.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) =>
                    Text(context.strings.text('Meals unavailable')),
                data: (rows) {
                  if (rows.isEmpty) {
                    return Text(context.strings.text('No meals for this day.'));
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
                        (meal) => meal.items.map((item) {
                          final food = items
                              .where((row) => row.id == item.foodId)
                              .firstOrNull;
                          return ListTile(
                            title: Text(food?.name ?? 'Food'),
                            subtitle: Text(
                              '${meal.meal.type} · ${item.quantity.toStringAsFixed(0)} ${food?.servingUnit ?? 'g'}',
                            ),
                            onTap: food == null
                                ? null
                                : () => _editMealItem(item, food),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => ref
                                  .read(mealRepositoryProvider)
                                  .deleteMealItem(item.id),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _save,
                child: Text(context.strings.text('Save log')),
              ),
            ],
          );
        },
      ),
    );
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
