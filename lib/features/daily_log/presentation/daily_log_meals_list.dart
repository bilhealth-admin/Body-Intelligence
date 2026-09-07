import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/theme/bil_semantic_icons.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/nutrient_evidence.dart';
import '../../../data/repositories/meal_repository.dart';
import '../../../shared/widgets/actionable_error_state.dart';
import '../../nutrition/services/food_presentation_localizer.dart';
import '../providers/daily_log_provider.dart';
import 'macro_value_formatter.dart';

part 'daily_log_meal_detail_items.dart';

class DailyMealsList extends ConsumerWidget {
  const DailyMealsList({
    super.key,
    required this.meals,
    this.showEmptyMealSlots = true,
    required this.onAdd,
  });

  final AsyncValue<List<MealWithItems>> meals;
  final bool showEmptyMealSlots;
  final ValueChanged<String> onAdd;

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
    required this.onAdd,
  });

  final String type;
  final String title;
  final MealWithItems? meal;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasItems = meal?.items.isNotEmpty ?? false;
    final semanticKind = switch (type) {
      'breakfast' => BilSemanticIconKind.breakfast,
      'lunch' => BilSemanticIconKind.lunch,
      'dinner' => BilSemanticIconKind.dinner,
      _ => BilSemanticIconKind.snack,
    };
    final logButton = FilledButton.tonalIcon(
      key: Key('daily-meal-log-$type'),
      onPressed: onAdd,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 42),
        padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 6, 0),
        shape: const StadiumBorder(),
      ),
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.chevron_right_rounded, size: 19),
      label: Text(
        _mealListText(context, hasItems ? 'logMore' : 'logFood'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 94),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                key: Key('daily-meal-header-$type'),
                children: [
                  BilSemanticIconBadge(
                    key: Key('daily-meal-semantic-icon-$type'),
                    kind: semanticKind,
                    size: 48,
                    iconSize: 25,
                    shape: BoxShape.rectangle,
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
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.25,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 128),
                    child: logButton,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
