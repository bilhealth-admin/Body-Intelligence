import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../engine/weight_analysis.dart';
import '../weight/providers/weight_provider.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    WeightEntry? entry,
  ]) async {
    final controller = TextEditingController(
      text: entry?.weight.toStringAsFixed(1),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(entry == null ? 'Add weight' : 'Edit weight'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Weight (kg)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete weight?'),
        content: Text(
          'Delete ${entry.weight.toStringAsFixed(1)} kg from history?',
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
    return Scaffold(
      appBar: AppBar(title: const Text('Weight history')),
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
                  title: const Text('Seven-day trend'),
                  subtitle: Text(
                    trend == null
                        ? 'More data needed'
                        : '${trend.toStringAsFixed(2)} kg',
                  ),
                ),
              ),
              ...rows.map(
                (entry) => Card(
                  child: ListTile(
                    title: Text('${entry.weight.toStringAsFixed(1)} kg'),
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
