import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../app/localization/app_localizations.dart';
import '../../core/units/measurement_units.dart';
import '../../engine/weight_analysis.dart';
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
          title: Text(entry == null ? 'Add weight' : 'Edit weight'),
          content: SizedBox(
            width: 440,
            child: WheelNumberField(
              value: displayed,
              minimum: UnitConverter.weightFromKg(20, system),
              maximum: UnitConverter.weightFromKg(350, system),
              step: system == MeasurementSystem.metric ? 0.1 : 0.2,
              decimalPlaces: 1,
              unit: UnitConverter.weightUnit(system),
              label: context.strings.text('Weight'),
              onChanged: (next) => setDialogState(() => displayed = next),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                UnitConverter.weightToKg(displayed, system),
              ),
              child: const Text('Save'),
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
        title: const Text('Delete weight?'),
        content: Text(
          'Delete ${displayed.toStringAsFixed(1)} ${UnitConverter.weightUnit(system)} from history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
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
        onPressed: () => _edit(context, ref),
        child: const Icon(Icons.add),
      ),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load weight history: $error')),
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(child: Text('No weight entries yet.'));
          }
          final chronological = rows.reversed.toList();
          final trend = WeightAnalysis.calculateWeeklyTrend(
            chronological.map((row) => row.weight).toList(),
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Card(
                child: ListTile(
                  title: Text(context.strings.text('Seven-day trend')),
                  subtitle: Text(
                    trend == null
                        ? 'More data needed'
                        : '${UnitConverter.weightFromKg(trend, system).toStringAsFixed(2)} $unit',
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
