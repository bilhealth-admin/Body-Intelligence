import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/nutrient_evidence.dart';
import '../../../data/repositories/meal_repository.dart';
import '../../../data/repositories/nutrition_goal_schedule_repository.dart';
import '../../../shared/widgets/actionable_error_state.dart';
import '../../settings/premium_meal_features_page.dart';
import '../../nutrition/services/food_presentation_localizer.dart';
import '../../commerce/presentation/premium_nutrition_glass.dart';
import '../providers/daily_log_provider.dart';
import 'macro_value_formatter.dart';

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
    if (mealNames.isLoading) return const LinearProgressIndicator();
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
        const indexes = {'breakfast': 0, 'lunch': 1, 'dinner': 2, 'snack': 3};
        final byType = <String, MealWithItems>{
          for (final meal in rows) meal.meal.type: meal,
        };
        final slots = <({String type, MealWithItems? meal})>[
          for (final entry in indexes.entries)
            if (() {
              final meal = byType[entry.key];
              final configuredName = configuredNames?[entry.value];
              final enabled =
                  configuredNames == null ||
                  configuredName == null ||
                  configuredName.isNotEmpty;
              return (meal?.items.isNotEmpty ?? false) ||
                  (showEmptyMealSlots && enabled);
            }())
              (type: entry.key, meal: byType[entry.key]),
          for (final meal in rows)
            if (!indexes.containsKey(meal.meal.type))
              (type: meal.meal.type, meal: meal),
        ];
        if (slots.isEmpty) {
          return _DiaryEmptyMeals(onAdd: () => onAdd('breakfast'));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final slot in slots) ...[
              _CompactDiaryMealCard(
                key: Key('daily-meal-card-${slot.type}'),
                type: slot.type,
                title: _resolvedMealName(context, mealNames, slot.type),
                meal: slot.meal,
                calorieGoal: mealCalorieGoals[slot.type],
                onAdd: () => onAdd(slot.type),
              ),
              const SizedBox(height: 12),
            ],
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
    final resolvedIndex = index[type];
    final resolved = names.value;
    if (resolvedIndex != null &&
        resolved != null &&
        resolved[resolvedIndex]?.isNotEmpty == true) {
      return resolved[resolvedIndex]!;
    }
    return context.strings.text('${type[0].toUpperCase()}${type.substring(1)}');
  }
}

class _CompactDiaryMealCard extends StatelessWidget {
  const _CompactDiaryMealCard({
    super.key,
    required this.type,
    required this.title,
    required this.meal,
    required this.calorieGoal,
    required this.onAdd,
  });

  final String type;
  final String title;
  final MealWithItems? meal;
  final double? calorieGoal;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = meal?.items ?? const <MealItem>[];
    final calories = items.fold<double>(0, (sum, item) => sum + item.calories);
    final icon = switch (type) {
      'breakfast' => Icons.wb_sunny_outlined,
      'lunch' => Icons.restaurant_outlined,
      'dinner' => Icons.nights_stay_outlined,
      _ => Icons.cookie_outlined,
    };
    final calorieText = items.isEmpty
        ? null
        : calorieGoal == null
        ? '${calories.round()} ${_mealListText(context, 'kcal')}'
        : '${calories.round()} / ${calorieGoal!.round()} ${_mealListText(context, 'kcal')}';
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAdd,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 94),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 10, 12),
            child: Row(
              key: Key('daily-meal-header-$type'),
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: .58),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: scheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        key: Key('daily-meal-title-$type'),
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.25,
                        ),
                      ),
                      if (calorieText != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          key: Key('daily-meal-totals-$type'),
                          calorieText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.ltr,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 128),
                  child: FilledButton.tonalIcon(
                    key: Key('daily-meal-log-$type'),
                    onPressed: onAdd,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        10,
                        0,
                        6,
                        0,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.chevron_right_rounded, size: 19),
                    label: Text(
                      _mealListText(
                        context,
                        items.isEmpty ? 'logFood' : 'logMore',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Retained for compatibility with historical golden helpers while the live
// Today surface uses [_CompactDiaryMealCard].
// ignore: unused_element
class _DiaryMealCard extends StatelessWidget {
  const _DiaryMealCard({
    required this.type,
    required this.title,
    required this.meal,
    required this.showFoodInsights,
    required this.showFoodTimestamps,
    required this.useNetCarbs,
    required this.mealGoal,
    required this.calorieGoal,
    required this.macroDisplay,
    required this.onAdd,
    required this.onEdit,
    required this.onActions,
  });

  final String type;
  final String title;
  final MealWithItems? meal;
  final bool showFoodInsights;
  final bool showFoodTimestamps;
  final bool useNetCarbs;
  final NutritionGoalTarget? mealGoal;
  final double? calorieGoal;
  final MealMacroDisplay? macroDisplay;
  final VoidCallback onAdd;
  final Future<void> Function(MealItem item, Food food) onEdit;
  final Future<void> Function(MealItem item, Food? food) onActions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = meal?.items ?? const <MealItem>[];
    final totals = _macroSummary(items);
    final calories = items.fold<double>(0, (sum, item) => sum + item.calories);
    final netCarbs = useNetCarbs ? knownNetCarbohydrateTotal(items) : null;
    final carbValue = useNetCarbs ? netCarbs : totals.carbs;
    final macroLine =
        'C ${carbValue == null ? '—' : formatDiaryMacroGrams(carbValue)}g   '
        'F ${formatDiaryMacroGrams(totals.fat)}g   '
        'P ${formatDiaryMacroGrams(totals.protein)}g';
    Widget logButton() => SizedBox(
      width: 124,
      child: FilledButton.tonal(
        key: Key('daily-meal-log-$type'),
        onPressed: onAdd,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: const StadiumBorder(),
          textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        child: Text(
          _mealListText(context, items.isEmpty ? 'logFood' : 'logMore'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: items.isEmpty
          ? ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 100),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
                child: Row(
                  key: Key('daily-meal-header-$type'),
                  children: [
                    Expanded(
                      child: Text(
                        key: Key('daily-meal-title-$type'),
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    logButton(),
                  ],
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 15, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    key: Key('daily-meal-header-$type'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              key: Key('daily-meal-title-$type'),
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.25,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            PremiumNutritionGlass(
                              key: Key('daily-meal-macros-$type'),
                              compact: true,
                              borderRadius: 8,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                child: Text(
                                  macroLine,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textDirection: TextDirection.ltr,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        fontSize: 13,
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        key: Key('daily-meal-totals-$type'),
                        '${calories.round()} ${_mealListText(context, 'kcal')}',
                        maxLines: 1,
                        textDirection: TextDirection.ltr,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.25,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(
                    key: Key('daily-meal-divider-$type'),
                    height: 1,
                    color: scheme.outlineVariant,
                  ),
                  const SizedBox(height: 7),
                  for (final item in items)
                    _DiaryFoodRow(
                      item: item,
                      food: meal?.foodsById[item.foodId],
                      onEdit: onEdit,
                      onActions: onActions,
                    ),
                  const SizedBox(height: 2),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: logButton(),
                  ),
                ],
              ),
            ),
    );
  }
}

class DailyMealDetailItems extends StatelessWidget {
  const DailyMealDetailItems({
    super.key,
    required this.meal,
    required this.onEdit,
    required this.onActions,
  });

  final MealWithItems? meal;
  final Future<void> Function(MealItem item, Food food) onEdit;
  final Future<void> Function(MealItem item, Food? food) onActions;

  @override
  Widget build(BuildContext context) {
    final items = [...?meal?.items]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('daily-meal-detail-items'),
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _mealListText(context, 'foodsInMeal'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            if (items.isEmpty) ...[
              const SizedBox(height: 14),
              Icon(
                Icons.add_circle_outline_rounded,
                color: scheme.primary,
                size: 30,
              ),
              const SizedBox(height: 8),
              Text(
                _mealListText(context, 'emptyMeal'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              for (var index = 0; index < items.length; index++) ...[
                _DiaryFoodRow(
                  item: items[index],
                  food: meal?.foodsById[items[index].foodId],
                  onEdit: onEdit,
                  onActions: onActions,
                  showLoggedTime: true,
                ),
                if (index != items.length - 1)
                  Divider(height: 1, color: scheme.outlineVariant),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _DiaryFoodRow extends StatelessWidget {
  const _DiaryFoodRow({
    required this.item,
    required this.food,
    required this.onEdit,
    required this.onActions,
    this.showLoggedTime = false,
  });

  final MealItem item;
  final Food? food;
  final Future<void> Function(MealItem item, Food food) onEdit;
  final Future<void> Function(MealItem item, Food? food) onActions;
  final bool showLoggedTime;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    final name = food == null
        ? context.strings.text('Historical food')
        : FoodPresentationLocalizer.foodName(
            name: food!.name,
            arabicName: food!.arabicName,
            localeTag: locale,
            isCustom: food!.isCustom,
            source: food!.source,
          );
    final serving = _servingText(
      item.quantity,
      item.servingUnitSnapshot,
      locale,
    );
    final localTime = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(item.createdAt.toLocal()),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final detail = showLoggedTime
        ? '$serving  ·  ${_mealListText(context, 'loggedAt')} $localTime'
        : serving;
    return Semantics(
      button: food != null && food?.deletedAt == null,
      hint: _mealListText(context, 'itemActions'),
      child: InkWell(
        key: Key('daily-food-row-${item.id}'),
        borderRadius: BorderRadius.circular(14),
        onTap: food == null || food?.deletedAt != null
            ? () => onActions(item, food)
            : () => onEdit(item, food!),
        onLongPress: () => onActions(item, food),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                item.calories.round().toString(),
                textDirection: TextDirection.ltr,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _servingText(double quantity, String unit, String locale) {
    final amount = quantity == quantity.roundToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity.toStringAsFixed(1);
    return FoodPresentationLocalizer.servingText(
      amount: amount,
      unit: unit,
      localeTag: locale,
    );
  }
}

class _DiaryEmptyMeals extends StatelessWidget {
  const _DiaryEmptyMeals({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.restaurant_menu_rounded, size: 36),
            const SizedBox(height: 10),
            Text(context.strings.text('No meals for this day.')),
            const SizedBox(height: 14),
            FilledButton.tonal(
              onPressed: onAdd,
              child: Text(_mealListText(context, 'logFood')),
            ),
          ],
        ),
      ),
    );
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
  final english = _mealListCopy['en']![key]!;
  return _mealListCopy[locale]?[key] ?? context.strings.text(english);
}

const _mealListCopy = <String, Map<String, String>>{
  'en': {
    'kcal': 'cal',
    'loggedAt': 'Logged at',
    'mealGoal': 'Meal goal',
    'itemActions': 'Tap to edit. Touch and hold for more actions.',
    'logFood': 'Plan meal',
    'logMore': 'Open meal',
    'foodsInMeal': 'Foods in this meal',
    'emptyMeal': 'Search above to add the first food to this meal.',
  },
  'ar': {
    'kcal': 'سعرة',
    'loggedAt': 'سُجّل في',
    'mealGoal': 'هدف الوجبة',
    'itemActions': 'اضغط للتعديل، واضغط مطولًا للمزيد من الإجراءات.',
    'logFood': 'خطّط للوجبة',
    'logMore': 'افتح الوجبة',
    'foodsInMeal': 'أطعمة هذه الوجبة',
    'emptyMeal': 'استخدم البحث أعلاه لإضافة أول طعام إلى هذه الوجبة.',
  },
  'fr': {
    'kcal': 'cal',
    'loggedAt': 'Enregistré à',
    'mealGoal': 'Objectif du repas',
    'itemActions': 'Touchez pour modifier. Maintenez pour plus d’actions.',
    'logFood': 'Planifier le repas',
    'logMore': 'Ouvrir le repas',
    'foodsInMeal': 'Aliments de ce repas',
    'emptyMeal':
        'Utilisez la recherche ci-dessus pour ajouter le premier aliment.',
  },
  'es': {
    'kcal': 'cal',
    'loggedAt': 'Registrado a las',
    'mealGoal': 'Objetivo de la comida',
    'itemActions': 'Toca para editar. Mantén pulsado para más acciones.',
    'logFood': 'Planificar comida',
    'logMore': 'Abrir comida',
    'foodsInMeal': 'Alimentos de esta comida',
    'emptyMeal': 'Usa la búsqueda de arriba para añadir el primer alimento.',
  },
  'tr': {
    'kcal': 'kal',
    'loggedAt': 'Kayıt saati',
    'mealGoal': 'Öğün hedefi',
    'itemActions': 'Düzenlemek için dokunun. Diğer işlemler için basılı tutun.',
    'logFood': 'Öğünü planla',
    'logMore': 'Öğünü aç',
    'foodsInMeal': 'Bu öğündeki yiyecekler',
    'emptyMeal': 'İlk yiyeceği eklemek için yukarıdaki aramayı kullanın.',
  },
  'de': {
    'logFood': 'Mahlzeit planen',
    'logMore': 'Mahlzeit öffnen',
    'foodsInMeal': 'Lebensmittel in dieser Mahlzeit',
    'emptyMeal': 'Suche oben, um das erste Lebensmittel hinzuzufügen.',
  },
  'it': {
    'logFood': 'Pianifica il pasto',
    'logMore': 'Apri il pasto',
    'foodsInMeal': 'Alimenti in questo pasto',
    'emptyMeal': 'Cerca qui sopra per aggiungere il primo alimento.',
  },
  'pt': {
    'logFood': 'Planejar refeição',
    'logMore': 'Abrir refeição',
    'foodsInMeal': 'Alimentos desta refeição',
    'emptyMeal': 'Pesquise acima para adicionar o primeiro alimento.',
  },
  'ur': {
    'logFood': 'کھانے کی منصوبہ بندی کریں',
    'logMore': 'کھانا کھولیں',
    'foodsInMeal': 'اس کھانے میں شامل غذائیں',
    'emptyMeal': 'پہلی غذا شامل کرنے کے لیے اوپر تلاش کریں۔',
  },
  'fa': {
    'logFood': 'برنامه‌ریزی وعده',
    'logMore': 'باز کردن وعده',
    'foodsInMeal': 'مواد غذایی این وعده',
    'emptyMeal': 'برای افزودن اولین ماده غذایی، بالا جستجو کنید.',
  },
  'hi': {
    'logFood': 'भोजन की योजना बनाएँ',
    'logMore': 'भोजन खोलें',
    'foodsInMeal': 'इस भोजन में खाद्य पदार्थ',
    'emptyMeal': 'पहला खाद्य पदार्थ जोड़ने के लिए ऊपर खोजें।',
  },
  'id': {
    'logFood': 'Rencanakan makan',
    'logMore': 'Buka makan',
    'foodsInMeal': 'Makanan dalam sajian ini',
    'emptyMeal': 'Cari di atas untuk menambahkan makanan pertama.',
  },
  'ms': {
    'logFood': 'Rancang sajian',
    'logMore': 'Buka sajian',
    'foodsInMeal': 'Makanan dalam sajian ini',
    'emptyMeal': 'Cari di atas untuk menambah makanan pertama.',
  },
  'ja': {
    'logFood': '食事を計画',
    'logMore': '食事を開く',
    'foodsInMeal': 'この食事の食品',
    'emptyMeal': '上で検索して最初の食品を追加してください。',
  },
  'ko': {
    'logFood': '식사 계획하기',
    'logMore': '식사 열기',
    'foodsInMeal': '이 식사의 음식',
    'emptyMeal': '위에서 검색하여 첫 음식을 추가하세요.',
  },
  'zh': {
    'logFood': '规划餐食',
    'logMore': '打开餐食',
    'foodsInMeal': '本餐食物',
    'emptyMeal': '请在上方搜索并添加第一种食物。',
  },
  'ru': {
    'logFood': 'Запланировать приём пищи',
    'logMore': 'Открыть приём пищи',
    'foodsInMeal': 'Продукты в этом приёме пищи',
    'emptyMeal': 'Найдите продукт выше, чтобы добавить его первым.',
  },
  'bn': {
    'logFood': 'খাবারের পরিকল্পনা করুন',
    'logMore': 'খাবার খুলুন',
    'foodsInMeal': 'এই খাবারের খাদ্যসমূহ',
    'emptyMeal': 'প্রথম খাদ্য যোগ করতে উপরে খুঁজুন।',
  },
  'vi': {
    'logFood': 'Lên kế hoạch bữa ăn',
    'logMore': 'Mở bữa ăn',
    'foodsInMeal': 'Thực phẩm trong bữa này',
    'emptyMeal': 'Tìm kiếm ở trên để thêm thực phẩm đầu tiên.',
  },
  'th': {
    'logFood': 'วางแผนมื้ออาหาร',
    'logMore': 'เปิดมื้ออาหาร',
    'foodsInMeal': 'อาหารในมื้อนี้',
    'emptyMeal': 'ค้นหาด้านบนเพื่อเพิ่มอาหารรายการแรก',
  },
  'pl': {
    'logFood': 'Zaplanuj posiłek',
    'logMore': 'Otwórz posiłek',
    'foodsInMeal': 'Produkty w tym posiłku',
    'emptyMeal': 'Wyszukaj powyżej, aby dodać pierwszy produkt.',
  },
  'nl': {
    'logFood': 'Maaltijd plannen',
    'logMore': 'Maaltijd openen',
    'foodsInMeal': 'Voedingsmiddelen in deze maaltijd',
    'emptyMeal': 'Zoek hierboven om het eerste voedingsmiddel toe te voegen.',
  },
  'uk': {
    'logFood': 'Запланувати прийом їжі',
    'logMore': 'Відкрити прийом їжі',
    'foodsInMeal': 'Продукти в цьому прийомі їжі',
    'emptyMeal': 'Знайдіть продукт вище, щоб додати його першим.',
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
