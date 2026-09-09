part of 'daily_log_summary_widgets.dart';

class _MacroMetric extends StatelessWidget {
  const _MacroMetric({
    required this.metricKey,
    required this.color,
    required this.grams,
    required this.goalGrams,
    required this.label,
  });

  final String metricKey;
  final Color color;
  final double grams;
  final double? goalGrams;
  final String label;

  @override
  Widget build(BuildContext context) {
    final hasGoal = goalGrams != null && goalGrams!.isFinite && goalGrams! > 0;
    final percent = hasGoal ? grams / goalGrams! * 100 : null;
    // The Today summary's primary macro value is consumption, not a compact
    // consumed/target fraction. Progress remains available in the secondary
    // percentage immediately above it, so the goal is not lost or allowed to
    // compete with the owner's requested `3 g`-style reading hierarchy.
    final gramsText = '${formatDiaryMacroGrams(grams)} g';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        KeyedSubtree(
          key: Key('daily-summary-$metricKey-percent'),
          child: Text(
            percent == null ? '—' : '${percent.round()}%',
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          key: Key('daily-summary-$metricKey-grams'),
          fit: BoxFit.scaleDown,
          child: Text(
            gramsText,
            maxLines: 1,
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
        ),
      ],
    );
  }
}

class NutrientMetric extends StatelessWidget {
  const NutrientMetric({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final double? value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final localizedUnit = _summaryText(context, unit);
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.science_outlined,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                value == null
                    ? '$label: ${context.strings.text('Unavailable')}'
                    : '$label ${value!.toStringAsFixed(1)} $localizedUnit',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
