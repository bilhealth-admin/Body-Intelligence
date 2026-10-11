import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/meal_repository.dart';
import '../../foods/providers/food_provider.dart';
import '../../recipe_import/domain/trusted_recipe.dart';
import '../../recipe_import/providers/trusted_recipe_providers.dart';
import '../../recipe_import/repositories/trusted_recipe_repository.dart';
import '../../recipe_import/services/trusted_recipe_diary_service.dart';
import 'nutrition_entry_fields.dart';

/// Choosing a recipe never logs it. The member explicitly chooses the number
/// of servings, destination day, meal, and confirms a single atomic write.
class RecipeDiaryConfirmationPage extends ConsumerStatefulWidget {
  const RecipeDiaryConfirmationPage({
    required this.saved,
    required this.initialDate,
    required this.initialMealType,
    super.key,
  });
  final SavedTrustedRecipe saved;
  final DateTime initialDate;
  final String initialMealType;
  @override
  ConsumerState<RecipeDiaryConfirmationPage> createState() =>
      _RecipeDiaryConfirmationPageState();
}

class _RecipeDiaryConfirmationPageState
    extends ConsumerState<RecipeDiaryConfirmationPage> {
  final _servings = TextEditingController(text: '1');
  late DateTime _date;
  late String _type;
  late MealRepository _meals;
  late TrustedRecipeRepository _recipes;
  bool _saving = false, _retired = false;
  String? _error;
  String t(String en, String ar) => nutritionEntryText(context, en, ar);
  bool get _current =>
      mounted &&
      !_retired &&
      identical(_meals, ref.read(mealRepositoryProvider)) &&
      identical(_recipes, ref.read(trustedRecipeRepositoryProvider));
  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    _type = widget.initialMealType;
    _meals = ref.read(mealRepositoryProvider);
    _recipes = ref.read(trustedRecipeRepositoryProvider);
  }

  @override
  void dispose() {
    _servings.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_current || _saving) return;
    final servings = parseNutritionNumber(_servings.text);
    if (servings == null || servings <= 0 || servings > 100) {
      setState(
        () => _error = t(
          'Enter a positive number of servings, up to 100.',
          'أدخل عدد حصص موجبًا لا يتجاوز 100.',
        ),
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final rows = await _recipes.load();
      if (!_current) return;
      final current = rows
          .where((row) => row.id == widget.saved.id)
          .firstOrNull;
      if (current == null ||
          jsonEncode(current.recipe.toJson()) !=
              jsonEncode(widget.saved.recipe.toJson())) {
        throw StateError('Recipe changed. Reopen the current saved recipe.');
      }
      await TrustedRecipeDiaryService(
        ref.read(foodRepositoryProvider),
        _meals,
      ).addServing(
        saved: current,
        date: _date,
        mealType: _type,
        servings: servings,
      );
      if (mounted && _current) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${t('Recipe added to', 'أُضيفت الوصفة إلى')} ${MaterialLocalizations.of(context).formatMediumDate(_date)} · ${nutritionMealType(context, _type)}',
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } on Object {
      if (_current) {
        setState(
          () => _error = t(
            'Could not log the recipe. Check that the saved recipe is current and has nutrition, and that the destination day is open. Your choices remain here.',
            'تعذر تسجيل الوصفة. تأكد من أن الوصفة المحفوظة لم تتغير ولها قيم، وأن يوم التسجيل مفتوح. اختياراتك باقية هنا.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(mealRepositoryProvider, (previous, next) {
      _retired = true;
      if (mounted) {
        setState(
          () => _error = t(
            'Account changed. Reopen the recipe.',
            'تغيّر الحساب. أعد فتح الوصفة.',
          ),
        );
      }
    });
    final nutrition = widget.saved.recipe.nutrition;
    final servings = parseNutritionNumber(_servings.text);
    final valid =
        nutrition != null &&
        servings != null &&
        servings > 0 &&
        servings <= 100;
    final enabled = !_saving && !_retired;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: Text(t('Log recipe', 'تسجيل الوصفة'))),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.saved.recipe.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              t(
                'Nutrition below is for the selected servings, not the entire recipe. Review the destination before confirming.',
                'القيم التالية للحصص المختارة، وليست لكل الوصفة. راجع وجهة التسجيل قبل التأكيد.',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _servings,
              enabled: enabled,
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: t('Number of servings', 'عدد الحصص'),
              ),
            ),
            if (valid)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        '${(nutrition.caloriesKcal * servings).toStringAsFixed(1)} ${t('kcal', 'سعرة')}',
                      ),
                      Text(
                        '${t('Protein', 'بروتين')}: ${(nutrition.proteinG * servings).toStringAsFixed(1)} ${t('g', 'جم')}',
                      ),
                      Text(
                        '${t('Carbohydrates', 'كربوهيدرات')}: ${(nutrition.carbohydrateG * servings).toStringAsFixed(1)} ${t('g', 'جم')}',
                      ),
                      Text(
                        '${t('Fat', 'دهون')}: ${(nutrition.fatG * servings).toStringAsFixed(1)} ${t('g', 'جم')}',
                      ),
                      if (nutrition.fiberG != null)
                        Text(
                          '${t('Fiber', 'ألياف')}: ${(nutrition.fiberG! * servings).toStringAsFixed(1)} ${t('g', 'جم')}',
                        ),
                    ],
                  ),
                ),
              ),
            nutritionDestinationFields(
              context,
              date: _date,
              type: _type,
              enabled: enabled,
              onDate: (date) {
                if (mounted) setState(() => _date = date);
              },
              onType: (type) => setState(() => _type = type),
            ),
            const SizedBox(height: 16),
            Text(
              t(
                'Existing diary food is kept. Saving this recipe again later intentionally adds another portion.',
                'تبقى أطعمة اليوميات القائمة. تسجيل الوصفة لاحقًا مرة أخرى يضيف حصة أخرى عمدًا.',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton.icon(
              key: const Key('confirm-recipe-diary-serving'),
              onPressed: enabled && valid ? _save : null,
              icon: const Icon(Icons.check),
              label: Text(
                _saving
                    ? t('Saving…', 'جارٍ الحفظ…')
                    : t('Confirm and log', 'تأكيد التسجيل'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
