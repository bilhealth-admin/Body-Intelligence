part of 'daily_log_summary_widgets.dart';

class _MacroMetric extends StatelessWidget {
  const _MacroMetric({
    required this.color,
    required this.percent,
    required this.progress,
    required this.grams,
    required this.goal,
    required this.label,
    this.percentKey,
    this.gramsKey,
    this.loading = false,
  });

  final Color color;
  final double? percent;
  final double progress;
  final double grams;
  final double? goal;
  final String label;
  final Key? percentKey;
  final Key? gramsKey;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: percentKey,
      value: loading || percent == null ? '—' : '${percent!.round()}%',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              textDirection: TextDirection.ltr,
              children: [
                Text(
                  loading ? '—' : '${formatDiaryMacroGrams(grams)} g',
                  key: gramsKey,
                  maxLines: 1,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (goal != null && goal!.isFinite && goal! > 0)
                  Text(
                    ' / ${formatDiaryMacroGrams(goal!)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: loading ? 0 : progress,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              color: color,
            ),
          ),
        ],
      ),
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
