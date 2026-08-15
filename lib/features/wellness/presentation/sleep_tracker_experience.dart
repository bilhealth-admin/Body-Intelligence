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
  bool saving = false;
  bool recordLoading = true;
  Object? recordError;
  int educationPage = 0;
  int insightsRevision = 0;
  late final DateTime recordDate;
  late final TabController tabController;
  late Stream<List<DailyLog>> insightsStream;

  @override
  void initState() {
    super.initState();
    recordDate = DateTime.now();
    tabController = TabController(length: 3, vsync: this);
    insightsStream = ref.read(dailyLogRepositoryProvider).watchAll();
    Future<void>.microtask(_loadRecord);
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
              Tab(text: tr('Log', 'تسجيل')),
              Tab(text: tr('Insights', 'الرؤى')),
              Tab(text: tr('Learn', 'تعلّم')),
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

  Widget _recordTab(DateTime today) => ListView(
    key: const Key('sleep-log-tab'),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
    children: [
      _HeroPanel(
        imageAsset: 'assets/images/brand/generated/sleep_hero_photoreal_v1.png',
        icon: Icons.bedtime_rounded,
        title: tr('Record last night', 'سجّل نوم الليلة الماضية'),
        subtitle: tr(
          'Your real sleep record can inform recovery guidance and Body Twin confidence.',
          'يساعد سجل نومك الحقيقي في فهم التعافي ورفع ثقة التوأم الجسدي.',
        ),
      ),
      const SizedBox(height: 18),
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
            title: Text(tr('Sleep history unavailable', 'سجل النوم غير متاح')),
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
      else
        _sleepEditorCard(),
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed:
            saving || recordLoading || recordError != null || hours == null
            ? null
            : () => _save(today),
        icon: const Icon(Icons.check_rounded),
        label: Text(
          saving ? tr('Saving…', 'جارٍ الحفظ…') : tr('Save sleep', 'حفظ النوم'),
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
  );

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(tr('0 h', '0 س')), Text(tr('14 h', '14 س'))],
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
      final recorded = snapshot.data!
          .where((entry) => entry.sleepHours != null)
          .take(7)
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
                        child: Column(
                          children: [
                            _sleepStageRow(
                              Colors.redAccent,
                              tr('Awake', 'الاستيقاظ'),
                            ),
                            _sleepStageRow(const Color(0xFF9C91FF), 'REM'),
                            _sleepStageRow(
                              const Color(0xFF4747F0),
                              tr('Core', 'الأساسي'),
                            ),
                            _sleepStageRow(
                              const Color(0xFF15158C),
                              tr('Deep', 'العميق'),
                            ),
                          ],
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

  Widget _sleepStageRow(Color color, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Container(
          width: 5,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(child: Text(label)),
        Text(
          tr('N/A', 'غير متاح'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );

  Widget _educationTab() {
    final pages = <({String title, String body, int visual})>[
      (
        title: tr(
          'How does food affect your sleep?',
          'كيف يؤثر الطعام في نومك؟',
        ),
        body: tr(
          'Spot trends, adjust your routine, and sleep well with BIL.',
          'اكتشف الأنماط وعدّل روتينك وحسّن نومك مع BIL.',
        ),
        visual: 0,
      ),
      (
        title: tr(
          "Find out what's keeping you awake",
          'اكتشف ما يبقيك مستيقظًا',
        ),
        body: tr(
          'Your eating and fitness habits might be making it hard to fall asleep and stay asleep.',
          'قد تجعل عاداتك الغذائية والرياضية النوم والاستمرار فيه أكثر صعوبة.',
        ),
        visual: 1,
      ),
      (
        title: tr('Time your meals for the best rest', 'وقّت وجباتك لنوم أفضل'),
        body: tr(
          'When you eat can be as important as what you eat, especially later in the day.',
          'قد يكون توقيت طعامك مهمًا بقدر نوعه، خصوصًا في وقت متأخر من اليوم.',
        ),
        visual: 2,
      ),
    ];
    return Column(
      key: const Key('sleep-learn-tab'),
      children: [
        Expanded(
          child: PageView.builder(
            key: const Key('sleep-education-carousel'),
            itemCount: pages.length,
            onPageChanged: (value) => setState(() => educationPage = value),
            itemBuilder: (context, index) {
              final page = pages[index];
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 30, 22, 24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF17178C), Color(0xFF4545EE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                height: 1.12,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          tr('Illustration only', 'رسم توضيحي فقط'),
                          style: const TextStyle(
                            color: Color(0xFFCCCCE8),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 26),
                        _sleepEducationVisual(page.visual),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    page.body,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            pages.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: index == educationPage ? 28 : 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: index == educationPage
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('sleep-see-my-data'),
              onPressed: () => tabController.animateTo(1),
              child: Text(tr('See my data', 'عرض بياناتي')),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sleepEducationVisual(int visual) => Container(
    height: 260,
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: ExcludeSemantics(
      child: switch (visual) {
        0 => Row(
          children: [
            const Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: CircularProgressIndicator(
                  value: .72,
                  strokeWidth: 14,
                  color: Color(0xFF4545EE),
                  backgroundColor: Color(0xFFE9E9F1),
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: LinearProgressIndicator(
                      value: .42 + index * .12,
                      minHeight: 9,
                      color: const Color(0xFF4545EE),
                      backgroundColor: const Color(0xFFE9E9F1),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        1 => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                tr('Sleep factors', 'عوامل النوم'),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            for (final factor in [
              (tr('Sugar', 'السكر'), .46),
              (tr('Water', 'الماء'), .25),
              (tr('Exercise', 'التمرين'), .67),
            ]) ...[
              Text(
                factor.$1,
                style: const TextStyle(
                  color: Color(0xFF30303A),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              LinearProgressIndicator(
                value: factor.$2,
                minHeight: 10,
                borderRadius: BorderRadius.circular(99),
                color: const Color(0xFF2688FF),
                backgroundColor: const Color(0xFFE9E9F1),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
        _ => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.restaurant_menu_rounded, color: Color(0xFF4545EE)),
            const SizedBox(height: 18),
            for (var index = 0; index < 3; index++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 11,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9E9F1),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(width: 28),
                    const Icon(
                      Icons.circle,
                      size: 10,
                      color: Color(0xFF4545EE),
                    ),
                  ],
                ),
              ),
          ],
        ),
      },
    ),
  );

  // Retained below the reference carousel as reusable evidence copy for future
  // accessibility surfaces; it is intentionally not the primary Learn view.
  // ignore: unused_element
  Widget _legacyEducationTab() => ListView(
    key: const Key('sleep-learn-tab'),
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
    children: [
      _HeroPanel(
        icon: Icons.school_outlined,
        title: tr('Understand your sleep', 'افهم نومك'),
        subtitle: tr(
          'Use recorded patterns as context—not as a diagnosis.',
          'استخدم الأنماط المسجلة كسياق، وليس كتشخيص.',
        ),
      ),
      const SizedBox(height: 16),
      _sleepLesson(
        Icons.restaurant_outlined,
        tr('Food and sleep', 'الطعام والنوم'),
        tr(
          'Large late meals may affect comfort for some people. Record timing and compare your own repeated observations.',
          'قد تؤثر الوجبات الكبيرة المتأخرة في الراحة لدى بعض الأشخاص. سجّل التوقيت وقارن ملاحظاتك المتكررة.',
        ),
      ),
      _sleepLesson(
        Icons.wb_sunny_outlined,
        tr('Morning context', 'سياق الصباح'),
        tr(
          'Sleep duration alone does not explain energy. Activity, stress, illness, and schedule can matter.',
          'مدة النوم وحدها لا تفسر الطاقة. قد يؤثر النشاط والضغط والمرض والجدول.',
        ),
      ),
      _sleepLesson(
        Icons.timeline_rounded,
        tr('Look for repeated patterns', 'ابحث عن أنماط متكررة'),
        tr(
          'One night is not a trend. Use several recorded nights and keep missing days visible.',
          'ليلة واحدة ليست اتجاهًا. استخدم عدة ليالٍ مسجلة وأبقِ الأيام الناقصة ظاهرة.',
        ),
      ),
      const SizedBox(height: 8),
      _SafetyNote(
        text: tr(
          'Seek qualified medical care for persistent sleep problems, breathing concerns, or severe daytime sleepiness.',
          'اطلب رعاية طبية مؤهلة عند استمرار مشاكل النوم أو صعوبات التنفس أو النعاس الشديد نهارًا.',
        ),
      ),
    ],
  );

  Widget _sleepLesson(IconData icon, String title, String body) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(body),
      ),
    ),
  );

  Widget _sleepState(
    IconData icon,
    String title,
    String body, {
    VoidCallback? onRetry,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(tr('Retry', 'إعادة المحاولة')),
            ),
          ],
        ],
      ),
    ),
  );

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
      setState(() => recordedHours = selectedHours);
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
