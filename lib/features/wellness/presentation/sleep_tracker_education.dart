part of 'wellness_tools_pages.dart';

extension _SleepTrackerEducation on _SleepTrackerPageState {
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
            onPageChanged: (value) => _updateState(() => educationPage = value),
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
}
