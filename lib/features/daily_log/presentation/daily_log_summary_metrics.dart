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
  final double? grams;
  final double? goal;
  final String label;
  final Key? percentKey;
  final Key? gramsKey;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label · g',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        PremiumNutritionGlass(
          compact: true,
          showLabel: false,
          child: Semantics(
            key: percentKey,
            value: loading
                ? '—'
                : percent == null
                ? '—'
                : '${percent!.round()}%',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: loading || grams == null
                            ? '—'
                            : formatDiaryMacroGrams(grams!),
                      ),
                      if (goal != null && goal!.isFinite && goal! > 0)
                        TextSpan(
                          text: ' / ${formatDiaryMacroGrams(goal!)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                  key: gramsKey,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: ExcludeSemantics(
                    excluding: loading || grams == null || percent == null,
                    child: BilStripedProgress(
                      nutritionColors: true,
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: loading ? 0 : progress,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
    this.compact = false,
    this.unknownAsDash = false,
  });

  final String label;
  final double? value;
  final String unit;
  final bool compact;
  final bool unknownAsDash;

  @override
  Widget build(BuildContext context) {
    final localizedUnit = _summaryText(context, unit);
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 11,
          vertical: compact ? 5 : 7,
        ),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              compact ? label : '$label · $localizedUnit',
              style: compact
                  ? Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    )
                  : null,
            ),
            const SizedBox(height: 4),
            if (compact)
              Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (value == null)
                    Semantics(
                      label: context.strings.text('Unavailable'),
                      child: const ExcludeSemantics(child: Text('—')),
                    )
                  else
                    PremiumNutritionGlass(
                      compact: true,
                      showLabel: false,
                      child: Text(
                        value!.toStringAsFixed(1),
                        textDirection: TextDirection.ltr,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                      ),
                    ),
                  Text(
                    localizedUnit,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              )
            else if (value == null)
              Semantics(
                label: context.strings.text('Unavailable'),
                child: ExcludeSemantics(
                  child: Text(
                    unknownAsDash ? '—' : context.strings.text('Unavailable'),
                  ),
                ),
              )
            else
              PremiumNutritionGlass(
                compact: true,
                showLabel: false,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    value!.toStringAsFixed(1),
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
