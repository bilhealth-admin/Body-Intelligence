import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/database/app_database.dart';
import '../../app/localization/app_localizations.dart';
import '../../core/units/measurement_units.dart';
import '../../engine/nutrition_engine.dart';
import '../../shared/widgets/wheel_number_field.dart';
import '../foods/providers/food_provider.dart';
import '../profile/providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';
import 'providers/daily_log_provider.dart';

class DailyLogPage extends ConsumerStatefulWidget {
  const DailyLogPage({super.key});

  @override
  ConsumerState<DailyLogPage> createState() => _DailyLogPageState();
}

class _DailyLogPageState extends ConsumerState<DailyLogPage> {
  final notes = TextEditingController();
  double weightKg = 60;
  final water = TextEditingController(text: '250');
  final quantity = TextEditingController(text: '100');
  Food? selectedFood;
  String mealType = 'breakfast';

  @override
  void dispose() {
    notes.dispose();
    water.dispose();
    quantity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final date = ref.read(selectedLogDateProvider);
    final repository = ref.read(dailyLogRepositoryProvider);
    await repository.save(
      date: date,
      notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
    );
    await ref.read(weightRepositoryProvider).addWeight(weightKg, date: date);

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
    );
    await ref.read(foodRepositoryProvider).recordRecent(selectedFood!.id);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Meal saved locally.')));
  }

  Future<void> _addWater() async {
    final amount = int.tryParse(water.text);
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
        title: Text('Edit ${food.name}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Quantity (${food.servingUnit})',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text)),
            child: const Text('Update'),
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
        );
  }

  @override
  Widget build(BuildContext context) {
    final foods = ref.watch(foodsProvider);
    final date = ref.watch(selectedLogDateProvider);
    final meals = ref.watch(dailyMealsProvider);
    final waterEntries = ref.watch(dailyWaterProvider);
    final system =
        ref.watch(measurementSystemProvider).value ?? MeasurementSystem.metric;
    ref.listen(selectedDailyLogProvider, (_, next) {
      next.whenData((log) {
        final value = log?.notes ?? '';
        if (notes.text != value) notes.text = value;
      });
    });

    return Scaffold(
      appBar: AppBar(title: Text(context.strings.text('Daily Log'))),
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
              WheelNumberField(
                key: ValueKey(system),
                label: context.strings.text('Weight'),
                unit: UnitConverter.weightUnit(system),
                value: system == MeasurementSystem.metric
                    ? weightKg
                    : UnitConverter.weightFromKg(weightKg, system),
                minimum: UnitConverter.weightFromKg(20, system),
                maximum: UnitConverter.weightFromKg(350, system),
                step: system == MeasurementSystem.metric ? 0.1 : 0.2,
                decimalPlaces: 1,
                onChanged: (value) => setState(() {
                  weightKg = UnitConverter.weightToKg(value, system);
                }),
              ),
              const SizedBox(height: 14),
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
              waterEntries.when(
                data: (rows) => Text(
                  'Water total: ${rows.fold<int>(0, (sum, row) => sum + row.amountMl)} ml',
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('Water data unavailable'),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: mealType,
                        decoration: InputDecoration(
                          labelText: context.strings.text('Meal type'),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'breakfast',
                            child: Text(context.strings.text('Breakfast')),
                          ),
                          DropdownMenuItem(
                            value: 'lunch',
                            child: Text(context.strings.text('Lunch')),
                          ),
                          DropdownMenuItem(
                            value: 'dinner',
                            child: Text(context.strings.text('Dinner')),
                          ),
                          DropdownMenuItem(
                            value: 'snack',
                            child: Text(context.strings.text('Snack')),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => mealType = value ?? 'breakfast'),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<Food>(
                        initialValue: selectedFood,
                        decoration: InputDecoration(
                          labelText: context.strings.text('Food'),
                        ),
                        items: items
                            .map(
                              (food) => DropdownMenuItem<Food>(
                                value: food,
                                child: Text(food.name),
                              ),
                            )
                            .toList(),
                        onChanged: (food) =>
                            setState(() => selectedFood = food),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: quantity,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity (g)',
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
                error: (_, _) => const Text('Meals unavailable'),
                data: (rows) {
                  if (rows.isEmpty) return const Text('No meals for this day.');
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
