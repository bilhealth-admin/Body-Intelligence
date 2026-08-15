import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/theme/premium_design_tokens.dart';
import '../../../data/repositories/meal_repository.dart';

class DashboardMealsTimeline extends StatelessWidget {
  const DashboardMealsTimeline({
    super.key,
    required this.meals,
    required this.onOpenMeal,
    this.usualBreakfastAvailable = false,
    this.onRepeatBreakfast,
    this.recentBreakfastAvailable = false,
    this.onRepeatRecentBreakfast,
  });

  final List<MealWithItems> meals;
  final ValueChanged<String> onOpenMeal;
  final bool usualBreakfastAvailable;
  final VoidCallback? onRepeatBreakfast;
  final bool recentBreakfastAvailable;
  final VoidCallback? onRepeatRecentBreakfast;

  static const types = ['breakfast', 'lunch', 'dinner', 'snack'];

  String mealLabel(BuildContext context, String type) => switch (type) {
    'breakfast' => context.strings.text('Breakfast'),
    'lunch' => context.strings.text('Lunch'),
    'dinner' => context.strings.text('Dinner'),
    _ => context.strings.text('Snack'),
  };

  IconData mealIcon(String type) => switch (type) {
    'breakfast' => Icons.free_breakfast_outlined,
    'lunch' => Icons.lunch_dining_outlined,
    'dinner' => Icons.dinner_dining_outlined,
    _ => Icons.cookie_outlined,
  };

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: PremiumDesignTokens.spaceXs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              PremiumDesignTokens.spaceMd,
              PremiumDesignTokens.spaceXs,
              PremiumDesignTokens.spaceMd,
              PremiumDesignTokens.spaceXs / 2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.strings.text("Today's meals"),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => onOpenMeal('breakfast'),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(context.strings.text('Open Diary')),
                ),
              ],
            ),
          ),
          if (usualBreakfastAvailable || recentBreakfastAvailable)
            Padding(
              padding: EdgeInsets.fromLTRB(
                PremiumDesignTokens.spaceMd,
                PremiumDesignTokens.spaceXs / 2,
                PremiumDesignTokens.spaceMd,
                PremiumDesignTokens.spaceXs,
              ),
              child: Wrap(
                spacing: PremiumDesignTokens.spaceXs,
                runSpacing: PremiumDesignTokens.spaceXs,
                children: [
                  if (usualBreakfastAvailable)
                    FilledButton.tonalIcon(
                      onPressed: onRepeatBreakfast,
                      icon: const Icon(Icons.replay_outlined),
                      label: Text(_mealsTimelineCopy(context, 'repeatUsual')),
                    ),
                  if (recentBreakfastAvailable)
                    OutlinedButton.icon(
                      onPressed: onRepeatRecentBreakfast,
                      icon: const Icon(Icons.history_outlined),
                      label: Text(_mealsTimelineCopy(context, 'repeatLast')),
                    ),
                ],
              ),
            ),
          for (var index = 0; index < types.length; index++)
            _MealTimelineEntry(
              type: types[index],
              label: mealLabel(context, types[index]),
              icon: mealIcon(types[index]),
              meal: meals
                  .where((entry) => entry.meal.type == types[index])
                  .firstOrNull,
              last: index == types.length - 1,
              onOpenMeal: onOpenMeal,
            ),
        ],
      ),
    ),
  );
}

String _mealsTimelineCopy(BuildContext context, String key) {
  final locale = Localizations.localeOf(context).languageCode.toLowerCase();
  return (_mealsTimelineCopies[locale] ?? _mealsTimelineCopies['en']!)[key]!;
}

const _mealsTimelineCopies = <String, Map<String, String>>{
  'ar': {'repeatUsual': 'كرّر فطورك المعتاد', 'repeatLast': 'كرّر آخر فطور'},
  'en': {
    'repeatUsual': 'Repeat usual breakfast',
    'repeatLast': 'Repeat last breakfast',
  },
  'fr': {
    'repeatUsual': 'Répéter le petit-déjeuner habituel',
    'repeatLast': 'Répéter le dernier petit-déjeuner',
  },
  'es': {
    'repeatUsual': 'Repetir el desayuno habitual',
    'repeatLast': 'Repetir el último desayuno',
  },
  'tr': {
    'repeatUsual': 'Her zamanki kahvaltıyı tekrarla',
    'repeatLast': 'Son kahvaltıyı tekrarla',
  },
};

class _MealTimelineEntry extends StatelessWidget {
  const _MealTimelineEntry({
    required this.type,
    required this.label,
    required this.icon,
    required this.meal,
    required this.last,
    required this.onOpenMeal,
  });

  final String type;
  final String label;
  final IconData icon;
  final MealWithItems? meal;
  final bool last;
  final ValueChanged<String> onOpenMeal;

  @override
  Widget build(BuildContext context) {
    final entry = meal;
    final calories =
        entry?.items.fold<double>(0, (sum, item) => sum + item.calories) ?? 0;
    final protein =
        entry?.items.fold<double>(0, (sum, item) => sum + item.protein) ?? 0;
    final foodNames =
        entry?.items
            .map(
              (item) =>
                  entry.foodsById[item.foodId]?.name ??
                  context.strings.text('Historical food'),
            )
            .toList() ??
        const <String>[];
    final time = entry == null
        ? null
        : MaterialLocalizations.of(
            context,
          ).formatTimeOfDay(TimeOfDay.fromDateTime(entry.meal.date));
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 54,
            child: Column(
              children: [
                CircleAvatar(radius: 18, child: Icon(icon, size: 19)),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ExpansionTile(
              key: ValueKey('today-meal-$type'),
              tilePadding: const EdgeInsetsDirectional.only(end: 16),
              title: Text(label),
              subtitle: Text(
                entry == null
                    ? context.strings.text('No foods logged yet')
                    : '${calories.round()} kcal · ${protein.round()} g ${context.strings.text('protein')} · $time',
              ),
              childrenPadding: const EdgeInsetsDirectional.fromSTEB(
                0,
                0,
                16,
                12,
              ),
              children: [
                if (foodNames.isEmpty)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => onOpenMeal(type),
                      icon: const Icon(Icons.add),
                      label: Text(context.strings.text('Add food')),
                    ),
                  )
                else
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => onOpenMeal(type),
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(foodNames.join(' · ')),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
