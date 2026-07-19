import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../app/localization/app_localizations.dart';
import '../../core/units/measurement_units.dart';
import '../../engine/weight_analysis.dart';
import '../../engine/progress_analysis.dart';
import '../../shared/widgets/wheel_number_field.dart';
import '../../shared/widgets/actionable_empty_state.dart';
import '../../shared/widgets/actionable_error_state.dart';
import '../profile/providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    WeightEntry? entry,
  ]) async {
    final system =
        ref.read(measurementSystemProvider).value ?? MeasurementSystem.metric;
    var displayed = UnitConverter.weightFromKg(entry?.weight ?? 60, system);
    var selectedDate = entry?.date ?? DateTime.now();
    var measurementContext = entry?.measurementContext ?? 'differentConditions';
    final value =
        await showDialog<
          ({double weight, DateTime date, String measurementContext})
        >(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(
                context.strings.text(
                  entry == null ? 'Add weight' : 'Edit weight',
                ),
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      WheelNumberField(
                        value: displayed,
                        minimum: UnitConverter.weightFromKg(20, system),
                        maximum: UnitConverter.weightFromKg(350, system),
                        step: UnitConverter.weightStep(system),
                        decimalPlaces: 1,
                        unit: UnitConverter.weightUnit(system),
                        label: context.strings.text('Weight'),
                        onChanged: (next) =>
                            setDialogState(() => displayed = next),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today_outlined),
                        title: Text(context.strings.text('Measurement date')),
                        subtitle: Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatMediumDate(selectedDate),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: measurementContext,
                        decoration: InputDecoration(
                          labelText: context.strings.text(
                            'Measurement conditions',
                          ),
                        ),
                        items:
                            const [
                                  'morning',
                                  'afterBathroom',
                                  'beforeFoodDrink',
                                  'differentConditions',
                                ]
                                .map(
                                  (contextValue) => DropdownMenuItem(
                                    value: contextValue,
                                    child: Text(
                                      context.strings.text(contextValue),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (next) => setDialogState(
                          () => measurementContext =
                              next ?? 'differentConditions',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(context.strings.text('Cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, (
                    weight: UnitConverter.weightToKg(displayed, system),
                    date: selectedDate,
                    measurementContext: measurementContext,
                  )),
                  child: Text(context.strings.text('Save')),
                ),
              ],
            ),
          ),
        );
    if (value == null) return;
    final repository = ref.read(weightRepositoryProvider);
    try {
      if (entry == null) {
        await repository.addWeight(
          value.weight,
          date: value.date,
          measurementContext: value.measurementContext,
        );
      } else {
        await repository.updateWeight(
          id: entry.id,
          weight: value.weight,
          date: value.date,
          note: entry.note,
          measurementContext: value.measurementContext,
        );
      }
    } on StateError {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.text(
              'A weight entry already exists for this date.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    WeightEntry entry,
  ) async {
    final system =
        ref.read(measurementSystemProvider).value ?? MeasurementSystem.metric;
    final displayed = UnitConverter.weightFromKg(entry.weight, system);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.strings.text('Delete weight?')),
        content: Text(
          '${context.strings.text('Delete')} ${displayed.toStringAsFixed(1)} ${UnitConverter.weightUnit(system)} ${context.strings.text('from history?')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.strings.text('Delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(weightRepositoryProvider).deleteWeight(entry.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(weightHistoryProvider);
    final system =
        ref.watch(measurementSystemProvider).value ?? MeasurementSystem.metric;
    final unit = UnitConverter.weightUnit(system);
    final profile = ref.watch(userProfileProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.text('Weight history'))),
      floatingActionButton: history.value?.isNotEmpty == true
          ? FloatingActionButton(
              tooltip: context.strings.text('Add weight'),
              onPressed: () => _edit(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ActionableErrorState(
          title: context.strings.text('Could not load weight history'),
          onRetry: () => ref.invalidate(weightHistoryProvider),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return ActionableEmptyState(
              icon: Icons.monitor_weight_outlined,
              title: context.strings.text('Build your first comparable trend'),
              body: context.strings.text(
                'One measurement establishes a starting point. BIL waits for more comparable days before describing a trend.',
              ),
              actionLabel: context.strings.text('Record first weight'),
              onAction: () => _edit(context, ref),
            );
          }
          final chronological = rows.reversed.toList();
          final trend = WeightAnalysis.calculateWeeklyTrend(
            chronological.map((row) => row.weight).toList(),
          );
          final analysis = ProgressAnalysis.evaluate(
            samples: chronological
                .map(
                  (row) => ProgressSample(date: row.date, weightKg: row.weight),
                )
                .toList(),
            goalWeightKg: profile?.targetWeight,
          );
          final arabic = Localizations.localeOf(context).languageCode == 'ar';
          final recent = chronological.length > 30
              ? chronological.sublist(chronological.length - 30)
              : chronological;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.strings.text('Weight trend'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _WeightTrendChart(
                        weights: recent.map((row) => row.weight).toList(),
                        variability: analysis.variabilityKg,
                        semanticsLabel: context.strings.text(
                          'Recorded weight trend over time',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${context.strings.text('Seven-day change')}: ${trend == null ? context.strings.text('More data needed') : '${UnitConverter.weightFromKg(trend, system).toStringAsFixed(2)} $unit'}',
                      ),
                      Text(
                        '${context.strings.text('Smoothed weekly direction')}: ${analysis.weeklyDirectionKg == null ? context.strings.text('At least four entries needed') : '${analysis.weeklyDirectionKg! >= 0 ? '+' : ''}${UnitConverter.weightFromKg(analysis.weeklyDirectionKg!, system).toStringAsFixed(2)} $unit/${context.strings.text('week')}'}',
                      ),
                      Text(
                        arabic
                            ? 'الاتجاه الشهري التقريبي: ${analysis.monthlyDirectionKg == null ? 'نحتاج بيانات تمتد لفترة أطول' : '${analysis.monthlyDirectionKg! >= 0 ? '+' : ''}${UnitConverter.weightFromKg(analysis.monthlyDirectionKg!, system).toStringAsFixed(1)} $unit'}'
                            : 'Approximate monthly direction: ${analysis.monthlyDirectionKg == null ? 'a longer evidence window is needed' : '${analysis.monthlyDirectionKg! >= 0 ? '+' : ''}${UnitConverter.weightFromKg(analysis.monthlyDirectionKg!, system).toStringAsFixed(1)} $unit'}',
                      ),
                      Text(
                        arabic
                            ? 'الثقة: ${_confidenceLabel(analysis.confidence, true)} · ${analysis.sampleCount} قياسًا خلال ${analysis.spanDays} يومًا'
                            : 'Confidence: ${_confidenceLabel(analysis.confidence, false)} · ${analysis.sampleCount} measurements across ${analysis.spanDays} days',
                      ),
                      if (analysis.variabilityKg != null)
                        Text(
                          arabic
                              ? 'التذبذب حول الاتجاه: نحو ${UnitConverter.weightFromKg(analysis.variabilityKg!, system).toStringAsFixed(2)} $unit'
                              : 'Variation around the direction: about ${UnitConverter.weightFromKg(analysis.variabilityKg!, system).toStringAsFixed(2)} $unit',
                        ),
                      Text(
                        analysis.projectedGoalDate == null
                            ? (arabic
                                  ? 'لن نعرض تاريخ هدف حتى تتوفر بيانات كافية واتجاه متوافق.'
                                  : 'No goal date is shown until evidence is sufficient and the direction aligns with the goal.')
                            : '${arabic ? 'نطاق تقديري حذر للهدف' : 'Cautious goal estimate'}: ${analysis.projectedGoalDate!.year}-${analysis.projectedGoalDate!.month.toString().padLeft(2, '0')}-${analysis.projectedGoalDate!.day.toString().padLeft(2, '0')}',
                      ),
                      Text(
                        context.strings.text(
                          'Scale trends include water, glycogen, digestive content, and measurement variation; they do not prove fat or muscle change.',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              ...rows.map(
                (entry) => Card(
                  child: ListTile(
                    title: Text(
                      '${UnitConverter.weightFromKg(entry.weight, system).toStringAsFixed(1)} $unit',
                    ),
                    subtitle: Text(
                      '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}-${entry.date.day.toString().padLeft(2, '0')}',
                    ),
                    onTap: () => _edit(context, ref, entry),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(context, ref, entry),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _confidenceLabel(ProgressConfidence confidence, bool arabic) =>
    switch (confidence) {
      ProgressConfidence.insufficient => arabic ? 'غير كافية' : 'insufficient',
      ProgressConfidence.low => arabic ? 'منخفضة' : 'low',
      ProgressConfidence.medium => arabic ? 'متوسطة' : 'medium',
      ProgressConfidence.high => arabic ? 'مرتفعة' : 'high',
    };

class _WeightTrendChart extends StatefulWidget {
  const _WeightTrendChart({
    required this.weights,
    required this.variability,
    required this.semanticsLabel,
  });

  final List<double> weights;
  final double? variability;
  final String semanticsLabel;

  @override
  State<_WeightTrendChart> createState() => _WeightTrendChartState();
}

class _WeightTrendChartState extends State<_WeightTrendChart> {
  bool showRaw = false;

  @override
  Widget build(BuildContext context) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return Column(
      children: [
        Semantics(
          label:
              '${widget.semanticsLabel}. ${arabic ? 'الخط الممهّد مع نطاق التذبذب' : 'Smoothed line with a variation band'}',
          image: true,
          child: SizedBox(
            height: 150,
            child: CustomPaint(
              painter: _WeightTrendPainter(
                weights: widget.weights,
                variability: widget.variability,
                showRaw: showRaw,
                color: Theme.of(context).colorScheme.primary,
                gridColor: Theme.of(context).dividerColor,
              ),
            ),
          ),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(
            arabic ? 'إظهار القياسات الخام' : 'Show raw measurements',
          ),
          subtitle: Text(
            arabic
                ? 'النطاق المظلل يوضح التذبذب حول الاتجاه، وليس يقينًا إحصائيًا.'
                : 'The shaded band shows variation around the trend, not statistical certainty.',
          ),
          value: showRaw,
          onChanged: (value) => setState(() => showRaw = value),
        ),
      ],
    );
  }
}

class _WeightTrendPainter extends CustomPainter {
  const _WeightTrendPainter({
    required this.weights,
    required this.variability,
    required this.showRaw,
    required this.color,
    required this.gridColor,
  });

  final List<double> weights;
  final double? variability;
  final bool showRaw;
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (var index = 0; index <= 3; index++) {
      final y = size.height * index / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (weights.isEmpty) return;
    var minimum = weights.reduce((a, b) => a < b ? a : b);
    var maximum = weights.reduce((a, b) => a > b ? a : b);
    if ((maximum - minimum).abs() < 0.1) {
      minimum -= 0.1;
      maximum += 0.1;
    }
    final smoothed = <double>[
      for (var index = 0; index < weights.length; index++)
        weights
                .sublist(
                  math.max(0, index - 1),
                  math.min(weights.length, index + 2),
                )
                .reduce((a, b) => a + b) /
            (math.min(weights.length, index + 2) - math.max(0, index - 1)),
    ];
    Offset pointFor(int index, double value) {
      final x = weights.length == 1
          ? size.width / 2
          : size.width * index / (weights.length - 1);
      final y =
          size.height - ((value - minimum) / (maximum - minimum)) * size.height;
      return Offset(x, y.clamp(0, size.height));
    }

    if (variability != null && variability! > 0) {
      final band = Path();
      for (var index = 0; index < smoothed.length; index++) {
        final point = pointFor(index, smoothed[index] + variability!);
        index == 0
            ? band.moveTo(point.dx, point.dy)
            : band.lineTo(point.dx, point.dy);
      }
      for (var index = smoothed.length - 1; index >= 0; index--) {
        final point = pointFor(index, smoothed[index] - variability!);
        band.lineTo(point.dx, point.dy);
      }
      band.close();
      canvas.drawPath(band, Paint()..color = color.withValues(alpha: 0.14));
    }
    if (showRaw) {
      final raw = Path();
      for (var index = 0; index < weights.length; index++) {
        final point = pointFor(index, weights[index]);
        index == 0
            ? raw.moveTo(point.dx, point.dy)
            : raw.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        raw,
        Paint()
          ..color = gridColor
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }
    final path = Path();
    for (var index = 0; index < smoothed.length; index++) {
      final point = pointFor(index, smoothed[index]);
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    final line = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, line);
    final point = Paint()..color = color;
    if (showRaw) {
      for (var index = 0; index < weights.length; index++) {
        canvas.drawCircle(pointFor(index, weights[index]), 3, point);
      }
    }
    canvas.drawCircle(pointFor(smoothed.length - 1, smoothed.last), 5, point);
  }

  @override
  bool shouldRepaint(covariant _WeightTrendPainter oldDelegate) =>
      oldDelegate.weights != weights ||
      oldDelegate.variability != variability ||
      oldDelegate.showRaw != showRaw ||
      oldDelegate.color != color ||
      oldDelegate.gridColor != gridColor;
}
