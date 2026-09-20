part of 'daily_log_summary_widgets.dart';

class _CalorieSummary extends StatelessWidget {
  const _CalorieSummary({
    required this.calories,
    required this.calorieGoal,
    required this.remaining,
    required this.loading,
  });

  final double calories;
  final double? calorieGoal;
  final double? remaining;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final goal =
        calorieGoal != null && calorieGoal!.isFinite && calorieGoal! > 0;
    final status = !goal
        ? _summaryText(context, 'noGoal')
        : remaining! >= 0
        ? '${remaining!.round()} ${_summaryText(context, 'kcal')} ${_summaryText(context, 'remaining')}'
        : '${(-remaining!).round()} ${_summaryText(context, 'kcal')} ${_summaryText(context, 'over')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _summaryText(context, 'calories'),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        if (loading)
          Container(
            key: const Key('daily-summary-calories-loading'),
            width: 150,
            height: 27,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
          )
        else
          Text(
            '${calories.round()} ${_summaryText(context, 'kcal')}${goal ? ' / ${calorieGoal!.round()}' : ''}',
            key: const Key('daily-summary-calories-value'),
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        const SizedBox(height: 4),
        Text(
          loading ? '…' : status,
          key: const Key('daily-summary-calories-status'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: goal && remaining! < 0
                ? scheme.error
                : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            key: const Key('daily-summary-calories-progress'),
            minHeight: 7,
            value: loading || !goal
                ? 0
                : (calories / calorieGoal!).clamp(0.0, 1.0).toDouble(),
            backgroundColor: scheme.surfaceContainerHighest,
            color: goal && remaining! < 0 ? scheme.error : scheme.primary,
          ),
        ),
      ],
    );
  }
}

class _SummaryRingSkeleton extends StatelessWidget {
  const _SummaryRingSkeleton({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 84,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 10),
        ),
      ),
    );
  }
}

class _MealMacroDial extends StatelessWidget {
  const _MealMacroDial({
    required this.label,
    required this.grams,
    required this.progress,
    required this.color,
  });

  final String label;
  final double grams;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 62,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  color: color,
                  backgroundColor: color.withValues(alpha: .13),
                  strokeCap: StrokeCap.round,
                ),
                Padding(
                  padding: const EdgeInsets.all(9),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${formatDiaryMacroGrams(grams)} g',
                      maxLines: 1,
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class DailyLogCalorieMacroRing extends StatelessWidget {
  const DailyLogCalorieMacroRing({
    super.key,
    required this.calories,
    required this.calorieGoal,
    required this.carbs,
    required this.fat,
    required this.protein,
    this.dimension = 126,
  });

  final double calories;
  final double? calorieGoal;
  final double carbs;
  final double fat;
  final double protein;
  final double dimension;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${calories.round()} ${_summaryText(context, 'kcal')}${calorieGoal == null ? '' : ' / ${calorieGoal!.round()}'}',
      child: SizedBox.square(
        dimension: dimension,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(dimension),
              painter: _MacroRingPainter(
                carbs: carbs,
                fat: fat,
                protein: protein,
                track: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(dimension * 0.17),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      calories.round().toString(),
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                    ),
                    Text(
                      _summaryText(context, 'kcal'),
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (calorieGoal != null)
                      Text(
                        '/ ${calorieGoal!.round()}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroRingPainter extends CustomPainter {
  const _MacroRingPainter({
    required this.carbs,
    required this.fat,
    required this.protein,
    required this.track,
  });

  final double carbs;
  final double fat;
  final double protein;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const colors = [Color(0xFF0A8F88), Color(0xFF6F1096), Color(0xFFFFAB32)];
    final energies = [carbs * 4, fat * 9, protein * 4];
    final total = energies.fold<double>(0, (sum, value) => sum + value);
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - 12) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, radius, paint..color = track);
    if (total <= 0) return;
    var start = -1.5707963267948966;
    for (var i = 0; i < energies.length; i++) {
      final sweep = 6.283185307179586 * energies[i] / total;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint..color = colors[i],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _MacroRingPainter oldDelegate) =>
      carbs != oldDelegate.carbs ||
      fat != oldDelegate.fat ||
      protein != oldDelegate.protein ||
      track != oldDelegate.track;
}

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
  final double percent;
  final double progress;
  final double grams;
  final double? goal;
  final String label;
  final Key? percentKey;
  final Key? gramsKey;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${percent.round()}%',
          key: percentKey,
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${formatDiaryMacroGrams(grams)} g',
            key: gramsKey,
            maxLines: 1,
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 4,
            value: loading ? 0 : progress,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            color: color,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          goal == null || goal! <= 0
              ? label
              : '$label / ${formatDiaryMacroGrams(goal!)} g',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
        ),
      ],
    );
  }
}
