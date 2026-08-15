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
  });

  final List<WeightEntry> weights;
  final MeasurementSystem system;
  final String rangeLabel;

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
    final minValue = converted.reduce((a, b) => a < b ? a : b);
    final maxValue = converted.reduce((a, b) => a > b ? a : b);
    final span = (maxValue - minValue).abs() < 0.01
        ? 1.0
        : (maxValue - minValue);
    final unit = UnitConverter.weightUnit(system);
    final firstValue = converted.first;
    final lastValue = converted.last;
    final delta = lastValue - firstValue;

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
                    ),
                  ),
                  const SizedBox(width: PremiumDesignTokens.spaceXs),
                  Expanded(
                    child: _ChartMetricChip(
                      label: analyticsText(
                        context,
                        'Range change',
                        'تغير النطاق',
                      ),
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
                          lineColor: Theme.of(context).colorScheme.primary,
                          pointColor: Theme.of(context).colorScheme.tertiary,
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
    required this.lineColor,
    required this.pointColor,
  });

  final List<double> values;
  final double minValue;
  final double span;
  final Color lineColor;
  final Color pointColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? size.width / 2
          : (index / (values.length - 1)) * size.width;
      final normalized = (values[index] - minValue) / span;
      final y = size.height - (normalized * (size.height - 8)) - 4;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, line);

    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? size.width / 2
          : (index / (values.length - 1)) * size.width;
      final normalized = (values[index] - minValue) / span;
      final y = size.height - (normalized * (size.height - 8)) - 4;
      final point = Offset(x, y);

      canvas.drawCircle(
        point,
        6,
        Paint()
          ..color = pointColor
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        point,
        7.5,
        Paint()
          ..color = Colors.white.withValues(alpha: .92)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        point,
        index == values.length - 1 ? 12 : 9,
        Paint()
          ..color = pointColor.withValues(
            alpha: index == values.length - 1 ? .22 : .10,
          )
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WeightLinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.minValue != minValue ||
        oldDelegate.span != span ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.pointColor != pointColor;
  }
}

class _ChartMetricChip extends StatelessWidget {
  const _ChartMetricChip({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

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
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
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
            child: Text('${top.toStringAsFixed(1)} $unit', style: textStyle),
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text('${middle.toStringAsFixed(1)} $unit', style: textStyle),
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text('${bottom.toStringAsFixed(1)} $unit', style: textStyle),
          ),
        ],
      ),
    );
  }
}
