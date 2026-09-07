part of 'premium_dashboard_benchmark.dart';

class _MacroProgress extends StatelessWidget {
  const _MacroProgress({
    required this.label,
    required this.value,
    required this.goal,
    required this.color,
    this.unit = 'g',
    this.showRemaining = true,
  });

  final String label;
  final int? value;
  final int? goal;
  final Color color;
  final String unit;
  final bool showRemaining;

  @override
  Widget build(BuildContext context) {
    final validGoal = goal != null && goal! > 0;
    final progress = DashboardHeartHealthPolicy.coverage(
      recorded: value,
      maximum: goal ?? 0,
    );
    final scheme = Theme.of(context).colorScheme;
    final remaining = !validGoal || value == null
        ? value
        : (goal! - value!).clamp(0, goal!);
    final centerValue = showRemaining ? remaining : value;
    final semanticValue = value == null
        ? 'unavailable'
        : validGoal
        ? '$value of $goal $unit'
        : '$value $unit';
    return Semantics(
      label: '$label, $semanticValue',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 62,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.square(
                  dimension: 56,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    color: color,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          centerValue?.toString() ?? '—',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: const Color(0xFF101923),
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        Text(
                          value == null ? '' : unit,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: const Color(0xFF101923)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF101923),
              fontWeight: FontWeight.w800,
              height: 1.08,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogShortcut extends StatelessWidget {
  const _LogShortcut({
    required this.kind,
    required this.label,
    required this.recorded,
    required this.onTap,
  });

  final BilSemanticIconKind kind;
  final String label;
  final bool recorded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          BilSemanticIconBadge(
            key: Key('dashboard-log-${kind.name}-icon'),
            kind: kind,
            size: 38,
            iconSize: 21,
          ),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Icon(
            recorded
                ? Icons.check_circle_rounded
                : Icons.add_circle_outline_rounded,
            size: 17,
            color: recorded
                ? const Color(0xFF38A169)
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    ),
  );
}
