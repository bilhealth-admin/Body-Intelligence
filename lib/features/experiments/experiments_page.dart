import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/app_localizations.dart';
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
    final t = context.strings.text;
    final experiments = ref.watch(experimentsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t('Personal experiments'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: Text(t('New experiment')),
      ),
      body: experiments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (rows) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  t(
                    'Experiments are structured personal observations, not medical proof. Change one variable when practical and record missing data and limitations.',
                  ),
                ),
              ),
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  t(
                    'No experiment yet. Start with a cautious, measurable question such as whether a consistent protein breakfast affects your reported satiety.',
                  ),
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
                    '${row.status == 'completed' ? '${row.result ?? t('No result recorded')} · ${t(row.confidence)} ${t('confidence')} · ${row.adherence?.toStringAsFixed(0)}% ${t('adherence')}' : '${t('Active')} · ${t('required')}: ${row.requiredData.isEmpty ? t('not specified') : row.requiredData}'}',
                  ),
                  isThreeLine: true,
                  onTap: row.status == 'completed'
                      ? null
                      : () => _complete(context, ref, row.id),
                  trailing: IconButton(
                    tooltip: t('Delete experiment'),
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
    final t = context.strings.text;
    final hypothesis = TextEditingController();
    final variable = TextEditingController();
    final controls = TextEditingController();
    final data = TextEditingController();
    final duration = TextEditingController(text: '14');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('Design an observation')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: hypothesis,
                decoration: InputDecoration(labelText: t('Hypothesis')),
              ),
              TextField(
                controller: variable,
                decoration: InputDecoration(
                  labelText: t('One changed variable'),
                ),
              ),
              TextField(
                controller: controls,
                decoration: InputDecoration(
                  labelText: t('Factors to keep consistent'),
                ),
              ),
              TextField(
                controller: data,
                decoration: InputDecoration(labelText: t('Required data')),
              ),
              TextField(
                controller: duration,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: t('Duration (3–90 days)'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('Start')),
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
    final t = context.strings.text;
    final result = TextEditingController();
    final limitations = TextEditingController();
    final adherence = TextEditingController(text: '80');
    String confidence = 'insufficient';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(t('Record observation')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: result,
                  decoration: InputDecoration(
                    labelText: t('What did you observe?'),
                  ),
                ),
                TextField(
                  controller: adherence,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: t('Adherence (0–100%)'),
                  ),
                ),
                TextField(
                  controller: limitations,
                  decoration: InputDecoration(
                    labelText: t('Missing data and limitations'),
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: confidence,
                  items: [
                    DropdownMenuItem(
                      value: 'insufficient',
                      child: Text(t('Insufficient evidence')),
                    ),
                    DropdownMenuItem(
                      value: 'low',
                      child: Text(t('Low confidence')),
                    ),
                    DropdownMenuItem(
                      value: 'moderate',
                      child: Text(t('Moderate confidence')),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => confidence = value ?? confidence),
                ),
                const SizedBox(height: 8),
                Text(
                  t(
                    'This result is a personal observation, not medical proof.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t('Save observation')),
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
