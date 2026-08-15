part of 'wellness_tools_pages.dart';

class _LegacySleepTrackerPage extends ConsumerStatefulWidget {
  const _LegacySleepTrackerPage();

  @override
  ConsumerState<_LegacySleepTrackerPage> createState() =>
      _LegacySleepTrackerPageState();
}

class _LegacySleepTrackerPageState
    extends ConsumerState<_LegacySleepTrackerPage>
    with _WellnessCopy {
  double hours = 7.5;
  bool saving = false;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(tr('Sleep intelligence', 'ذكاء النوم')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          _HeroPanel(
            icon: Icons.bedtime_rounded,
            title: tr('Record last night', 'سجّل نوم الليلة الماضية'),
            subtitle: tr(
              'Your real sleep record can inform recovery guidance and Body Twin confidence.',
              'يساعد سجل نومك الحقيقي في فهم التعافي ورفع ثقة توأم الجسم.',
            ),
          ),
          const SizedBox(height: 18),
          StreamBuilder<DailyLog?>(
            stream: ref.read(dailyLogRepositoryProvider).watchForDay(today),
            builder: (context, snapshot) {
              final recorded = snapshot.data?.sleepHours;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      Text(
                        '${hours.toStringAsFixed(1)} ${tr('hours', 'ساعة')}',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Slider(
                        value: hours,
                        min: 0,
                        max: 14,
                        divisions: 28,
                        label: hours.toStringAsFixed(1),
                        onChanged: (value) => setState(() => hours = value),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(tr('0 h', '0 س')),
                          Text(tr('14 h', '14 س')),
                        ],
                      ),
                      if (recorded != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          tr(
                            'Recorded today: ${recorded.toStringAsFixed(1)} h',
                            'المسجل اليوم: ${recorded.toStringAsFixed(1)} ساعة',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: saving ? null : () => _save(today),
            icon: const Icon(Icons.check_rounded),
            label: Text(
              saving
                  ? tr('Saving…', 'جارٍ الحفظ…')
                  : tr('Save sleep', 'حفظ النوم'),
            ),
          ),
          const SizedBox(height: 18),
          _SafetyNote(
            text: tr(
              'Sleep duration is a personal log, not a medical measurement or diagnosis.',
              'مدة النوم سجل شخصي وليست قياسًا طبيًا أو تشخيصًا.',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(DateTime date) async {
    setState(() => saving = true);
    final repository = ref.read(dailyLogRepositoryProvider);
    final existing = await repository.watchForDay(date).first;
    await repository.save(
      date: date,
      notes: existing?.notes,
      sleepHours: hours,
      steps: existing?.steps,
      exerciseNotes: existing?.exerciseNotes,
    );
    if (!mounted) return;
    setState(() => saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(
            'Sleep saved to today’s health record.',
            'تم حفظ النوم في سجل اليوم الصحي.',
          ),
        ),
      ),
    );
  }
}
