import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../app/localization/app_localizations.dart';
import '../foods/providers/food_provider.dart';

class FoodPage extends ConsumerStatefulWidget {
  const FoodPage({super.key});

  @override
  ConsumerState<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends ConsumerState<FoodPage> {
  final search = TextEditingController();
  List<Food>? results;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String value) async {
    final rows = await ref.read(foodRepositoryProvider).search(value);
    if (mounted) setState(() => results = rows);
  }

  Future<void> _createFood() async {
    final created = await showDialog<_FoodDraft>(
      context: context,
      builder: (_) => const _CustomFoodDialog(),
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
        );
    await _runSearch(search.text);
  }

  @override
  Widget build(BuildContext context) {
    final allFoods = ref.watch(foodsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.text('Food catalog'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createFood,
        icon: const Icon(Icons.add),
        label: Text(context.strings.text('Custom food')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchBar(
              controller: search,
              hintText: 'English, Arabic, keyword, or barcode',
              leading: const Icon(Icons.search),
              onChanged: _runSearch,
            ),
          ),
          Expanded(
            child: allFoods.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Could not load foods: $error')),
              data: (foods) {
                final visible = results ?? foods;
                if (visible.isEmpty) {
                  return const Center(
                    child: Text('No matching foods. Create a custom food.'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: visible.length,
                  itemBuilder: (_, index) => _FoodTile(food: visible[index]),
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
  const _FoodTile({required this.food});
  final Food food;

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

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    return ListTile(
      title: Text(
        food.arabicName == null
            ? food.name
            : '${food.arabicName} • ${food.name}',
      ),
      subtitle: Text(
        '${food.calories.toStringAsFixed(0)} kcal · ${food.protein.toStringAsFixed(1)} g protein / '
        '${food.servingSize.toStringAsFixed(0)} ${food.servingUnit}',
      ),
      trailing: IconButton(
        tooltip: favorite ? 'Remove favorite' : 'Add favorite',
        icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
        onPressed: () async {
          final next = !favorite;
          await ref.read(foodRepositoryProvider).setFavorite(food.id, next);
          if (mounted) setState(() => favorite = next);
        },
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
  final double fiber;
  final double sodium;
  final double potassium;
}

class _CustomFoodDialog extends StatefulWidget {
  const _CustomFoodDialog();

  @override
  State<_CustomFoodDialog> createState() => _CustomFoodDialogState();
}

class _CustomFoodDialogState extends State<_CustomFoodDialog> {
  final formKey = GlobalKey<FormState>();
  final controllers = List.generate(11, (_) => TextEditingController());

  @override
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
    ];
    return AlertDialog(
      title: const Text('Create custom food'),
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
                  decoration: InputDecoration(labelText: labels[index]),
                  keyboardType: index >= 3 && index != 4
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.text,
                  validator: (value) {
                    if (index == 0 && (value == null || value.trim().isEmpty)) {
                      return 'Required';
                    }
                    if (index >= 3 &&
                        index != 4 &&
                        (double.tryParse(value ?? '') ?? -1) < 0) {
                      return 'Enter a non-negative number';
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            double number(int index) => double.parse(controllers[index].text);
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
                fiber: number(9),
                sodium: number(10),
                potassium: 0,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
