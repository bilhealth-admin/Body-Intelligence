part of 'bil_smart_plan_page.dart';

/// A real, bounded session over the saved movement order. Step checks are
/// temporary progress, never diary writes. Finishing returns to the existing
/// explicit actual-duration confirmation and atomic recording service.
class BilSmartPlanSessionPage extends ConsumerStatefulWidget {
  const BilSmartPlanSessionPage({
    super.key,
    required this.plan,
    required this.day,
    required this.checkAccess,
    required this.loadItems,
    required this.openExercise,
  });
  final BilSmartPlan plan;
  final BilPlanDay day;
  final void Function() checkAccess;
  final Future<List<WellnessContentItem>> Function(String locale) loadItems;
  final Future<void> Function(String id) openExercise;
  @override
  ConsumerState<BilSmartPlanSessionPage> createState() =>
      _BilSmartPlanSessionState();
}

class _BilSmartPlanSessionState extends ConsumerState<BilSmartPlanSessionPage> {
  Future<List<WellnessContentItem>>? _load;
  String? _locale;
  int _step = 0;
  final Set<String> _reviewed = {};
  bool _opening = false;
  bool _warmupReviewed = false;
  List<BilPlanWarmupStep> _warmups = const [];
  final _warmupTitles = <String, String>{};
  final _doses = <String, BilPlanExercisePrescription>{};
  String _rangeForDirection(String value) => value.replaceAllMapped(
    RegExp(r'\d+(?:-\d+)?'),
    (match) => '\u2066${match.group(0)}\u2069',
  );
  bool _allowed() {
    try {
      widget.checkAccess();
      return ref.read(verifiedEntitlementOwnerIdProvider) ==
          widget.plan.ownerId;
    } on Object {
      return false;
    }
  }

  Future<List<WellnessContentItem>> _loadSession(String locale) async {
    if (!_allowed()) throw StateError('smart_plan_owner_changed');
    final items = await widget
        .loadItems(locale)
        .timeout(const Duration(seconds: 10));
    if (!_allowed()) throw StateError('smart_plan_owner_changed');
    final workout = widget.day.workout!;
    final doses = await const BilSmartPlanPrescriptions().session(workout);
    final warmups = await const BilSmartPlanPrescriptions().warmup(workout);
    if (!_allowed()) throw StateError('smart_plan_owner_changed');
    _doses.clear();
    _doses.addEntries(doses.map((dose) => MapEntry(dose.exerciseId, dose)));
    final bundle = workout.templateId.startsWith('home-')
        ? 'home-training'
        : 'gym-six-month';
    final ordered = <WellnessContentItem>[];
    final warmupTitles = <String, String>{};
    for (final step in warmups) {
      if (step.exerciseId == null) continue;
      final matches = items.where(
        (item) =>
            item.id == step.exerciseId &&
            item.verified &&
            item.releaseBundleId == bundle,
      );
      if (matches.length != 1) {
        throw StateError('smart_plan_warmup_catalog_changed');
      }
      warmupTitles[step.exerciseId!] = matches.single.title;
    }
    for (final id in workout.exerciseIds) {
      final match = items.where(
        (item) =>
            item.id == id && item.verified && item.releaseBundleId == bundle,
      );
      if (match.length != 1) throw StateError('smart_plan_catalog_changed');
      ordered.add(match.single);
    }
    if (!_allowed()) throw StateError('smart_plan_owner_changed');
    _warmups = warmups;
    _warmupTitles
      ..clear()
      ..addAll(warmupTitles);
    return List.unmodifiable(ordered);
  }

  Widget _sourceLink(String title, String url) => TextButton.icon(
    style: TextButton.styleFrom(foregroundColor: _smartPlanActionInk(context)),
    onPressed: () async {
      if (!_allowed()) return;
      var opened = false;
      try {
        opened = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      } on Object {
        opened = false;
      }
      if (!opened && mounted && _allowed()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _smartPlanText(
                context,
                'The reference could not be opened. Try again.',
                'تعذّر فتح المرجع. حاول مجددًا.',
              ),
            ),
          ),
        );
      }
    },
    icon: const Icon(Icons.open_in_new_rounded),
    label: Text(title),
  );

  Widget _warmupSurface(String locale) {
    String t(String en, String ar) => _smartPlanText(context, en, ar);
    final home = widget.day.workout!.templateId.startsWith('home-');
    return ListView(
      key: const ValueKey('bil-smart-plan-warmup-scroll'),
      padding: const EdgeInsets.all(16),
      children: [
        BilSmartPlanPanel(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.self_improvement_rounded, size: 32),
                const SizedBox(height: 12),
                Text(
                  t('Warm up before your session', 'الإحماء قبل جلستك'),
                  key: const ValueKey('bil-smart-plan-warmup'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  home
                      ? t(
                          'Allow at least 6 minutes. Start gently, take longer when needed, and stop if you feel pain or become unwell.',
                          'خصص 6 دقائق على الأقل. ابدأ بلطف وخذ وقتًا أطول عند الحاجة، وتوقف إذا شعرت بألم أو بتوعك.',
                        )
                      : t(
                          'Prepare with the movements from your BIL source plan. Keep the effort gentle; these are preparation sets, separate from your working sets.',
                          'استعد بحركات الإحماء من خطة BIL الموثقة. حافظ على جهد خفيف؛ هذه مجموعات تحضيرية منفصلة عن مجموعات التدريب.',
                        ),
                ),
                for (final step in _warmups) ...[
                  const SizedBox(height: 16),
                  Text(
                    (locale == 'ar' && step.titleAr != null)
                        ? step.titleAr!
                        : step.exerciseId == null
                        ? (locale == 'ar'
                              ? step.titleAr ?? step.title
                              : step.title)
                        : _warmupTitles[step.exerciseId]!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    _rangeForDirection(
                      locale == 'ar'
                          ? step.doseAr ??
                                'مجموعة واحدة بتحكم؛ 6–10 تكرارات أو 20–30 ثانية.'
                          : step.dose,
                    ),
                  ),
                  if (step.exerciseId != null)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _smartPlanActionInk(context),
                      ),
                      onPressed: _opening
                          ? null
                          : () async {
                              if (!_allowed()) return;
                              setState(() => _opening = true);
                              try {
                                await widget.openExercise(step.exerciseId!);
                              } finally {
                                if (mounted) setState(() => _opening = false);
                              }
                            },
                      icon: const Icon(Icons.play_circle_outline_rounded),
                      label: Text(
                        t('View verified movement', 'عرض الحركة الموثقة'),
                      ),
                    ),
                ],
                if (home)
                  _sourceLink(
                    t('NHS warm-up reference', 'مرجع الإحماء من NHS'),
                    'https://www.nhs.uk/live-well/exercise/how-to-warm-up-before-exercising/',
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const ValueKey('bil-smart-plan-warmup-continue'),
                  onPressed: () {
                    if (_allowed()) setState(() => _warmupReviewed = true);
                  },
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    t('Continue to exercises', 'المتابعة إلى التمارين'),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  t(
                    'Reviewing this preparation does not record a completed workout.',
                    'مراجعة الإحماء لا تسجّل تمرينًا مكتملًا.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(verifiedEntitlementOwnerIdProvider);
    ref.watch(verifiedSubscriptionAccessProvider);
    String t(String en, String ar) => _smartPlanText(context, en, ar);
    final allowed = _allowed();
    final locale = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    if (allowed && _locale != locale) {
      _locale = locale;
      _load = _loadSession(locale);
    }
    return Scaffold(
      key: const ValueKey('bil-smart-plan-session'),
      appBar: AppBar(
        title: Text(t('Your training session', 'جلستك التدريبية')),
      ),
      body: BilPearlBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: !allowed
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        t(
                          'Session access changed. Return to your plan and refresh.',
                          'تغيّر الوصول للجلسة. ارجع إلى خطتك وحدّثها.',
                        ),
                        key: const ValueKey(
                          'bil-smart-plan-session-access-changed',
                        ),
                      ),
                    )
                  : FutureBuilder<List<WellnessContentItem>>(
                      future: _load,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  t(
                                    'The session could not be opened. Your plan and diary are unchanged.',
                                    'تعذّر فتح الجلسة. لم تتغير خطتك أو سجلاتك.',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _smartPlanActionInk(
                                      context,
                                    ),
                                  ),
                                  onPressed: () => setState(
                                    () => _load = _loadSession(locale),
                                  ),
                                  child: Text(t('Try again', 'إعادة المحاولة')),
                                ),
                              ],
                            ),
                          );
                        }
                        final items = snapshot.data;
                        if (items == null) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: BilSmartPlanPanel(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          t(
                                            'Preparing your session',
                                            'تحضير جلستك',
                                          ),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 16),
                                        const LinearProgressIndicator(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        if (!_warmupReviewed && _warmups.isNotEmpty) {
                          return _warmupSurface(locale);
                        }
                        final item = items[_step];
                        final dose = _doses[item.id];
                        final title = locale == 'ar' && dose?.titleAr != null
                            ? dose!.titleAr!
                            : item.title;
                        return ListView(
                          key: const ValueKey(
                            'bil-smart-plan-exercises-scroll',
                          ),
                          padding: const EdgeInsets.all(16),
                          children: [
                            BilSmartPlanPanel(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      widget.day.date,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '${_step + 1} / ${items.length}',
                                      textDirection: TextDirection.ltr,
                                      textAlign:
                                          Directionality.of(context) ==
                                              TextDirection.rtl
                                          ? TextAlign.right
                                          : TextAlign.left,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    LinearProgressIndicator(
                                      value: _reviewed.length / items.length,
                                    ),
                                    const SizedBox(height: 20),
                                    if (locale == 'ar' &&
                                        title.contains(' — ')) ...[
                                      Text(
                                        title.split(' — ').first,
                                        key: const ValueKey(
                                          'bil-smart-plan-session-exercise',
                                        ),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.headlineSmall,
                                      ),
                                      Text(
                                        title.split(' — ').last,
                                        textDirection: TextDirection.ltr,
                                        textAlign: TextAlign.right,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ] else
                                      Text(
                                        title,
                                        key: const ValueKey(
                                          'bil-smart-plan-session-exercise',
                                        ),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.headlineSmall,
                                      ),
                                    const SizedBox(height: 12),
                                    Text(
                                      item.id ==
                                              'home-bodyweight-chair-squat-standard'
                                          ? t(
                                              'Stable chair and clear floor',
                                              'كرسي ثابت وأرضية خالية من العوائق',
                                            )
                                          : item.id ==
                                                'home-bodyweight-wall-push-up-standard'
                                          ? t(
                                              'Fixed wall and non-slip footing',
                                              'حائط ثابت وموضع قدمين غير قابل للانزلاق',
                                            )
                                          : item.id ==
                                                'home-bodyweight-counter-incline-push-up-standard'
                                          ? t(
                                              'Stable fixed counter',
                                              'سطح مرتفع ثابت وآمن',
                                            )
                                          : item.equipment
                                                .map(
                                                  (value) => value == 'none'
                                                      ? t(
                                                          'No equipment',
                                                          'دون معدات',
                                                        )
                                                      : value,
                                                )
                                                .join(' · '),
                                    ),
                                    for (final step in [
                                      ...item.instructions,
                                      ...item.steps,
                                    ])
                                      Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Text(step),
                                      ),
                                    for (final segment in item.segments) ...[
                                      Text(segment.title),
                                      Text(segment.instruction),
                                      if (segment.repetitions != null)
                                        Text(
                                          '${t('Repetitions: ', 'التكرارات: ')}${segment.repetitions}',
                                        ),
                                      if (segment.restSeconds != null)
                                        Text(
                                          '${t('Rest seconds: ', 'ثواني الراحة: ')}${segment.restSeconds}',
                                        ),
                                    ],
                                    if (dose != null) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        '${t('Sets: ', 'المجموعات: ')}${dose.sets}',
                                        key: const ValueKey(
                                          'bil-smart-plan-source-sets',
                                        ),
                                      ),
                                      Text(
                                        '${t('Repetitions: ', 'التكرارات: ')}${_rangeForDirection(dose.repetitions.replaceAll('each side', t('each side', 'لكل جهة')).replaceAll('seconds', t('seconds', 'ثانية')).replaceAll('controlled technical reps', t('controlled technical reps', 'تكرارات فنية بتحكم')))}',
                                      ),
                                      Text(
                                        '${t('Rest seconds: ', 'ثواني الراحة: ')}${dose.restSeconds}',
                                      ),
                                      if (dose.homeGuidance) ...[
                                        const SizedBox(height: 10),
                                        Text(
                                          t(
                                            'Move with control. Stop if painful and rest longer when needed.',
                                            'حافظ على التحكم. توقف عند الألم وزد الراحة عند الحاجة.',
                                          ),
                                        ),
                                        ExpansionTile(
                                          key: const ValueKey(
                                            'bil-smart-plan-home-guidance',
                                          ),
                                          tilePadding: EdgeInsets.zero,
                                          title: Text(
                                            t(
                                              'Guidance and sources',
                                              'الإرشادات والمصادر',
                                            ),
                                          ),
                                          children: [
                                            Text(
                                              t(
                                                'BIL adapts published NHS and CDC strength guidance for this general adult program. It is not injury rehabilitation. Sets and resistance never increase automatically; review and approve any change.',
                                                'يطبّق BIL إرشادات القوة المنشورة لدى NHS وCDC في برنامج عام للبالغين وليس لتأهيل الإصابات. لا تزيد المجموعات أو المقاومة تلقائيًا؛ راجع أي تعديل ووافق عليه.',
                                              ),
                                            ),
                                            Text(
                                              t(
                                                'Use a comfortable resistance. Allow more time rather than shortening rest or rushing technique.',
                                                'استخدم مقاومة مريحة. أتح وقتًا أطول بدلًا من اختصار الراحة أو استعجال الأداء.',
                                              ),
                                            ),
                                            _sourceLink(
                                              t(
                                                'NHS sets and repetitions',
                                                'المجموعات والتكرارات من NHS',
                                              ),
                                              'https://www.nhs.uk/live-well/exercise/how-to-improve-strength-flexibility/',
                                            ),
                                            _sourceLink(
                                              t(
                                                'CDC rest guidance',
                                                'إرشادات الراحة من CDC',
                                              ),
                                              'https://www.cdc.gov/pcd/issues/2014/13_0403.htm',
                                            ),
                                          ],
                                        ),
                                      ] else
                                        Text(
                                          t(
                                            'Reference: BIL source-verified Gym plan. Adjust only through a reviewed plan change.',
                                            'المرجع: خطة النادي الموثقة من مصدر BIL. لا تُعدّل إلا بعد مراجعة تغيير الخطة.',
                                          ),
                                        ),
                                    ],
                                    if (dose == null && item.segments.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Text(
                                          t(
                                            'This reference does not specify sets, repetitions or rest. BIL will not invent a training dose.',
                                            'لا يحدد هذا المرجع مجموعات أو تكرارات أو راحة. لن يختلق BIL جرعة تدريب.',
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _smartPlanActionInk(
                                          context,
                                        ),
                                      ),
                                      onPressed: _opening
                                          ? null
                                          : () async {
                                              if (!_allowed()) return;
                                              setState(() => _opening = true);
                                              try {
                                                await widget.openExercise(
                                                  item.id,
                                                );
                                              } finally {
                                                if (mounted) {
                                                  setState(
                                                    () => _opening = false,
                                                  );
                                                }
                                              }
                                            },
                                      icon: const Icon(
                                        Icons.play_circle_outline_rounded,
                                      ),
                                      label: Text(
                                        t(
                                          'Open verified demonstration',
                                          'فتح العرض الموثق',
                                        ),
                                      ),
                                    ),
                                    CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      key: const ValueKey(
                                        'bil-smart-plan-session-step-done',
                                      ),
                                      value: _reviewed.contains(item.id),
                                      onChanged: (value) {
                                        if (!_allowed()) return;
                                        setState(() {
                                          if (value == true) {
                                            _reviewed.add(item.id);
                                          } else {
                                            _reviewed.remove(item.id);
                                          }
                                        });
                                      },
                                      title: Text(
                                        t(
                                          'I finished this movement',
                                          'أنهيت هذه الحركة',
                                        ),
                                      ),
                                    ),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                _smartPlanActionInk(context),
                                          ),
                                          onPressed: _step == 0
                                              ? null
                                              : () => setState(() => _step--),
                                          child: Text(
                                            t(
                                              'Previous exercise',
                                              'التمرين السابق',
                                            ),
                                          ),
                                        ),
                                        if (_step + 1 < items.length)
                                          FilledButton(
                                            key: const ValueKey(
                                              'bil-smart-plan-session-next',
                                            ),
                                            onPressed: () =>
                                                setState(() => _step++),
                                            child: Text(
                                              t(
                                                'Next exercise',
                                                'التمرين التالي',
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              key: const ValueKey(
                                'bil-smart-plan-session-finish',
                              ),
                              onPressed: _reviewed.length != items.length
                                  ? null
                                  : () {
                                      if (_allowed()) {
                                        Navigator.pop(context, true);
                                      }
                                    },
                              icon: const Icon(
                                Icons.check_circle_outline_rounded,
                              ),
                              label: Text(
                                t('Review completion', 'مراجعة الإكمال'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              t(
                                'Nothing is recorded until you confirm the actual activity on the next screen.',
                                'لا يُسجّل شيء حتى تؤكد النشاط الفعلي في الشاشة التالية.',
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
