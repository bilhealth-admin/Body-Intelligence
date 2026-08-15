import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/nutrient_evidence.dart';
import '../../../data/repositories/meal_repository.dart';
import '../../../data/repositories/nutrition_goal_schedule_repository.dart';
import '../../../shared/widgets/actionable_error_state.dart';
import '../providers/daily_log_provider.dart';
import '../../settings/premium_meal_features_page.dart';
import 'daily_log_summary_widgets.dart';
import 'meal_item_evidence_presenter.dart';

class DailyMealsList extends ConsumerWidget {
  const DailyMealsList({
    super.key,
    required this.arabic,
    required this.meals,
    this.showEmptyMealSlots = true,
    this.showFoodInsights = true,
    this.showFoodTimestamps = false,
    this.useNetCarbs = false,
    this.dailyGoal,
    this.mealGoals = const {},
    this.mealCalorieGoals = const {},
    this.mealMacroDisplay,
    required this.onAdd,
    required this.onEdit,
    required this.onActions,
  });

  final bool arabic;
  final AsyncValue<List<MealWithItems>> meals;
  final bool showEmptyMealSlots;
  final bool showFoodInsights;
  final bool showFoodTimestamps;
  final bool useNetCarbs;
  final NutritionGoalTarget? dailyGoal;
  final Map<String, NutritionGoalTarget> mealGoals;
  final Map<String, double> mealCalorieGoals;
  final MealMacroDisplay? mealMacroDisplay;
  final ValueChanged<String> onAdd;
  final Future<void> Function(MealItem item, Food food) onEdit;
  final Future<void> Function(MealItem item, Food? food) onActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealNames = ref.watch(diaryMealNamesProvider);
    if (mealNames.isLoading) {
      return const LinearProgressIndicator();
    }
    if (mealNames.hasError) {
      return ActionableErrorState(
        title: context.strings.text('Meal names could not be loaded.'),
        onRetry: () => ref.invalidate(diaryMealNamesProvider),
      );
    }
    return meals.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => ActionableErrorState(
        title: context.strings.text('Meals unavailable'),
        onRetry: () => ref.invalidate(dailyMealsProvider),
      ),
      data: (rows) {
        final configuredNames = mealNames.value;
        const mealIndexes = {
          'breakfast': 0,
          'lunch': 1,
          'dinner': 2,
          'snack': 3,
        };
        final namedRows = rows.where((meal) {
          final index = mealIndexes[meal.meal.type];
          // Never conceal existing diary data. An explicitly blank label only
          // hides its empty slot.
          return meal.items.isNotEmpty ||
              index == null ||
              configuredNames == null ||
              configuredNames[index] == null ||
              configuredNames[index]!.isNotEmpty;
        }).toList();
        final visibleRows = showEmptyMealSlots
            ? namedRows
            : namedRows.where((meal) => meal.items.isNotEmpty).toList();
        if (visibleRows.isEmpty) {
          return Text(context.strings.text('No meals for this day.'));
        }
        final allItems = visibleRows.expand((meal) => meal.items).toList();
        final netCarbohydrates = knownNetCarbohydrateTotal(allItems);
        final carbohydrateValue = useNetCarbs
            ? netCarbohydrates?.toStringAsFixed(1) ??
                  context.strings.text('Unavailable')
            : allItems
                  .fold<double>(0, (sum, item) => sum + item.carbs)
                  .toStringAsFixed(1);
        final carbohydrateLabel = useNetCarbs ? 'netCarbs' : 'carbs';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showFoodInsights)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  minTileHeight: 76,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Icon(
                    Icons.donut_large_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(context.strings.text('Calculated nutrition')),
                  subtitle: Text(
                    '${allItems.fold<double>(0, (sum, item) => sum + item.calories).toStringAsFixed(0)} ${_mealListText(context, 'kcal')} · '
                    '${allItems.fold<double>(0, (sum, item) => sum + item.protein).toStringAsFixed(1)} ${_mealListText(context, 'protein')} · '
                    '$carbohydrateValue ${_mealListText(context, carbohydrateLabel)} · '
                    '${allItems.fold<double>(0, (sum, item) => sum + item.fats).toStringAsFixed(1)} ${_mealListText(context, 'fat')}'
                    '${dailyGoal == null ? '' : ' · ${_mealListText(context, 'dailyGoal')} ${dailyGoal!.calories.toStringAsFixed(0)} ${_mealListText(context, 'kcal')}'}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            if (showFoodInsights)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  NutrientMetric(
                    label: _mealListText(context, 'fiber'),
                    value: knownNutrientTotal(
                      allItems,
                      TrackedNutrient.fiber,
                      (item) => item.fiber,
                    ),
                    unit: 'g',
                  ),
                  NutrientMetric(
                    label: _mealListText(context, 'sodium'),
                    value: knownNutrientTotal(
                      allItems,
                      TrackedNutrient.sodium,
                      (item) => item.sodium,
                    ),
                    unit: 'mg',
                  ),
                  NutrientMetric(
                    label: _mealListText(context, 'potassium'),
                    value: knownNutrientTotal(
                      allItems,
                      TrackedNutrient.potassium,
                      (item) => item.potassium,
                    ),
                    unit: 'mg',
                  ),
                  NutrientMetric(
                    label: _mealListText(context, 'magnesium'),
                    value: knownNutrientTotal(
                      allItems,
                      TrackedNutrient.magnesium,
                      (item) => item.magnesium,
                    ),
                    unit: 'mg',
                  ),
                  NutrientMetric(
                    label: _mealListText(context, 'calcium'),
                    value: knownNutrientTotal(
                      allItems,
                      TrackedNutrient.calcium,
                      (item) => item.calcium,
                    ),
                    unit: 'mg',
                  ),
                  NutrientMetric(
                    label: _mealListText(context, 'sugar'),
                    value: knownNutrientTotal(
                      allItems,
                      TrackedNutrient.sugar,
                      (item) => item.sugar,
                    ),
                    unit: 'g',
                  ),
                ],
              ),
            ...visibleRows.map(
              (meal) => Card(
                margin: const EdgeInsets.only(top: 10),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Builder(
                      builder: (context) {
                        final calorieGoal = mealCalorieGoals[meal.meal.type];
                        final macroCopy = _macroSummary(meal.items);
                        final details = <String>[
                          if (calorieGoal != null)
                            '${_mealListText(context, 'mealGoal')} ${calorieGoal.toStringAsFixed(0)} ${_mealListText(context, 'kcal')}',
                          if (mealMacroDisplay?.enabled == true)
                            mealMacroDisplay!.mode == MealMacroDisplayMode.grams
                                ? '${macroCopy.protein.toStringAsFixed(1)} g P · ${macroCopy.carbs.toStringAsFixed(1)} g C · ${macroCopy.fat.toStringAsFixed(1)} g F'
                                : '${macroCopy.proteinPercent.toStringAsFixed(0)}% P · ${macroCopy.carbsPercent.toStringAsFixed(0)}% C · ${macroCopy.fatPercent.toStringAsFixed(0)}% F',
                        ];
                        return ListTile(
                          leading: Icon(
                            switch (meal.meal.type) {
                              'breakfast' => Icons.wb_sunny_rounded,
                              'lunch' => Icons.restaurant_rounded,
                              'dinner' => Icons.nights_stay_rounded,
                              _ => Icons.cookie_rounded,
                            },
                            color: switch (meal.meal.type) {
                              'breakfast' => const Color(0xFFF59E0B),
                              'lunch' => const Color(0xFF10B981),
                              'dinner' => const Color(0xFF7C3AED),
                              _ => const Color(0xFFEC4899),
                            },
                          ),
                          title: Text(
                            _resolvedMealName(
                              context,
                              mealNames,
                              meal.meal.type,
                            ),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          subtitle: details.isEmpty
                              ? null
                              : Text(details.join(' · ')),
                          trailing: TextButton.icon(
                            onPressed: () => onAdd(meal.meal.type),
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            label: Text(_mealListText(context, 'addFood')),
                          ),
                        );
                      },
                    ),
                    if (meal.items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            _mealListText(context, 'emptyMeal'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ),
                    ...meal.items.asMap().entries.map((entry) {
                      final item = entry.value;
                      final food = meal.foodsById[item.foodId];
                      final mealGoal = mealGoals[meal.meal.type];
                      return Column(
                        children: [
                          const Divider(height: 1),
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.restaurant_menu_rounded),
                            ),
                            title: Text(
                              Localizations.localeOf(context).languageCode ==
                                          'ar' &&
                                      food?.arabicName != null
                                  ? food!.arabicName!
                                  : food?.name ??
                                        context.strings.text('Historical food'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              [
                                MealItemEvidencePresenter.subtitle(
                                  item: item,
                                  mealLabel: _resolvedMealName(
                                    context,
                                    mealNames,
                                    meal.meal.type,
                                  ),
                                  languageCode: Localizations.localeOf(
                                    context,
                                  ).languageCode,
                                ),
                                if (showFoodTimestamps)
                                  '${_mealListText(context, 'loggedAt')} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(item.createdAt.toLocal()))}',
                                if (mealGoal != null)
                                  '${_mealListText(context, 'mealGoal')} ${mealGoal.calories.toStringAsFixed(0)} ${_mealListText(context, 'kcal')} · ${mealGoal.carbsPercent.toStringAsFixed(0)}% C · ${mealGoal.proteinPercent.toStringAsFixed(0)}% P · ${mealGoal.fatPercent.toStringAsFixed(0)}% F',
                              ].join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: food == null || food.deletedAt != null
                                ? null
                                : () => onEdit(item, food),
                            onLongPress: () => onActions(item, food),
                            trailing: IconButton(
                              tooltip: _mealListText(context, 'itemActions'),
                              icon: const Icon(Icons.more_horiz_rounded),
                              onPressed: () => onActions(item, food),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _resolvedMealName(
    BuildContext context,
    AsyncValue<List<String?>> names,
    String type,
  ) {
    const index = {'breakfast': 0, 'lunch': 1, 'dinner': 2, 'snack': 3};
    final i = index[type];
    final resolved = names.value;
    if (i != null && resolved != null && resolved[i]?.isNotEmpty == true) {
      return resolved[i]!;
    }
    return context.strings.text('${type[0].toUpperCase()}${type.substring(1)}');
  }
}

({
  double protein,
  double carbs,
  double fat,
  double proteinPercent,
  double carbsPercent,
  double fatPercent,
})
_macroSummary(List<MealItem> items) {
  final protein = items.fold<double>(0, (sum, item) => sum + item.protein);
  final carbs = items.fold<double>(0, (sum, item) => sum + item.carbs);
  final fat = items.fold<double>(0, (sum, item) => sum + item.fats);
  final energy = protein * 4 + carbs * 4 + fat * 9;
  return (
    protein: protein,
    carbs: carbs,
    fat: fat,
    proteinPercent: energy > 0 ? protein * 400 / energy : 0,
    carbsPercent: energy > 0 ? carbs * 400 / energy : 0,
    fatPercent: energy > 0 ? fat * 900 / energy : 0,
  );
}

String _mealListText(BuildContext context, String key) {
  final locale = Localizations.localeOf(context).languageCode.toLowerCase();
  return _mealListCopy[locale]?[key] ??
      context.strings.text(_mealListCopy['en']![key]!);
}

const _mealListCopy = <String, Map<String, String>>{
  'en': {
    'kcal': 'kcal',
    'protein': 'g protein',
    'carbs': 'g carbs',
    'netCarbs': 'g net carbs',
    'loggedAt': 'Logged at',
    'dailyGoal': 'Daily goal',
    'mealGoal': 'Meal goal',
    'fat': 'g fat',
    'fiber': 'Fiber',
    'sodium': 'Sodium',
    'potassium': 'Potassium',
    'magnesium': 'Magnesium',
    'calcium': 'Calcium',
    'sugar': 'Sugar',
    'moveUp': 'Move up',
    'moveDown': 'Move down',
    'itemActions': 'Item actions',
    'addFood': 'Add food',
    'emptyMeal': 'No food logged yet',
  },
  'ar': {
    'kcal': 'سعرة',
    'protein': 'جم بروتين',
    'carbs': 'جم كربوهيدرات',
    'netCarbs': 'غ صافي كربوهيدرات',
    'loggedAt': 'سُجّل في',
    'dailyGoal': 'هدف اليوم',
    'mealGoal': 'هدف الوجبة',
    'fat': 'جم دهون',
    'fiber': 'الألياف',
    'sodium': 'الصوديوم',
    'potassium': 'البوتاسيوم',
    'magnesium': 'المغنيسيوم',
    'calcium': 'الكالسيوم',
    'sugar': 'السكريات',
    'moveUp': 'حرّك لأعلى',
    'moveDown': 'حرّك لأسفل',
    'itemActions': 'إجراءات العنصر',
    'addFood': 'إضافة طعام',
    'emptyMeal': 'لم يُسجّل طعام بعد',
  },
  'fr': {
    'kcal': 'kcal',
    'protein': 'g protéines',
    'carbs': 'g glucides',
    'netCarbs': 'g glucides nets',
    'loggedAt': 'Enregistré à',
    'dailyGoal': 'Objectif du jour',
    'mealGoal': 'Objectif du repas',
    'fat': 'g lipides',
    'fiber': 'Fibres',
    'sodium': 'Sodium',
    'potassium': 'Potassium',
    'magnesium': 'Magnésium',
    'calcium': 'Calcium',
    'sugar': 'Sucres',
    'moveUp': 'Déplacer vers le haut',
    'moveDown': 'Déplacer vers le bas',
    'itemActions': 'Actions sur l’élément',
    'addFood': 'Ajouter',
    'emptyMeal': 'Aucun aliment enregistré',
  },
  'es': {
    'kcal': 'kcal',
    'protein': 'g proteína',
    'carbs': 'g carbohidratos',
    'netCarbs': 'g carbohidratos netos',
    'loggedAt': 'Registrado a las',
    'dailyGoal': 'Objetivo diario',
    'mealGoal': 'Objetivo de la comida',
    'fat': 'g grasa',
    'fiber': 'Fibra',
    'sodium': 'Sodio',
    'potassium': 'Potasio',
    'magnesium': 'Magnesio',
    'calcium': 'Calcio',
    'sugar': 'Azúcar',
    'moveUp': 'Mover arriba',
    'moveDown': 'Mover abajo',
    'itemActions': 'Acciones del elemento',
    'addFood': 'Añadir',
    'emptyMeal': 'Aún no hay alimentos',
  },
  'tr': {
    'kcal': 'kcal',
    'protein': 'g protein',
    'carbs': 'g karbonhidrat',
    'netCarbs': 'g net karbonhidrat',
    'loggedAt': 'Kayıt saati',
    'dailyGoal': 'Günlük hedef',
    'mealGoal': 'Öğün hedefi',
    'fat': 'g yağ',
    'fiber': 'Lif',
    'sodium': 'Sodyum',
    'potassium': 'Potasyum',
    'magnesium': 'Magnezyum',
    'calcium': 'Kalsiyum',
    'sugar': 'Şeker',
    'moveUp': 'Yukarı taşı',
    'moveDown': 'Aşağı taşı',
    'itemActions': 'Öğe işlemleri',
    'addFood': 'Ekle',
    'emptyMeal': 'Henüz yiyecek yok',
  },
};

/// Returns a net-carbohydrate total only when every row carries explicit
/// fibre evidence. Missing fibre is unknown data, not an assumed zero.
double? knownNetCarbohydrateTotal(Iterable<MealItem> items) {
  final rows = items.toList(growable: false);
  if (rows.isEmpty ||
      rows.any(
        (item) => !NutrientEvidenceMask.contains(
          item.nutrientEvidenceMask,
          TrackedNutrient.fiber,
        ),
      )) {
    return null;
  }
  return rows.fold<double>(
    0,
    (total, item) =>
        total + (item.carbs - item.fiber).clamp(0, double.infinity).toDouble(),
  );
}
