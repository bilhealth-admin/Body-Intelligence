part of 'daily_log_meals_list.dart';

/// Planning remains discoverable inside the meal, away from Today's overview.
class DailyMealPlannerAction extends StatelessWidget {
  const DailyMealPlannerAction({
    super.key,
    required this.mealType,
    required this.onPressed,
  });
  final String mealType;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    key: Key('daily-meal-planner-$mealType'),
    tooltip: _mealListText(context, 'logFood'),
    onPressed: onPressed,
    icon: const Icon(Icons.event_note_rounded),
  );
}

/// Today's row opens the existing meal editor. Evidence, quantities and goals
/// remain owned by the repositories and the dedicated meal screen.
class _DiaryCompactMealRow extends StatelessWidget {
  const _DiaryCompactMealRow({
    super.key,
    required this.type,
    required this.title,
    required this.meal,
    required this.onOpen,
  });

  final String type;
  final String title;
  final MealWithItems? meal;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = meal?.items ?? const <MealItem>[];
    final calories = DailyLogNutritionEvidence.forItems(
      items,
      ownerKey: meal?.ownerKey,
    ).total(TrackedNutrient.calories);
    final value = items.isEmpty
        ? _mealListText(context, 'notRecorded')
        : '${calories?.round() ?? '—'} ${_mealListText(context, 'kcal')}';
    final name = Text(
      title,
      key: Key('daily-meal-title-$type'),
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
    final total = Text(
      value,
      key: Key('daily-meal-totals-$type'),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
    );
    return BilPearlCard(
      margin: EdgeInsets.zero,
      child: Semantics(
        key: Key('daily-meal-access-$type'),
        button: true,
        onTap: onOpen,
        label: '$title, $value',
        hint: _mealListText(context, 'logMore'),
        excludeSemantics: true,
        child: InkWell(
          key: Key('daily-meal-log-$type'),
          onTap: onOpen,
          borderRadius: BorderRadius.circular(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scaler = MediaQuery.textScalerOf(context);
                  double lineWidth(Text text) {
                    final painter = TextPainter(
                      text: TextSpan(text: text.data, style: text.style),
                      textDirection: Directionality.of(context),
                      textScaler: scaler,
                      locale: Localizations.localeOf(context),
                      maxLines: 1,
                    )..layout();
                    final width = painter.width;
                    painter.dispose();
                    return width;
                  }

                  // The icon, gaps and chevron occupy 66 logical pixels.
                  // Localized labels must fit beside their actual total before
                  // selecting the compact single-line presentation.
                  final inlineWidth = lineWidth(name) + 10 + lineWidth(total);
                  final stacked =
                      constraints.maxWidth < 290 ||
                      scaler.scale(1) > 1.3 ||
                      inlineWidth > constraints.maxWidth - 66;
                  return Row(
                    key: Key('daily-meal-header-$type'),
                    children: [
                      BilNavigationFeedback(
                        child: Icon(
                          BilSemanticIcons.spec(_mealSemanticIcon(type)).icon,
                          size: 24,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: stacked
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  name,
                                  const SizedBox(height: 4),
                                  total,
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(child: name),
                                  const SizedBox(width: 10),
                                  total,
                                ],
                              ),
                      ),
                      const SizedBox(width: 10),
                      BilNavigationFeedback(
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
