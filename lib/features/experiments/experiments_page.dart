import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/app_localizations.dart';
import '../../data/database/app_database.dart';
import '../../data/database/database_provider.dart';
import '../../data/repositories/experiment_repository.dart';
import '../../shared/widgets/secondary_page_app_bar.dart';
import '../intelligence_center/services/coach_context_provider.dart';

part 'experiments_components.dart';

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
      appBar: SecondaryPageAppBar(title: Text(t('BIL experiments'))),
      body: experiments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 42),
                const SizedBox(height: 12),
                Text(
                  t('Your saved data was not changed. Try again.'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(experimentsProvider),
                  child: Text(t('Retry')),
                ),
              ],
            ),
          ),
        ),
        data: (rows) {
          final active = rows
              .where((row) => row.status == 'active')
              .firstOrNull;
          final completed = rows
              .where((row) => row.status == 'completed')
              .toList(growable: false);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
            children: [
              _ExperimentHero(active: active),
              const SizedBox(height: 18),
              if (active != null)
                _ActiveExperimentCard(
                  experiment: active,
                  onComplete: () => _complete(context, ref, active.id),
                  onDelete: () => _delete(context, ref, active.id),
                )
              else ...[
                Text(
                  t('Choose one thing to learn this week'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  t(
                    'BIL changes one practical variable, watches your own records, then helps you decide whether it is worth keeping.',
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                for (final preset in _ExperimentPreset.defaults(t))
                  _PresetCard(
                    preset: preset,
                    onStart: () => _startPreset(context, ref, preset),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _createCustom(context, ref),
                  icon: const Icon(Icons.tune_rounded),
                  label: Text(t('Design a custom experiment')),
                ),
              ],
              if (completed.isNotEmpty) ...[
                const SizedBox(height: 26),
                Text(
                  t('What BIL learned'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                for (final row in completed)
                  _CompletedExperimentCard(
                    experiment: row,
                    onDelete: () => _delete(context, ref, row.id),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _startPreset(
    BuildContext context,
    WidgetRef ref,
    _ExperimentPreset preset,
  ) async {
    final t = context.strings.text;
    var duration = 7;
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(radius: 27, child: Icon(preset.icon, size: 27)),
                const SizedBox(height: 14),
                Text(
                  preset.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(preset.hypothesis, style: const TextStyle(height: 1.45)),
                const SizedBox(height: 18),
                Text(
                  t('How long should BIL observe?'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                _DurationPicker(
                  value: duration,
                  onChanged: (value) => setState(() => duration = value),
                ),
                const SizedBox(height: 16),
                _ExperimentDetail(
                  icon: Icons.swap_horiz_rounded,
                  title: t('Change'),
                  value: preset.variable,
                ),
                _ExperimentDetail(
                  icon: Icons.fact_check_outlined,
                  title: t('BIL watches'),
                  value: preset.requiredData,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(t('Start my experiment')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (accepted != true || !context.mounted) return;
    await _create(
      context,
      ref,
      hypothesis: preset.hypothesis,
      changedVariable: preset.variable,
      controlledFactors: preset.controls,
      requiredData: preset.requiredData,
      durationDays: duration,
    );
  }

  Future<void> _createCustom(BuildContext context, WidgetRef ref) async {
    final t = context.strings.text;
    final hypothesis = TextEditingController();
    final variable = TextEditingController();
    final data = TextEditingController();
    var duration = 7;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            4,
            22,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('Design one clear experiment'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: hypothesis,
                  decoration: InputDecoration(
                    labelText: t('What do you want to learn?'),
                    hintText: t(
                      'Example: Does an earlier dinner improve my sleep?',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: variable,
                  decoration: InputDecoration(
                    labelText: t('The one change you will make'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: data,
                  decoration: InputDecoration(
                    labelText: t('What should BIL watch?'),
                  ),
                ),
                const SizedBox(height: 14),
                _DurationPicker(
                  value: duration,
                  onChanged: (value) => setState(() => duration = value),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    child: Text(t('Start my experiment')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed == true && context.mounted) {
      await _create(
        context,
        ref,
        hypothesis: hypothesis.text,
        changedVariable: variable.text,
        controlledFactors: t(
          'Keep the rest of the routine as consistent as practical',
        ),
        requiredData: data.text,
        durationDays: duration,
      );
    }
    hypothesis.dispose();
    variable.dispose();
    data.dispose();
  }

  Future<void> _create(
    BuildContext context,
    WidgetRef ref, {
    required String hypothesis,
    required String changedVariable,
    required String controlledFactors,
    required String requiredData,
    required int durationDays,
  }) async {
    final t = context.strings.text;
    try {
      await ref
          .read(experimentRepositoryProvider)
          .create(
            hypothesis: hypothesis,
            changedVariable: changedVariable,
            controlledFactors: controlledFactors,
            requiredData: requiredData,
            startedAt: DateTime.now(),
            durationDays: durationDays,
          );
      ref.invalidate(coachContextSnapshotProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t('Experiment started. BIL will use it in daily decisions.'),
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (!context.mounted) return;
      final message = error is StateError
          ? t('Finish your active experiment before starting another.')
          : error is ArgumentError
          ? (error.message?.toString() ?? t('Check the experiment details.'))
          : t('The experiment could not be started.');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _complete(BuildContext context, WidgetRef ref, int id) async {
    final t = context.strings.text;
    final result = TextEditingController();
    final limitations = TextEditingController();
    var adherence = 80.0;
    String confidence = 'low';
    final saved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            4,
            22,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('What did your body show?'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: result,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: t('Your observation'),
                    hintText: t(
                      'What improved, stayed the same, or became harder?',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '${t('How closely did you follow it?')} ${adherence.round()}%',
                ),
                Slider(
                  value: adherence,
                  divisions: 10,
                  label: '${adherence.round()}%',
                  onChanged: (value) => setState(() => adherence = value),
                ),
                DropdownButtonFormField<String>(
                  initialValue: confidence,
                  decoration: InputDecoration(
                    labelText: t('How clear was the pattern?'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'insufficient',
                      child: Text(t('Not clear yet')),
                    ),
                    DropdownMenuItem(
                      value: 'low',
                      child: Text(t('A weak signal')),
                    ),
                    DropdownMenuItem(
                      value: 'moderate',
                      child: Text(t('A repeatable signal')),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => confidence = value ?? confidence),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: limitations,
                  decoration: InputDecoration(
                    labelText: t('Anything that affected the result?'),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    child: Text(t('Save what BIL learned')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true) {
      await ref
          .read(experimentRepositoryProvider)
          .complete(
            id: id,
            adherence: adherence,
            result: result.text.trim().isEmpty
                ? t('No clear change observed')
                : result.text,
            limitations: limitations.text,
            confidence: confidence,
          );
      ref.invalidate(coachContextSnapshotProvider);
    }
    result.dispose();
    limitations.dispose();
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, int id) async {
    final t = context.strings.text;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('Delete this experiment?')),
        content: Text(t('It will no longer guide BIL decisions.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('Keep')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(experimentRepositoryProvider).delete(id);
    ref.invalidate(coachContextSnapshotProvider);
  }
}
