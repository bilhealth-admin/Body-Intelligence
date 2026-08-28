part of 'meal_image_guide_page.dart';

class MealImageGuidePage extends ConsumerStatefulWidget {
  const MealImageGuidePage({super.key, this.initialPage = 0});

  final int initialPage;

  @override
  ConsumerState<MealImageGuidePage> createState() => _MealImageGuidePageState();
}

class _MealImageGuidePageState extends ConsumerState<MealImageGuidePage> {
  late final PageController _controller;
  late int _page;

  static const _steps = <_MealImageGuideStep>[
    _MealImageGuideStep(
      icon: Icons.center_focus_strong_rounded,
      title: 'step_scan_title',
      body: 'step_scan_body',
      preview: _MealImagePreview.plate,
    ),
    _MealImageGuideStep(
      icon: Icons.checklist_rtl_rounded,
      title: 'step_select_title',
      body: 'step_select_body',
      preview: _MealImagePreview.selection,
    ),
    _MealImageGuideStep(
      icon: Icons.edit_note_rounded,
      title: 'step_add_title',
      body: 'step_add_body',
      preview: _MealImagePreview.search,
    ),
    _MealImageGuideStep(
      icon: Icons.fact_check_outlined,
      title: 'step_review_title',
      body: 'step_review_body',
      preview: _MealImagePreview.review,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage.clamp(0, _steps.length - 1);
    _controller = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final usage = ref.watch(mealVisionUsageProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_mealGuideText(context, 'meal_scan')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_mealGuideText(context, 'not_now')),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _steps.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) =>
                    _GuideStepView(step: _steps[index], stepNumber: index + 1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _steps.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: index == _page ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: index == _page
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _VisionUsageCard(snapshot: usage),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('meal-image-guide-next'),
                      onPressed: usage.asData?.value.canAnalyze == true
                          ? () {
                              if (_page == _steps.length - 1) {
                                Navigator.of(context).pop(true);
                              } else {
                                _controller.nextPage(
                                  duration: const Duration(milliseconds: 240),
                                  curve: Curves.easeOutCubic,
                                );
                              }
                            }
                          : null,
                      child: Text(
                        _page == _steps.length - 1
                            ? _mealGuideText(context, 'choose_photo')
                            : _mealGuideText(context, 'continue'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _mealGuideText(context, 'suggestions_disclaimer'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisionUsageCard extends StatelessWidget {
  const _VisionUsageCard({required this.snapshot});

  final AsyncValue<MealVisionUsageSnapshot> snapshot;

  @override
  Widget build(BuildContext context) {
    final resolved = snapshot.asData?.value;
    final usage = resolved?.usage;
    final exhausted = usage?.exhausted ?? false;
    final text = usage != null
        ? _mealGuideText(
            context,
            exhausted ? 'quota_exhausted' : 'usage',
            values: {
              'used': _mealGuideNumber(context, usage.used),
              'limit': _mealGuideNumber(context, usage.limit),
              'remaining': _mealGuideNumber(context, usage.remaining),
            },
          )
        : _mealGuideText(
            context,
            resolved?.availability == MealVisionUsageAvailability.signedOut
                ? 'usage_signed_out'
                : 'usage_unavailable',
          );
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      key: const Key('meal-vision-usage'),
      label: text,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: exhausted
              ? colors.errorContainer
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              exhausted ? Icons.lock_clock_outlined : Icons.auto_awesome,
              size: 18,
              color: exhausted ? colors.onErrorContainer : colors.primary,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideStepView extends StatelessWidget {
  const _GuideStepView({required this.step, required this.stepNumber});

  final _MealImageGuideStep step;
  final int stepNumber;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
      child: Column(
        children: [
          Text(
            _mealGuideText(
              context,
              'step_progress',
              values: {
                'current': _mealGuideNumber(context, stepNumber),
                'total': _mealGuideNumber(context, 4),
              },
            ),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colors.primary,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 14),
          _MealImagePhonePreview(type: step.preview),
          const SizedBox(height: 26),
          Icon(step.icon, color: colors.primary, size: 30),
          const SizedBox(height: 12),
          Text(
            _mealGuideText(context, step.title),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            _mealGuideText(context, step.body),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

enum _MealImagePreview { plate, selection, search, review }

class _MealImagePhonePreview extends StatelessWidget {
  const _MealImagePhonePreview({required this.type});

  final _MealImagePreview type;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 210,
      // The review and selection previews contain several full-size labels.
      // Give them enough vertical room instead of shrinking accessible text.
      height: 360,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.onSurface,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: ColoredBox(
          color: colors.surface,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: switch (type) {
              _MealImagePreview.plate => _plate(context, colors),
              _MealImagePreview.selection => _selection(context, colors),
              _MealImagePreview.search => _search(context, colors),
              _MealImagePreview.review => _review(context, colors),
            },
          ),
        ),
      ),
    );
  }

  Widget _plate(BuildContext context, ColorScheme colors) => Column(
    children: [
      Text(
        _mealGuideText(context, 'frame_meal'),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      const Spacer(),
      Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.primaryContainer,
          border: Border.all(color: colors.primary, width: 3),
        ),
        child: const Icon(Icons.dinner_dining_rounded, size: 72),
      ),
      const Spacer(),
      const Icon(Icons.camera_alt_rounded, size: 36),
    ],
  );

  Widget _selection(BuildContext context, ColorScheme colors) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        _mealGuideText(context, 'visible_foods'),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 14),
      for (final item in const ['grilled_chicken', 'rice', 'mixed_salad'])
        Card(
          margin: const EdgeInsets.only(bottom: 9),
          child: CheckboxListTile(
            dense: true,
            value: true,
            onChanged: null,
            title: Text(
              _mealGuideText(context, item),
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ),
      const Spacer(),
      Text(
        _mealGuideText(context, 'confirm_visible'),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colors.primary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _search(BuildContext context, ColorScheme colors) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        _mealGuideText(context, 'add_another_food'),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 44,
        child: TextField(
          enabled: false,
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search, size: 18),
            hintText: _mealGuideText(context, 'search_foods'),
          ),
        ),
      ),
      const SizedBox(height: 8),
      for (final item in const [
        'tahini_sauce',
        'sparkling_water',
        'pita_bread',
      ])
        SizedBox(
          height: 46,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.add_circle_outline,
              color: colors.primary,
              size: 20,
            ),
            title: Text(
              _mealGuideText(context, item),
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ),
      const Spacer(),
    ],
  );

  Widget _review(BuildContext context, ColorScheme colors) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        _mealGuideText(context, 'review_meal'),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 14),
      for (final item in const [
        ('chicken', 'trusted_source'),
        ('rice', 'portion_review'),
        ('salad', 'trusted_source'),
      ])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _mealGuideText(context, item.$1),
                      style: const TextStyle(fontSize: 15, height: 1.25),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _mealGuideText(context, item.$2),
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      const Spacer(),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _mealGuideText(context, 'nothing_saved'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}

class _MealImageGuideStep {
  const _MealImageGuideStep({
    required this.icon,
    required this.title,
    required this.body,
    required this.preview,
  });
  final IconData icon;
  final String title;
  final String body;
  final _MealImagePreview preview;
}
