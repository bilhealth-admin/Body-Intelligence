part of 'wellness_tools_pages.dart';

class SleepTrackerPage extends ConsumerStatefulWidget {
  const SleepTrackerPage({super.key});

  @override
  ConsumerState<SleepTrackerPage> createState() => _SleepTrackerPageState();
}

class _SleepTrackerPageState extends ConsumerState<SleepTrackerPage>
    with SingleTickerProviderStateMixin, _WellnessCopy {
  double? hours;
  double? recordedHours;
  DateTime? manualUpdatedAt;
  int insightWindowDays = 7;
  SleepSchedule sleepSchedule = const SleepSchedule.defaults();
  late final SleepScheduleStore sleepScheduleStore;
  bool scheduleLoading = true;
  bool scheduleSaving = false;
  bool saving = false;
  bool recordLoading = true;
  Object? recordError;
  int educationPage = 0;
  int insightsRevision = 0;
  late final DateTime recordDate;
  late final TabController tabController;
  late Stream<List<DailyLog>> insightsStream;

  void _updateState(VoidCallback update) => setState(update);

  @override
  void initState() {
    super.initState();
    recordDate = DateTime.now();
    tabController = TabController(length: 3, vsync: this);
    insightsStream = ref.read(dailyLogRepositoryProvider).watchAll();
    sleepScheduleStore = SleepScheduleStore();
    Future<void>.microtask(_loadRecord);
    Future<void>.microtask(_loadSleepSchedule);
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = recordDate;
    return PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: saving
                ? null
                : () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/wellness-library');
                    }
                  },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(tr('Sleep', 'النوم')),
          bottom: TabBar(
            controller: tabController,
            onTap: (index) {
              if (saving) tabController.index = 0;
            },
            tabs: [
              for (final label in [
                tr('Log', 'تسجيل'),
                tr('Insights', 'الرؤى'),
                tr('Learn', 'تعلّم'),
              ])
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label, maxLines: 1),
                  ),
                ),
            ],
          ),
        ),
        body: TabBarView(
          controller: tabController,
          physics: saving ? const NeverScrollableScrollPhysics() : null,
          children: [_recordTab(today), _insightsTab(), _educationTab()],
        ),
      ),
    );
  }

  Widget _recordTab(DateTime today) {
    final connected = ref.watch(connectedHealthProvider).value;
    final connectedSleep = _connectedSleepEvidence(connected);
    return ListView(
      key: const Key('sleep-log-tab'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        _HeroPanel(
          imageAsset:
              'assets/images/brand/generated/sleep_hero_photoreal_v1.png',
          icon: Icons.bedtime_rounded,
          title: tr('Record last night', 'سجّل نوم الليلة الماضية'),
          subtitle: tr(
            'Your real sleep record can inform recovery guidance and Body Twin confidence.',
            'يساعد سجل نومك الحقيقي في فهم التعافي ورفع ثقة التوأم الجسدي.',
          ),
        ),
        const SizedBox(height: 18),
        if (connectedSleep != null) ...[
          Card(
            key: const Key('sleep-connected-source'),
            child: ListTile(
              leading: const Icon(Icons.watch_rounded),
              title: Text(
                '${connectedSleep.signal.value.toStringAsFixed(1)} ${tr('hours', 'ساعة')}',
              ),
              subtitle: Text(
                '${tr('Measured by', 'مقاس بواسطة')} ${connectedSleep.signal.source} · '
                '${tr('Last sync', 'آخر مزامنة')} ${MaterialLocalizations.of(context).formatShortDate(connectedSleep.lastSyncAt)}',
              ),
              trailing: const Icon(Icons.verified_rounded, color: Colors.green),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              tr(
                'Connected sleep is the source for this night. Manual entry remains a fallback when no measured record is available.',
                'النوم المتصل هو مصدر هذه الليلة. يبقى الإدخال اليدوي بديلًا عند غياب سجل مقاس.',
              ),
            ),
          ),
          if (connectedSleep.measuredStages.isNotEmpty) ...[
            const SizedBox(height: 10),
            Card(
              key: const Key('sleep-measured-stages'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Sleep', 'النوم'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final stage in connectedSleep.measuredStages)
                          Chip(label: Text(stage)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr(
                        'Sleep stages appear only when a connected device supplies measured stage records.',
                        'تظهر مراحل النوم فقط عندما يرسل جهاز متصل سجلات مراحل مقاسة.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
        ],
        if (recordLoading)
          const Card(
            child: SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (recordError != null)
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(20),
              leading: const Icon(Icons.error_outline_rounded),
              title: Text(
                tr('Sleep history unavailable', 'سجل النوم غير متاح'),
              ),
              subtitle: Text(
                tr(
                  'Your saved data was not changed. Try again.',
                  'لم تتغير بياناتك المحفوظة. حاول مجددًا.',
                ),
              ),
              trailing: TextButton(
                onPressed: _loadRecord,
                child: Text(tr('Retry', 'إعادة المحاولة')),
              ),
            ),
          )
        else if (connectedSleep == null)
          _sleepEditorCard(),
        if (connectedSleep == null && recordedHours != null) ...[
          const SizedBox(height: 10),
          Card(
            key: const Key('sleep-manual-source'),
            child: ListTile(
              leading: const Icon(Icons.edit_note_rounded),
              title: Text('${tr('Source', 'المصدر')}: ${tr('Manual', 'يدوي')}'),
              subtitle: Text(
                manualUpdatedAt == null
                    ? tr('Updated locally', 'محدّث محليًا')
                    : '${tr('Updated locally', 'محدّث محليًا')} · '
                          '${MaterialLocalizations.of(context).formatShortDate(manualUpdatedAt!.toLocal())} '
                          '${TimeOfDay.fromDateTime(manualUpdatedAt!.toLocal()).format(context)}',
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (connectedSleep == null)
          FilledButton.icon(
            onPressed:
                saving || recordLoading || recordError != null || hours == null
                ? null
                : () => _save(today),
            icon: const Icon(Icons.check_rounded),
            label: Text(
              saving
                  ? tr('Saving…', 'جارٍ الحفظ…')
                  : tr('Save sleep', 'حفظ النوم'),
            ),
          ),
        const SizedBox(height: 18),
        _sleepScheduleCard(),
        const SizedBox(height: 18),
        _SafetyNote(
          text: tr(
            'Sleep duration is a personal log, not a medical measurement or diagnosis.',
            'مدة النوم سجل شخصي وليست قياسًا طبيًا أو تشخيصًا.',
          ),
        ),
      ],
    );
  }

  _ConnectedSleepEvidence? _connectedSleepEvidence(
    ConnectedHealthSnapshot? snapshot,
  ) {
    if (snapshot == null || !snapshot.deviceVerified) return null;
    ConnectedHealthSignalView? latest;
    for (final signal in snapshot.signals) {
      if (signal.key != 'sleep' ||
          !signal.value.isFinite ||
          signal.value <= 0 ||
          signal.value > 14) {
        continue;
      }
      if (latest == null || signal.observedAt.isAfter(latest.observedAt)) {
        latest = signal;
      }
    }
    final sync = snapshot.lastSyncAt;
    if (latest == null || sync == null) return null;
    if (DateTime.now().difference(latest.observedAt.toLocal()).inHours > 36) {
      return null;
    }
    return _ConnectedSleepEvidence(signal: latest, lastSyncAt: sync);
  }

  Widget _sleepEditorCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Text(
            hours == null
                ? tr('N/A', 'غير متاح')
                : '${hours!.toStringAsFixed(1)} ${tr('hours', 'ساعة')}',
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          Slider(
            value: hours ?? 7.5,
            min: 0,
            max: 14,
            divisions: 28,
            label: hours?.toStringAsFixed(1),
            onChanged: saving ? null : (value) => setState(() => hours = value),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  tr('0 h', '0 س'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                ),
              ),
              Expanded(
                child: Text(
                  tr('14 h', '14 س'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          if (recordedHours != null) ...[
            const SizedBox(height: 12),
            Text(
              tr(
                'Recorded today: ${recordedHours!.toStringAsFixed(1)} h',
                'المسجل اليوم: ${recordedHours!.toStringAsFixed(1)} ساعة',
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _sleepScheduleCard() {
    final material = MaterialLocalizations.of(context);
    final scheduleLabels = bilSleepScheduleLabels(
      Localizations.localeOf(context).toLanguageTag(),
    );
    String formatTime(int hour, int minute) =>
        material.formatTimeOfDay(TimeOfDay(hour: hour, minute: minute));
    final goalHours = sleepSchedule.goalMinutes / 60;
    return Card(
      key: const Key('sleep-schedule-card'),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            key: const Key('sleep-schedule-toggle'),
            secondary: const Icon(Icons.notifications_active_outlined),
            title: Text(
              '${tr('Sleep', 'النوم')} · ${tr('Daily reminders', 'التذكيرات اليومية')}',
            ),
            value: sleepSchedule.enabled,
            onChanged: scheduleLoading || scheduleSaving
                ? null
                : _setSleepScheduleEnabled,
          ),
          const Divider(height: 1),
          ListTile(
            enabled: !scheduleLoading && !scheduleSaving,
            leading: const Icon(Icons.bedtime_outlined),
            title: Text(scheduleLabels.$1),
            trailing: Text(
              formatTime(sleepSchedule.bedHour, sleepSchedule.bedMinute),
            ),
            onTap: () => _chooseSleepTime(wake: false),
          ),
          ListTile(
            enabled: !scheduleLoading && !scheduleSaving,
            leading: const Icon(Icons.wb_sunny_outlined),
            title: Text(scheduleLabels.$2),
            trailing: Text(
              formatTime(sleepSchedule.wakeHour, sleepSchedule.wakeMinute),
            ),
            onTap: () => _chooseSleepTime(wake: true),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text('${tr('Sleep', 'النوم')} · ${tr('Goal', 'الهدف')}'),
            subtitle: Text(
              '${goalHours.toStringAsFixed(goalHours % 1 == 0 ? 0 : 1)} ${tr('hours', 'ساعة')}',
            ),
            trailing: PopupMenuButton<int>(
              enabled: !scheduleLoading && !scheduleSaving,
              tooltip: tr('Goal', 'الهدف'),
              onSelected: (minutes) => _saveSleepSchedule(
                sleepSchedule.copyWith(goalMinutes: minutes),
              ),
              itemBuilder: (_) => [
                for (final minutes in const [360, 420, 450, 480, 540])
                  PopupMenuItem(
                    value: minutes,
                    child: Text(
                      '${(minutes / 60).toStringAsFixed(minutes % 60 == 0 ? 0 : 1)} ${tr('hours', 'ساعة')}',
                    ),
                  ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.nights_stay_outlined),
            title: Text('${tr('Sleep', 'النوم')} · ${tr('Reminder', 'تذكير')}'),
            subtitle: Text(
              tr(
                '${sleepSchedule.windDownMinutes} min',
                '${sleepSchedule.windDownMinutes} د',
              ),
            ),
            trailing: PopupMenuButton<int>(
              enabled: !scheduleLoading && !scheduleSaving,
              tooltip: tr('Time', 'الوقت'),
              onSelected: (minutes) => _saveSleepSchedule(
                sleepSchedule.copyWith(windDownMinutes: minutes),
              ),
              itemBuilder: (_) => [
                for (final minutes in const [15, 30, 45, 60])
                  PopupMenuItem(
                    value: minutes,
                    child: Text(tr('$minutes min', '$minutes د')),
                  ),
              ],
            ),
          ),
          if (scheduleSaving)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _insightsTab() => StreamBuilder<List<DailyLog>>(
    key: ValueKey(insightsRevision),
    stream: insightsStream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _sleepState(
          Icons.error_outline_rounded,
          tr('Sleep history unavailable', 'سجل النوم غير متاح'),
          tr(
            'Your saved data was not changed. Try again.',
            'لم تتغير بياناتك المحفوظة. حاول مجددًا.',
          ),
          onRetry: () => setState(() {
            insightsRevision++;
            insightsStream = ref.read(dailyLogRepositoryProvider).watchAll();
          }),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final cutoff = DateTime.now().subtract(Duration(days: insightWindowDays));
      final recorded = snapshot.data!
          .where(
            (entry) => entry.sleepHours != null && !entry.date.isBefore(cutoff),
          )
          .take(insightWindowDays)
          .toList()
          .reversed
          .toList();
      final average = recorded.isEmpty
          ? null
          : recorded.fold<double>(0, (sum, entry) => sum + entry.sleepHours!) /
                recorded.length;
      final latest = recorded.isEmpty ? null : recorded.last;
      return ListView(
        key: const Key('sleep-insights-tab'),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SegmentedButton<int>(
              key: const Key('sleep-insight-window'),
              segments: [
                ButtonSegment(value: 7, label: Text(tr('7 days', '7 أيام'))),
                ButtonSegment(
                  value: 30,
                  label: Text(tr('30 days', '30 يومًا')),
                ),
              ],
              selected: <int>{insightWindowDays},
              onSelectionChanged: (selection) =>
                  setState(() => insightWindowDays = selection.single),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            key: const Key('sleep-stage-overview'),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 142,
                        height: 142,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const SizedBox.expand(
                              child: CircularProgressIndicator(
                                value: 1,
                                strokeWidth: 12,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bedtime_outlined),
                                Text(
                                  latest == null
                                      ? 'N/A'
                                      : '${latest.sleepHours!.floor()}h ${((latest.sleepHours! % 1) * 60).round()}m',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Text(tr('Total sleep', 'إجمالي النوم')),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Text(
                          tr(
                            'Sleep stages appear only when a connected device supplies measured stage records.',
                            'تظهر مراحل النوم فقط عندما يرسل جهاز متصل سجلات مراحل مقاسة.',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF17178C), Color(0xFF4747F0)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('Psst… are you awake?', 'هل ما زلت مستيقظًا؟'),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tr(
                            'Connect a supported health source to import measured sleep stages. BIL never invents them.',
                            'اربط مصدرًا صحيًا مدعومًا لاستيراد مراحل النوم المقاسة. لا يخترعها BIL.',
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                        TextButton(
                          onPressed: () => context.push('/connected-health'),
                          child: Text(
                            tr('Connect health data', 'ربط البيانات الصحية'),
                            style: const TextStyle(color: Color(0xFFFFD55C)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.menu_book_outlined),
                    title: Text(
                      tr(
                        'Review meals alongside sleep',
                        'راجع الوجبات بجانب النوم',
                      ),
                    ),
                    subtitle: Text(
                      tr(
                        'Open Daily Log to review meal timing alongside saved sleep. This does not establish causation.',
                        'افتح السجل اليومي لمراجعة توقيت الوجبات بجانب النوم المحفوظ. هذا لا يثبت السببية.',
                      ),
                    ),
                    trailing: IconButton(
                      onPressed: () => context.push('/daily-log'),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (recorded.isEmpty)
            _sleepState(
              Icons.insights_outlined,
              tr('No sleep trend yet', 'لا يوجد اتجاه للنوم بعد'),
              tr(
                'Record sleep to build a recorded trend. Missing days stay missing.',
                'سجّل نومك لبناء اتجاه مسجل. تبقى الأيام الناقصة ناقصة.',
              ),
            )
          else ...[
            _HeroPanel(
              icon: Icons.insights_rounded,
              title: tr('Your recorded sleep', 'نومك المسجل'),
              subtitle: tr(
                '${recorded.length} recorded nights · ${average!.toStringAsFixed(1)} h average',
                '${recorded.length} ليالٍ مسجلة · متوسط ${average.toStringAsFixed(1)} ساعة',
              ),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
                child: SizedBox(
                  height: 190,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final entry in recorded)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(entry.sleepHours!.toStringAsFixed(1)),
                                const SizedBox(height: 6),
                                Container(
                                  height: (entry.sleepHours! / 14 * 120).clamp(
                                    6,
                                    120,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(8),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  '${entry.date.day}/${entry.date.month}',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _SafetyNote(
              text: tr(
                'Only saved nights are shown. BIL does not estimate missing nights or diagnose sleep conditions.',
                'تظهر الليالي المحفوظة فقط. لا يقدّر BIL الليالي الناقصة ولا يشخّص اضطرابات النوم.',
              ),
            ),
          ],
        ],
      );
    },
  );

  Future<void> _loadSleepSchedule() async {
    final value = await sleepScheduleStore.load();
    if (!mounted) return;
    setState(() {
      sleepSchedule = value;
      scheduleLoading = false;
    });
  }

  Future<void> _setSleepScheduleEnabled(bool enabled) async {
    if (scheduleSaving) return;
    if (enabled) {
      try {
        final allowed = await ref
            .read(fastingNotificationServiceProvider)
            .requestPermission();
        if (!mounted) return;
        if (!allowed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr(
                  'Notification permission is off. You can enable it in phone settings.',
                  'إذن الإشعارات متوقف. يمكنك تفعيله من إعدادات الهاتف.',
                ),
              ),
              action: SnackBarAction(
                label: tr('Settings', 'الإعدادات'),
                onPressed: () => ref
                    .read(fastingNotificationServiceProvider)
                    .openSystemSettings(),
              ),
            ),
          );
          return;
        }
      } on Object {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'Notification permission is off. You can enable it in phone settings.',
                'إذن الإشعارات متوقف. يمكنك تفعيله من إعدادات الهاتف.',
              ),
            ),
          ),
        );
        return;
      }
    }
    await _saveSleepSchedule(sleepSchedule.copyWith(enabled: enabled));
  }

  Future<void> _chooseSleepTime({required bool wake}) async {
    final initial = TimeOfDay(
      hour: wake ? sleepSchedule.wakeHour : sleepSchedule.bedHour,
      minute: wake ? sleepSchedule.wakeMinute : sleepSchedule.bedMinute,
    );
    final selected = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (selected == null || !mounted) return;
    await _saveSleepSchedule(
      wake
          ? sleepSchedule.copyWith(
              wakeHour: selected.hour,
              wakeMinute: selected.minute,
            )
          : sleepSchedule.copyWith(
              bedHour: selected.hour,
              bedMinute: selected.minute,
            ),
    );
  }

  Future<void> _saveSleepSchedule(SleepSchedule value) async {
    if (scheduleSaving) return;
    final languageCode = Localizations.localeOf(context).languageCode;
    setState(() => scheduleSaving = true);
    try {
      await sleepScheduleStore.save(value);
      final notifications = ref.read(fastingNotificationServiceProvider);
      if (value.enabled) {
        await notifications.scheduleSleepSchedule(
          bedHour: value.bedHour,
          bedMinute: value.bedMinute,
          wakeHour: value.wakeHour,
          wakeMinute: value.wakeMinute,
          windDownMinutes: value.windDownMinutes,
          languageCode: languageCode,
        );
      } else {
        await notifications.cancelSleepSchedule();
      }
      if (!mounted) return;
      setState(() => sleepSchedule = value);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'The notification preference could not be saved.',
              'تعذر حفظ تفضيل الإشعار.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => scheduleSaving = false);
    }
  }

  Future<void> _loadRecord() async {
    if (mounted) {
      setState(() {
        recordLoading = true;
        recordError = null;
      });
    }
    try {
      final record = await ref
          .read(dailyLogRepositoryProvider)
          .getForDay(recordDate);
      if (!mounted) return;
      setState(() {
        recordedHours = record?.sleepHours;
        hours = record?.sleepHours;
        manualUpdatedAt = record?.sleepHours == null ? null : record?.updatedAt;
        recordLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        recordError = error;
        recordLoading = false;
      });
    }
  }

  Future<void> _save(DateTime date) async {
    final selectedHours = hours;
    if (saving || selectedHours == null) return;
    setState(() => saving = true);
    try {
      final repository = ref.read(dailyLogRepositoryProvider);
      await repository.updateSleepHours(date: date, sleepHours: selectedHours);
      if (!mounted) return;
      final saved = await repository.getForDay(date);
      if (!mounted) return;
      setState(() {
        recordedHours = selectedHours;
        manualUpdatedAt = saved?.updatedAt ?? DateTime.now();
      });
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Your saved data was not changed. Try again.',
              'لم تتغير بياناتك المحفوظة. حاول مجددًا.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

final class _ConnectedSleepEvidence {
  const _ConnectedSleepEvidence({
    required this.signal,
    required this.lastSyncAt,
  });

  final ConnectedHealthSignalView signal;
  final DateTime lastSyncAt;

  List<String> get measuredStages {
    final raw =
        signal.attributes['measuredStages'] ?? signal.attributes['stages'];
    if (raw is! List) return const <String>[];
    final result = <String>{};
    for (final value in raw) {
      final stage = value is Map
          ? value['stage']?.toString()
          : value?.toString();
      if (stage == null || stage.trim().isEmpty) continue;
      final normalized = stage.trim();
      if (const {
        'awake',
        'inBed',
        'unknown',
        'unspecified',
      }.contains(normalized)) {
        continue;
      }
      result.add(normalized);
    }
    return result.toList(growable: false);
  }
}
