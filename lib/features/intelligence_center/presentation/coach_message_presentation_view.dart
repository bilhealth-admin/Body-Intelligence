import 'package:body_intelligence_log/shared/widgets/bil_crystal_expansion_indicator.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/coach_message_presentation.dart';
import 'coach_message_plain_copy.dart';

/// Assistant body only. No reads or writes occur during rendering.
class CoachMessageBody extends StatelessWidget {
  const CoachMessageBody({
    required this.text,
    required this.archive,
    required this.expectedOwnerKey,
    required this.ownerVisitIsCurrent,
    required this.textBuilder,
    this.presentation,
    this.copy,
    super.key,
  });
  final String text, expectedOwnerKey;
  final CoachMessagePresentation? presentation;
  final Map<String, Object?>? archive;
  final bool Function() ownerVisitIsCurrent;
  final Widget Function(String) textBuilder;
  final CoachMessagePlainCopy? copy;
  static String? archivedOwner(Map<String, Object?>? archive) {
    final value = archive?['ownerKey'];
    return value is String && value.isNotEmpty ? value : null;
  }

  @override
  Widget build(BuildContext context) {
    final words = copy ?? CoachMessagePlainCopy(context);
    final owner = presentation?.ownerKey ?? archivedOwner(archive);
    // A foreign-owner payload cannot fall back to text containing its facts.
    if (!ownerVisitIsCurrent() || owner != null && owner != expectedOwnerKey) {
      return Text(words.ownerChanged);
    }
    final visual =
        presentation ??
        CoachMessagePresentation.tryFromArchive(
          archive,
          expectedOwnerKey: expectedOwnerKey,
        );
    return visual == null
        ? textBuilder(text)
        : CoachMessagePresentationView(
            presentation: visual,
            expectedOwnerKey: expectedOwnerKey,
            ownerVisitIsCurrent: ownerVisitIsCurrent,
            copy: words,
          );
  }
}

class CoachMessagePresentationView extends StatelessWidget {
  const CoachMessagePresentationView({
    required this.presentation,
    required this.expectedOwnerKey,
    required this.ownerVisitIsCurrent,
    this.copy,
    super.key,
  });
  final CoachMessagePresentation presentation;
  final String expectedOwnerKey;
  final bool Function() ownerVisitIsCurrent;
  final CoachMessagePlainCopy? copy;
  @override
  Widget build(BuildContext context) {
    final words = copy ?? CoachMessagePlainCopy(context);
    if (!ownerVisitIsCurrent() || presentation.ownerKey != expectedOwnerKey) {
      return Text(words.ownerChanged);
    }
    final block = switch (presentation.kind) {
      CoachVisualKind.measurement => _Nutrition(
        column: presentation.columns.single,
        copy: words,
      ),
      CoachVisualKind.nutrition => _Nutrition(
        column: presentation.columns.single,
        copy: words,
      ),
      CoachVisualKind.comparison => _Comparison(
        presentation: presentation,
        copy: words,
      ),
      CoachVisualKind.weight => _Weight(
        presentation: presentation,
        copy: words,
      ),
    };
    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          block,
          for (final note in presentation.notes)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(note, style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: scheme.surfaceContainerLow.withValues(alpha: .72),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: .52),
            width: .7,
          ),
        ),
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics, required this.copy});
  final List<CoachVisualMetric> metrics;
  final CoachMessagePlainCopy copy;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final count = (constraints.maxWidth / (112 * scale.clamp(1, 3)))
          .floor()
          .clamp(1, 3);
      final width = (constraints.maxWidth - (count - 1) * 10) / count;
      final theme = Theme.of(context);
      return Wrap(
        spacing: 10,
        runSpacing: 12,
        children: [
          for (final metric in metrics)
            SizedBox(
              width: width,
              child: Semantics(
                label: copy.metricLine(metric),
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.metricLabel(metric.id),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: copy.amount(metric)),
                          if (metric.knownSubtotal != null)
                            TextSpan(
                              text: ' ${copy.metricUnit(metric)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                      key: ValueKey('coach-fact-${metric.id}'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: metric.id == 'calories' ? 24 : 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (metric.coverage == CoachVisualCoverage.partial)
                      Text(copy.partial, style: theme.textTheme.bodySmall),
                    if (metric.estimated)
                      Text(copy.estimated, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _Nutrition extends StatelessWidget {
  const _Nutrition({required this.column, required this.copy});
  final CoachVisualNutritionColumn column;
  final CoachMessagePlainCopy copy;
  static const main = {
    'calories',
    'carbohydrates',
    'fat',
    'protein',
    'fiber',
    'netCarbohydrates',
  };
  static const minerals = {
    'sodium',
    'potassium',
    'calcium',
    'magnesium',
    'phosphorus',
    'iron',
  };
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMeasurement = column.metrics.every((x) => x.unit == 'cm');
    final mainValues = column.metrics
        .where((x) => isMeasurement || main.contains(x.id))
        .toList();
    final mineralValues = column.metrics
        .where((x) => minerals.contains(x.id))
        .toList();
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.columnTitle(column),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(copy.day(column.dayKey), style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          _MetricGrid(metrics: mainValues, copy: copy),
          if (mineralValues.any((x) => x.knownSubtotal != null)) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1),
            ),
            Text(
              copy.tr('Minerals', 'المعادن'),
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 10),
            _MetricGrid(metrics: mineralValues, copy: copy),
          ],
          ExpansionTile(
            key: const ValueKey('coach-nutrition-details'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text(copy.details, style: theme.textTheme.bodyMedium),

            trailing: const BilCrystalExpansionIndicator(),
            children: [
              _MetricGrid(
                metrics: column.metrics
                    .where(
                      (x) =>
                          !isMeasurement &&
                          !main.contains(x.id) &&
                          (!minerals.contains(x.id) ||
                              !mineralValues.any(
                                (m) => m.knownSubtotal != null,
                              )),
                    )
                    .toList(),
                copy: copy,
              ),
              const SizedBox(height: 10),
              Text(copy.sources(column), style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison({required this.presentation, required this.copy});
  final CoachMessagePresentation presentation;
  final CoachMessagePlainCopy copy;
  CoachVisualMetric? _metric(CoachVisualNutritionColumn column, String id) {
    for (final metric in column.metrics) {
      if (metric.id == id) return metric;
    }
    return null;
  }

  double? _delta(String id) {
    final a = _metric(presentation.columns.first, id),
        b = _metric(presentation.columns.last, id);
    return a == null || b == null ? null : coachVisualMetricDifference(a, b);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final ids = presentation.columns
          .expand((x) => x.metrics)
          .map((x) => x.id)
          .toSet();
      if (presentation.columns.length > 2) {
        final cellWidth = 144.0 * scale.clamp(1, 3);
        return ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(copy.tr('Comparison', 'المقارنة')),
          subtitle: Text(
            '${presentation.columns.length} ${copy.tr('recorded periods', 'فترات مسجلة')}',
          ),

          trailing: const BilCrystalExpansionIndicator(),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: cellWidth * (presentation.columns.length + 1),
                child: Table(
                  defaultColumnWidth: FixedColumnWidth(cellWidth),
                  children: [
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(copy.tr('Nutrient', 'المغذي')),
                        ),
                        for (final column in presentation.columns)
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              '${copy.columnTitle(column)}\n${copy.day(column.dayKey)}',
                            ),
                          ),
                      ],
                    ),
                    for (final id in ids)
                      TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(copy.metricLabel(id)),
                          ),
                          for (final column in presentation.columns)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                _metric(column, id) == null
                                    ? copy.unavailable
                                    : copy.value(_metric(column, id)!),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      }
      if (constraints.maxWidth < 520 * scale) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final column in presentation.columns) ...[
              _Nutrition(column: column, copy: copy),
              const SizedBox(height: 10),
            ],
            if (presentation.columns.length == 2)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(copy.difference),

                trailing: const BilCrystalExpansionIndicator(),
                children: [
                  for (final id in ids)
                    if (_delta(id) case final value?)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(copy.metricLabel(id)),
                        subtitle: Text(
                          copy.metricDifference(
                            _metric(presentation.columns.first, id)!,
                            value,
                          ),
                        ),
                      ),
                ],
              ),
          ],
        );
      }
      return _Surface(
        child: Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {0: FlexColumnWidth(1.4)},
          children: [
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(copy.tr('Nutrient', 'المغذي')),
                ),
                for (final column in presentation.columns)
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      '${copy.columnTitle(column)}\n${copy.day(column.dayKey)}',
                    ),
                  ),
                if (presentation.columns.length == 2)
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(copy.difference),
                  ),
              ],
            ),
            for (final id in ids)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(copy.metricLabel(id)),
                  ),
                  for (final column in presentation.columns)
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        _metric(column, id) == null
                            ? copy.unavailable
                            : copy.value(_metric(column, id)!),
                      ),
                    ),
                  if (presentation.columns.length == 2)
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        _delta(id) == null
                            ? copy.unavailable
                            : copy.metricDifference(
                                _metric(presentation.columns.first, id)!,
                                _delta(id)!,
                              ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      );
    },
  );
}

class _Weight extends StatefulWidget {
  const _Weight({required this.presentation, required this.copy});
  final CoachMessagePresentation presentation;
  final CoachMessagePlainCopy copy;
  @override
  State<_Weight> createState() => _WeightState();
}

class _WeightState extends State<_Weight> {
  int? selected;
  @override
  void didUpdateWidget(covariant _Weight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.presentation, widget.presentation)) {
      selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.presentation.weightPoints,
        copy = widget.copy,
        theme = Theme.of(context);
    final index = (selected ?? points.length - 1).clamp(0, points.length - 1),
        point = points[index];
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(copy.weightLabel, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            copy.weight(point),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(copy.day(point.dayKey), style: theme.textTheme.bodySmall),
          if (index > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${copy.difference}: ${copy.weightDelta(points[index - 1], point)}',
              ),
            ),
          if (points.length >= 3) ...[
            const SizedBox(height: 12),
            Text(
              '${copy.day(widget.presentation.fromDay)} – ${copy.day(widget.presentation.throughDay)}',
              style: theme.textTheme.bodySmall,
            ),
            LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                onTapUp: (details) {
                  final fraction = coachVisualWeightTapFraction(
                    details.localPosition.dx,
                    constraints.maxWidth,
                  );
                  var nearest = 0, distance = double.infinity;
                  for (var i = 0; i < points.length; i++) {
                    final delta =
                        (coachVisualWeightFraction(points[i], points) -
                                fraction)
                            .abs();
                    if (delta < distance) {
                      nearest = i;
                      distance = delta;
                    }
                  }
                  setState(() => selected = nearest);
                },
                child: Semantics(
                  label: copy.recordedPoints,
                  child: CustomPaint(
                    key: const ValueKey('coach-weight-timeline'),
                    size: Size(constraints.maxWidth, 144),
                    painter: _WeightPainter(
                      points: points,
                      selected: index,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(copy.recordedPoints, style: theme.textTheme.bodySmall),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (var i = 0; i < points.length; i++)
                Tooltip(
                  message:
                      '${copy.point(points[i])} · ${points[i].recordedAtUtc.toIso8601String()}',
                  child: TextButton(
                    key: ValueKey('coach-weight-point-$i'),
                    onPressed: () => setState(() => selected = i),
                    child: Text(copy.point(points[i])),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeightPainter extends CustomPainter {
  _WeightPainter({
    required this.points,
    required this.selected,
    required this.color,
  });
  final List<CoachVisualWeightPoint> points;
  final int selected;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final minValue = points.map((x) => x.kg).reduce(math.min),
        maxValue = points.map((x) => x.kg).reduce(math.max);
    final span = maxValue - minValue;
    final coords = [
      for (final point in points)
        Offset(
          coachVisualWeightChartInset +
              coachVisualWeightFraction(point, points) *
                  (size.width - 2 * coachVisualWeightChartInset),
          span == 0
              ? size.height / 2
              : 8 + (maxValue - point.kg) / span * (size.height - 16),
        ),
    ];
    final line = Paint()
      ..color = color.withValues(alpha: .64)
      ..strokeWidth = 1.5;
    for (var i = 1; i < points.length; i++) {
      final a = coords[i - 1], b = coords[i];
      if (points[i].recordedAtUtc
              .difference(points[i - 1].recordedAtUtc)
              .inHours <=
          48) {
        canvas.drawLine(a, b, line);
      } else {
        for (var step = 0; step < 12; step += 2) {
          canvas.drawLine(
            Offset.lerp(a, b, step / 12)!,
            Offset.lerp(a, b, (step + 1) / 12)!,
            line,
          );
        }
      }
    }
    for (var i = 0; i < coords.length; i++) {
      canvas.drawCircle(
        coords[i],
        i == selected ? 5 : 3,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WeightPainter old) =>
      !identical(old.points, points) ||
      old.selected != selected ||
      old.color != color;
}
