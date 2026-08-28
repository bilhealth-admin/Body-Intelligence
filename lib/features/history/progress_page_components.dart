part of 'progress_page.dart';

class _Point {
  const _Point(this.date, this.value);
  final DateTime date;
  final double value;
}

class _ProgressSelector extends StatelessWidget {
  const _ProgressSelector({
    required this.icon,
    required this.eyebrow,
    required this.value,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String eyebrow;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: .62),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                size: 19,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          ],
        ),
      ),
    ),
  );
}

final class _ProgressSummaryData {
  const _ProgressSummaryData(this.label, this.value);
  final String label;
  final String value;
}

class _ProgressChartCard extends StatelessWidget {
  const _ProgressChartCard({
    required this.title,
    required this.latestLabel,
    required this.latestValue,
    required this.unit,
    required this.dateLabel,
    required this.semanticsLabel,
    required this.points,
    required this.summaries,
  });

  final String title;
  final String latestLabel;
  final String latestValue;
  final String unit;
  final String dateLabel;
  final String semanticsLabel;
  final List<_Point> points;
  final List<_ProgressSummaryData> summaries;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.surface,
              colors.primaryContainer.withValues(alpha: .2),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateLabel,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        latestLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: latestValue),
                              TextSpan(
                                text: ' $unit',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(color: colors.onSurfaceVariant),
                              ),
                            ],
                          ),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 220,
                child: Semantics(
                  label: semanticsLabel,
                  child: CustomPaint(
                    key: const Key('progress-real-series-chart'),
                    painter: _ProgressPainter(
                      points,
                      lineColor: colors.primary,
                      gridColor: colors.outlineVariant.withValues(alpha: .42),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: .75),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: .55),
                  ),
                ),
                child: Row(
                  children: [
                    for (var index = 0; index < summaries.length; index++) ...[
                      if (index > 0)
                        SizedBox(
                          height: 32,
                          child: VerticalDivider(
                            width: 1,
                            color: colors.outlineVariant,
                          ),
                        ),
                      Expanded(
                        child: _SummaryValue(
                          label: summaries[index].label,
                          value: summaries[index].value,
                          unit: unit,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.label,
    required this.value,
    required this.unit,
  });
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label, $value $unit',
    child: Column(
      children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _ProgressEmptyState extends StatelessWidget {
  const _ProgressEmptyState({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      child: Column(
        children: [
          Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: .85),
                  Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: .18),
                ],
              ),
            ),
            child: Icon(
              Icons.insights_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 19),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(height: 1.45),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('progress-empty-add'),
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    ),
  );
}

class _ProgressLoadingState extends StatelessWidget {
  const _ProgressLoadingState();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _ProgressSkeleton(width: 112, height: 18, color: colors),
                const Spacer(),
                _ProgressSkeleton(width: 72, height: 28, color: colors),
              ],
            ),
            const SizedBox(height: 24),
            _ProgressSkeleton(height: 220, color: colors),
            const SizedBox(height: 16),
            Row(
              children: [
                for (var index = 0; index < 3; index++) ...[
                  if (index > 0) const SizedBox(width: 10),
                  Expanded(child: _ProgressSkeleton(height: 50, color: colors)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressSkeleton extends StatelessWidget {
  const _ProgressSkeleton({
    this.width,
    required this.height,
    required this.color,
  });

  final double? width;
  final double height;
  final ColorScheme color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color.surfaceContainerHighest.withValues(alpha: .72),
      borderRadius: BorderRadius.circular(height > 80 ? 18 : 10),
    ),
  );
}

class _ProgressPainter extends CustomPainter {
  const _ProgressPainter(
    this.points, {
    required this.lineColor,
    required this.gridColor,
  });
  final List<_Point> points;
  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(4, 8, size.width - 8, size.height - 18);
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= 4; index++) {
      final y = chart.top + chart.height * index / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 3.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final values = points.map((point) => point.value);
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    final spread = math.max(high - low, 1);
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final x = points.length == 1
          ? chart.center.dx
          : chart.left + chart.width * index / (points.length - 1);
      final y =
          chart.bottom - ((points[index].value - low) / spread * chart.height);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final fillPath = Path.from(path)
      ..lineTo(points.length == 1 ? chart.center.dx : chart.right, chart.bottom)
      ..lineTo(points.length == 1 ? chart.center.dx : chart.left, chart.bottom)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: .26),
            lineColor.withValues(alpha: .01),
          ],
        ).createShader(chart),
    );
    canvas.drawPath(path, paint);
    final latestX = points.length == 1 ? chart.center.dx : chart.right;
    final latestY =
        chart.bottom - ((points.last.value - low) / spread * chart.height);
    canvas.drawCircle(
      Offset(latestX, latestY),
      7,
      Paint()..color = lineColor.withValues(alpha: .2),
    );
    canvas.drawCircle(Offset(latestX, latestY), 4, Paint()..color = lineColor);
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.gridColor != gridColor;
}
