import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database_provider.dart';
import '../../data/repositories/experiment_repository.dart';

final experimentRepositoryProvider = Provider<ExperimentRepository>(
  (ref) => ExperimentRepository(ref.watch(databaseProvider)),
);
final experimentsProvider = StreamProvider(
  (ref) => ref.watch(experimentRepositoryProvider).watchAll(),
);

class ExperimentsPage extends ConsumerWidget {
  const ExperimentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final experiments = ref.watch(experimentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Personal experiments')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New experiment'),
      ),
      body: experiments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (rows) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Experiments are structured personal observations, not medical proof. Change one variable when practical and record missing data and limitations.',
                ),
              ),
            ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No experiment yet. Start with a cautious, measurable question such as whether a consistent protein breakfast affects your reported satiety.',
                ),
              ),
            for (final row in rows)
              Card(
                child: ListTile(
                  leading: Icon(
                    row.status == 'completed'
                        ? Icons.science
                        : Icons.science_outlined,
                  ),
                  title: Text(row.hypothesis),
                  subtitle: Text(
                    '${row.changedVariable} · ${row.startedAt.toLocal().toString().split(' ').first} → ${row.endsAt.toLocal().toString().split(' ').first}\n'
                    '${row.status == 'completed' ? '${row.result ?? 'No result recorded'} · ${row.confidence} confidence · ${row.adherence?.toStringAsFixed(0)}% adherence' : 'Active · required: ${row.requiredData.isEmpty ? 'not specified' : row.requiredData}'}',
                  ),
                  isThreeLine: true,
                  onTap: row.status == 'completed'
                      ? null
                      : () => _complete(context, ref, row.id),
                  trailing: IconButton(
                    tooltip: 'Delete experiment',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () =>
                        ref.read(experimentRepositoryProvider).delete(row.id),
                  ),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final hypothesis = TextEditingController();
    final variable = TextEditingController();
    final controls = TextEditingController();
    final data = TextEditingController();
    final duration = TextEditingController(text: '14');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Design an observation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: hypothesis,
                decoration: const InputDecoration(labelText: 'Hypothesis'),
              ),
              TextField(
                controller: variable,
                decoration: const InputDecoration(
                  labelText: 'One changed variable',
                ),
              ),
              TextField(
                controller: controls,
                decoration: const InputDecoration(
                  labelText: 'Factors to keep consistent',
                ),
              ),
              TextField(
                controller: data,
                decoration: const InputDecoration(labelText: 'Required data'),
              ),
              TextField(
                controller: duration,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration (3–90 days)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref
            .read(experimentRepositoryProvider)
            .create(
              hypothesis: hypothesis.text,
              changedVariable: variable.text,
              controlledFactors: controls.text,
              requiredData: data.text,
              startedAt: DateTime.now(),
              durationDays: int.tryParse(duration.text) ?? 14,
            );
      } on ArgumentError catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.message?.toString() ?? error.toString()),
            ),
          );
        }
      }
    }
    hypothesis.dispose();
    variable.dispose();
    controls.dispose();
    data.dispose();
    duration.dispose();
  }

  Future<void> _complete(BuildContext context, WidgetRef ref, int id) async {
    final result = TextEditingController();
    final limitations = TextEditingController();
    final adherence = TextEditingController(text: '80');
    String confidence = 'insufficient';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Record observation'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: result,
                  decoration: const InputDecoration(
                    labelText: 'What did you observe?',
                  ),
                ),
                TextField(
                  controller: adherence,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Adherence (0–100%)',
                  ),
                ),
                TextField(
                  controller: limitations,
                  decoration: const InputDecoration(
                    labelText: 'Missing data and limitations',
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: confidence,
                  items: const [
                    DropdownMenuItem(
                      value: 'insufficient',
                      child: Text('Insufficient evidence'),
                    ),
                    DropdownMenuItem(
                      value: 'low',
                      child: Text('Low confidence'),
                    ),
                    DropdownMenuItem(
                      value: 'moderate',
                      child: Text('Moderate confidence'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => confidence = value ?? confidence),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This result is a personal observation, not medical proof.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save observation'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await ref
          .read(experimentRepositoryProvider)
          .complete(
            id: id,
            adherence: double.tryParse(adherence.text) ?? 0,
            result: result.text,
            limitations: limitations.text,
            confidence: confidence,
          );
    }
    result.dispose();
    limitations.dispose();
    adherence.dispose();
  }
}
