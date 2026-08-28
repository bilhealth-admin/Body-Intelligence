part of 'experiments_page.dart';

class _ExperimentHero extends StatelessWidget {
  const _ExperimentHero({required this.active});
  final PersonalExperiment? active;

  @override
  Widget build(BuildContext context) {
    final t = context.strings.text;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primaryContainer, scheme.tertiaryContainer],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_rounded, color: scheme.primary, size: 34),
          const SizedBox(height: 14),
          Text(
            active == null
                ? t('Learn what works for your body')
                : t('BIL is observing one change'),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            active == null
                ? t(
                    'A few useful days can guide a practical decision. Longer history simply makes the signal stronger.',
                  )
                : t(
                    'Keep the change simple. Continue logging normally and BIL will carry the context into Coach replies.',
                  ),
            style: const TextStyle(height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _ActiveExperimentCard extends StatelessWidget {
  const _ActiveExperimentCard({
    required this.experiment,
    required this.onComplete,
    required this.onDelete,
  });
  final PersonalExperiment experiment;
  final VoidCallback onComplete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.strings.text;
    final scheme = Theme.of(context).colorScheme;
    final total = experiment.endsAt.difference(experiment.startedAt).inDays + 1;
    final elapsed = DateTime.now().difference(experiment.startedAt).inDays + 1;
    final progress = (elapsed / total).clamp(0.0, 1.0);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t('Active experiment'),
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: t('Delete experiment'),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            Text(
              experiment.hypothesis,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              borderRadius: BorderRadius.circular(9),
            ),
            const SizedBox(height: 7),
            Text(
              '${t('Day')} ${elapsed.clamp(1, total)} ${t('of')} $total',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 15),
            _ExperimentDetail(
              icon: Icons.swap_horiz_rounded,
              title: t('Change'),
              value: experiment.changedVariable,
            ),
            _ExperimentDetail(
              icon: Icons.fact_check_outlined,
              title: t('BIL watches'),
              value: experiment.requiredData,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onComplete,
                icon: const Icon(Icons.done_rounded),
                label: Text(t('Record what happened')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedExperimentCard extends StatelessWidget {
  const _CompletedExperimentCard({
    required this.experiment,
    required this.onDelete,
  });
  final PersonalExperiment experiment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.strings.text;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        leading: const CircleAvatar(child: Icon(Icons.check_rounded)),
        title: Text(
          experiment.hypothesis,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          experiment.result?.trim().isNotEmpty == true
              ? experiment.result!
              : t('No clear change observed'),
        ),
        trailing: IconButton(
          tooltip: t('Delete experiment'),
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({required this.preset, required this.onStart});
  final _ExperimentPreset preset;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final t = context.strings.text;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 11),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onStart,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(preset.icon, color: scheme.primary),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      preset.subtitle,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Text(
                    t('7 days'),
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DurationPicker extends StatelessWidget {
  const _DurationPicker({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.strings.text;
    return SegmentedButton<int>(
      segments: [
        ButtonSegment(value: 3, label: Text(t('3 days'))),
        ButtonSegment(value: 7, label: Text(t('7 days'))),
        ButtonSegment(value: 14, label: Text(t('14 days'))),
      ],
      selected: {value},
      onSelectionChanged: (values) => onChanged(values.single),
    );
  }
}

class _ExperimentDetail extends StatelessWidget {
  const _ExperimentDetail({
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 9),
        Expanded(child: Text('$title: $value')),
      ],
    ),
  );
}

class _ExperimentPreset {
  const _ExperimentPreset({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.hypothesis,
    required this.variable,
    required this.controls,
    required this.requiredData,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String hypothesis;
  final String variable;
  final String controls;
  final String requiredData;

  static List<_ExperimentPreset> defaults(String Function(String) t) => [
    _ExperimentPreset(
      icon: Icons.egg_alt_outlined,
      title: t('Protein-first breakfast'),
      subtitle: t('Learn whether mornings feel steadier'),
      hypothesis: t(
        'A protein-first breakfast may improve my satiety and energy through the morning.',
      ),
      variable: t('Start breakfast with a consistent protein source'),
      controls: t(
        'Keep breakfast time and normal activity reasonably consistent',
      ),
      requiredData: t('Breakfast, hunger, energy, and daily nutrition logs'),
    ),
    _ExperimentPreset(
      icon: Icons.bedtime_outlined,
      title: t('Consistent sleep window'),
      subtitle: t('Test recovery without chasing one night'),
      hypothesis: t(
        'A consistent sleep window may improve my reported energy and recovery.',
      ),
      variable: t('Use the same bedtime window each night'),
      controls: t('Keep caffeine timing and training reasonably consistent'),
      requiredData: t('Sleep hours, energy, and activity logs'),
    ),
    _ExperimentPreset(
      icon: Icons.directions_walk_rounded,
      title: t('Walk after dinner'),
      subtitle: t('Observe digestion, sleep, and consistency'),
      hypothesis: t(
        'A short walk after dinner may improve how I feel later in the evening.',
      ),
      variable: t('Take a 10-minute walk after dinner'),
      controls: t('Keep dinner timing and portion broadly comparable'),
      requiredData: t('Dinner, activity, sleep, and how you felt'),
    ),
  ];
}
