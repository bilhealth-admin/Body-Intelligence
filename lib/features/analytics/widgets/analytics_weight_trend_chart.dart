import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/theme/premium_design_tokens.dart';
import '../../../core/units/measurement_units.dart';
import '../../../data/database/app_database.dart';
import '../analytics_locale_copy.dart';

class AnalyticsWeightTrendChart extends StatelessWidget {
  const AnalyticsWeightTrendChart({
    super.key,
    required this.weights,
    required this.system,
    required this.rangeLabel,
    this.targetWeightKg,
  });

  final List<WeightEntry> weights;
  final MeasurementSystem system;
  final String rangeLabel;
  final double? targetWeightKg;

  @override
  Widget build(BuildContext context) {
    if (weights.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            context.strings.text('No local weight measurements in this range.'),
          ),
        ),
      );
    }

    final converted = weights
        .map((entry) => UnitConverter.weightFromKg(entry.weight, system))
        .toList();
    final convertedTarget = targetWeightKg == null
        ? null
        : UnitConverter.weightFromKg(targetWeightKg!, system);
    final measuredMin = converted.reduce((a, b) => a < b ? a : b);
    final measuredMax = converted.reduce((a, b) => a > b ? a : b);
    final minValue = convertedTarget == null
        ? measuredMin
        : (convertedTarget < measuredMin ? convertedTarget : measuredMin);
    final maxValue = convertedTarget == null
        ? measuredMax
        : (convertedTarget > measuredMax ? convertedTarget : measuredMax);
    final span = (maxValue - minValue).abs() < 0.01
        ? 1.0
        : (maxValue - minValue);
    final unit = UnitConverter.weightUnit(system);
    final firstValue = converted.first;
    final lastValue = converted.last;
    final delta = lastValue - firstValue;
    final progressColor = _goalProgressColor(
      start: firstValue,
      current: lastValue,
      target: convertedTarget,
      fallback: Theme.of(context).colorScheme.primary,
    );

    return SizedBox(
      height: 236,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusMd),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.35),
              Theme.of(context).colorScheme.surfaceContainerLow,
            ],
          ),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PremiumDesignTokens.spaceMd,
            PremiumDesignTokens.spaceSm,
            PremiumDesignTokens.spaceMd,
            PremiumDesignTokens.spaceSm,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ChartMetricChip(
                      label: analyticsText(context, 'Start', 'البداية'),
                      value: '${firstValue.toStringAsFixed(1)} $unit',
                    ),
                  ),
                  const SizedBox(width: PremiumDesignTokens.spaceXs),
                  Expanded(
                    child: _ChartMetricChip(
                      label: analyticsText(context, 'Current', 'الحالي'),
                      value: '${lastValue.toStringAsFixed(1)} $unit',
                      emphasize: true,
                      accent: progressColor,
                    ),
                  ),
                  const SizedBox(width: PremiumDesignTokens.spaceXs),
                  Expanded(
                    child: _ChartMetricChip(
                      label: analyticsText(context, 'Change', 'التغيّر'),
                      value:
                          '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} $unit',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PremiumDesignTokens.spaceSm),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ChartAxisLabels(
                      top: maxValue,
                      middle: minValue + (span / 2),
                      bottom: minValue,
                      unit: unit,
                    ),
                    const SizedBox(width: PremiumDesignTokens.spaceXs),
                    Expanded(
                      child: CustomPaint(
                        painter: _WeightLinePainter(
                          values: converted,
                          minValue: minValue,
                          span: span,
                          neutralColor: Theme.of(context).colorScheme.primary,
                          targetValue: convertedTarget,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.bottomEnd,
                          child: Semantics(
                            label: context.strings.text(
                              'Current measured point',
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: PremiumDesignTokens.spaceXs,
                                vertical: PremiumDesignTokens.spaceXs,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(
                                  PremiumDesignTokens.radiusMd,
                                ),
                              ),
                              child: Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(
                                  '${lastValue.toStringAsFixed(1)} $unit',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: PremiumDesignTokens.spaceXs),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  rangeLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeightLinePainter extends CustomPainter {
  _WeightLinePainter({
    required this.values,
    required this.minValue,
    required this.span,
    required this.neutralColor,
    required this.targetValue,
  });

  final List<double> values;
  final double minValue;
  final double span;
  final Color neutralColor;
  final double? targetValue;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final points = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? size.width / 2
          : (index / (values.length - 1)) * size.width;
      final normalized = (values[index] - minValue) / span;
      final y = size.height - (normalized * (size.height - 8)) - 4;
      points.add(Offset(x, y));
    }

    final grid = Paint()
      ..color = neutralColor.withValues(alpha: .10)
      ..strokeWidth = 1;
    for (var row = 0; row <= 3; row++) {
      final y = size.height * row / 3;
      canvas.drawLine(Offset.zero.translate(0, y), Offset(size.width, y), grid);
    }

    if (targetValue != null &&
        targetValue! >= minValue &&
        targetValue! <= minValue + span) {
      final normalized = (targetValue! - minValue) / span;
      final y = size.height - (normalized * (size.height - 8)) - 4;
      final targetPaint = Paint()
        ..color = const Color(0xFF12B76A).withValues(alpha: .72)
        ..strokeWidth = 1.5;
      for (double x = 0; x < size.width; x += 9) {
        canvas.drawLine(
          Offset(x, y),
          Offset((x + 5).clamp(0, size.width).toDouble(), y),
          targetPaint,
        );
      }
    }

    if (points.length > 1) {
      final areaPath = Path()..moveTo(points.first.dx, size.height);
      for (final point in points) {
        areaPath.lineTo(point.dx, point.dy);
      }
      areaPath
        ..lineTo(points.last.dx, size.height)
        ..close();
      canvas.drawPath(
        areaPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              neutralColor.withValues(alpha: .18),
              neutralColor.withValues(alpha: .015),
            ],
          ).createShader(Offset.zero & size),
      );
    }

    final startDistance = targetValue == null
        ? null
        : (values.first - targetValue!).abs();
    final line = Paint()
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (points.length == 1) {
      line.color = _goalProgressColor(
        start: values.first,
        current: values.first,
        target: targetValue,
        fallback: neutralColor,
      );
      canvas.drawCircle(points.first, 4, line..style = PaintingStyle.fill);
    } else {
      for (var index = 1; index < points.length; index++) {
        line.color = _goalProgressColorFromDistance(
          distance: targetValue == null
              ? null
              : (values[index] - targetValue!).abs(),
          startDistance: startDistance,
          fallback: neutralColor,
        );
        canvas.drawLine(points[index - 1], points[index], line);
      }
    }

    final currentColor = _goalProgressColor(
      start: values.first,
      current: values.last,
      target: targetValue,
      fallback: neutralColor,
    );
    canvas.drawCircle(
      points.first,
      4,
      Paint()
        ..color = neutralColor.withValues(alpha: .78)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      points.last,
      7,
      Paint()
        ..color = currentColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      points.last,
      9,
      Paint()
        ..color = Colors.white.withValues(alpha: .92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _WeightLinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.minValue != minValue ||
        oldDelegate.span != span ||
        oldDelegate.neutralColor != neutralColor ||
        oldDelegate.targetValue != targetValue;
  }
}

class _ChartMetricChip extends StatelessWidget {
  const _ChartMetricChip({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.accent,
  });

  final String label;
  final String value;
  final bool emphasize;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PremiumDesignTokens.spaceXs,
        vertical: PremiumDesignTokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: emphasize
            ? (accent ?? theme.colorScheme.primary).withValues(alpha: .14)
            : theme.colorScheme.surfaceContainerHighest,
        border: emphasize && accent != null
            ? Border.all(color: accent!.withValues(alpha: .30))
            : null,
        borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Directionality(
            textDirection: TextDirection.ltr,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                maxLines: 1,
                style: theme.textTheme.labelMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _goalProgressColor({
  required double start,
  required double current,
  required double? target,
  required Color fallback,
}) => _goalProgressColorFromDistance(
  distance: target == null ? null : (current - target).abs(),
  startDistance: target == null ? null : (start - target).abs(),
  fallback: fallback,
);

Color _goalProgressColorFromDistance({
  required double? distance,
  required double? startDistance,
  required Color fallback,
}) {
  if (distance == null || startDistance == null) return fallback;
  final progress = startDistance <= .001
      ? 1.0
      : (1 - (distance / startDistance)).clamp(0.0, 1.0).toDouble();
  const red = Color(0xFFE5484D);
  const amber = Color(0xFFF5A524);
  const green = Color(0xFF12B76A);
  if (progress < .5) {
    return Color.lerp(red, amber, progress * 2)!;
  }
  return Color.lerp(amber, green, (progress - .5) * 2)!;
}

class _ChartAxisLabels extends StatelessWidget {
  const _ChartAxisLabels({
    required this.top,
    required this.middle,
    required this.bottom,
    required this.unit,
  });

  final double top;
  final double middle;
  final double bottom;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return SizedBox(
      width: 54,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '${top.toStringAsFixed(1)} $unit',
                maxLines: 1,
                style: textStyle,
              ),
            ),
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '${middle.toStringAsFixed(1)} $unit',
                maxLines: 1,
                style: textStyle,
              ),
            ),
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '${bottom.toStringAsFixed(1)} $unit',
                maxLines: 1,
                style: textStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
