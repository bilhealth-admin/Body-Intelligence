import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/database/app_database.dart';
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
  final mealName = TextEditingController(text: 'Breakfast');
  final quantity = TextEditingController(text: '100');
  Food? selectedFood;

  @override
  void dispose() {
    notes.dispose();
    mealName.dispose();
    quantity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repository = ref.read(dailyLogRepositoryProvider);
    await repository.save(
      date: DateTime.now(),
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
    final mealId = await mealRepository.createMeal(
      date: DateTime.now(),
      name: mealName.text.trim().isEmpty ? 'Meal' : mealName.text.trim(),
      type: 'meal',
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
    );

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Meal saved locally.')));
  }

  @override
  Widget build(BuildContext context) {
    final foods = ref.watch(foodsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Log')),
      body: foods.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (items) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _field(notes, 'Notes', lines: 4),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: mealName,
                        decoration: const InputDecoration(
                          labelText: 'Meal name',
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<Food>(
                        initialValue: selectedFood,
                        decoration: const InputDecoration(labelText: 'Food'),
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
                        child: const Text('Save meal'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _save, child: const Text('Save log')),
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
