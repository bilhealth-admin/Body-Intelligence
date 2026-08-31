import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/theme/premium_design_tokens.dart';
import '../../../data/repositories/meal_repository.dart';

IconData dashboardMealIcon(String type, DateTime? recordedAt) {
  if (type == 'snack') return Icons.schedule_rounded;
  final hour = recordedAt?.toLocal().hour;
  if (hour != null) {
    if (hour < 11) return Icons.wb_sunny_outlined;
    if (hour < 17) return Icons.restaurant_outlined;
    return Icons.nights_stay_outlined;
  }
  return switch (type) {
    'breakfast' => Icons.wb_sunny_outlined,
    'lunch' => Icons.restaurant_outlined,
    'dinner' => Icons.nights_stay_outlined,
    _ => Icons.schedule_rounded,
  };
}

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
    required this.meal,
    required this.last,
    required this.onOpenMeal,
  });

  final String type;
  final String label;
  final MealWithItems? meal;
  final bool last;
  final ValueChanged<String> onOpenMeal;

  @override
  Widget build(BuildContext context) {
    final entry = meal;
    final calories =
        entry?.items.fold<double>(0, (sum, item) => sum + item.calories) ?? 0;
    final time = entry == null
        ? null
        : MaterialLocalizations.of(
            context,
          ).formatTimeOfDay(TimeOfDay.fromDateTime(entry.meal.date));
    final icon = dashboardMealIcon(type, entry?.meal.date);
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
            child: ListTile(
              key: ValueKey('today-meal-$type'),
              onTap: () => onOpenMeal(type),
              contentPadding: const EdgeInsetsDirectional.only(end: 16),
              title: Text(label),
              subtitle: Text(
                entry == null
                    ? context.strings.text('No foods logged yet')
                    : '${calories.round()} kcal · $time',
              ),
              trailing: FilledButton.tonalIcon(
                key: ValueKey('today-open-meal-$type'),
                onPressed: () => onOpenMeal(type),
                icon: Icon(
                  entry == null ? Icons.add_rounded : Icons.edit_outlined,
                ),
                label: Text(
                  context.strings.text(entry == null ? 'Add food' : 'Edit'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
