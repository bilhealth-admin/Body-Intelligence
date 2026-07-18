import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../app/localization/app_localizations.dart';
import '../../core/units/measurement_units.dart';
import '../../engine/weight_analysis.dart';
import '../../engine/intelligence_engine.dart';
import '../../shared/widgets/wheel_number_field.dart';
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
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            context.strings.text(entry == null ? 'Add weight' : 'Edit weight'),
          ),
          content: SizedBox(
            width: 440,
            child: WheelNumberField(
              value: displayed,
              minimum: UnitConverter.weightFromKg(20, system),
              maximum: UnitConverter.weightFromKg(350, system),
              step: UnitConverter.weightStep(system),
              decimalPlaces: 1,
              unit: UnitConverter.weightUnit(system),
              label: context.strings.text('Weight'),
              onChanged: (next) => setDialogState(() => displayed = next),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.strings.text('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                UnitConverter.weightToKg(displayed, system),
              ),
              child: Text(context.strings.text('Save')),
            ),
          ],
        ),
      ),
    );
    if (value == null) return;
    final repository = ref.read(weightRepositoryProvider);
    if (entry == null) {
      await repository.addWeight(value);
    } else {
      await repository.updateWeight(
        id: entry.id,
        weight: value,
        date: entry.date,
        note: entry.note,
        measurementContext: entry.measurementContext,
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
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.text('Weight history'))),
      floatingActionButton: FloatingActionButton(
        tooltip: context.strings.text('Add weight'),
        onPressed: () => _edit(context, ref),
        child: const Icon(Icons.add),
      ),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.strings.text('Could not load weight history')),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => ref.invalidate(weightHistoryProvider),
                icon: const Icon(Icons.refresh),
                label: Text(context.strings.text('Try again')),
              ),
            ],
          ),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Text(context.strings.text('No weight entries yet.')),
            );
          }
          final chronological = rows.reversed.toList();
          final trend = WeightAnalysis.calculateWeeklyTrend(
            chronological.map((row) => row.weight).toList(),
          );
          final smoothed = IntelligenceEngine.weeklyRate(
            chronological.map((row) => row.weight).toList(),
          );
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
                        semanticsLabel: context.strings.text(
                          'Recorded weight trend over time',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${context.strings.text('Seven-day change')}: ${trend == null ? context.strings.text('More data needed') : '${UnitConverter.weightFromKg(trend, system).toStringAsFixed(2)} $unit'}',
                      ),
                      Text(
                        '${context.strings.text('Smoothed weekly direction')}: ${smoothed == null ? context.strings.text('At least four entries needed') : '${smoothed >= 0 ? '+' : ''}${UnitConverter.weightFromKg(smoothed, system).toStringAsFixed(2)} $unit/${context.strings.text('week')}'}',
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

class _WeightTrendChart extends StatelessWidget {
  const _WeightTrendChart({
    required this.weights,
    required this.semanticsLabel,
  });

  final List<double> weights;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticsLabel,
    image: true,
    child: SizedBox(
      height: 150,
      child: CustomPaint(
        painter: _WeightTrendPainter(
          weights: weights,
          color: Theme.of(context).colorScheme.primary,
          gridColor: Theme.of(context).dividerColor,
        ),
      ),
    ),
  );
}

class _WeightTrendPainter extends CustomPainter {
  const _WeightTrendPainter({
    required this.weights,
    required this.color,
    required this.gridColor,
  });

  final List<double> weights;
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
    final path = Path();
    for (var index = 0; index < weights.length; index++) {
      final x = weights.length == 1
          ? size.width / 2
          : size.width * index / (weights.length - 1);
      final y =
          size.height -
          ((weights[index] - minimum) / (maximum - minimum)) * size.height;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
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
    for (var index = 0; index < weights.length; index++) {
      final x = weights.length == 1
          ? size.width / 2
          : size.width * index / (weights.length - 1);
      final y =
          size.height -
          ((weights[index] - minimum) / (maximum - minimum)) * size.height;
      canvas.drawCircle(Offset(x, y), 3.5, point);
    }
  }

  @override
  bool shouldRepaint(covariant _WeightTrendPainter oldDelegate) =>
      oldDelegate.weights != weights ||
      oldDelegate.color != color ||
      oldDelegate.gridColor != gridColor;
}
