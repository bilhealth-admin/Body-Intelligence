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
    if (!_allowed()) throw StateError('smart_plan_owner_changed');
    _doses.clear();
    _doses.addEntries(doses.map((dose) => MapEntry(dose.exerciseId, dose)));
    final bundle = workout.templateId.startsWith('home-')
        ? 'home-training'
        : 'gym-six-month';
    final ordered = <WellnessContentItem>[];
    for (final id in workout.exerciseIds) {
      final match = items.where(
        (item) =>
            item.id == id && item.verified && item.releaseBundleId == bundle,
      );
      if (match.length != 1) throw StateError('smart_plan_catalog_changed');
      ordered.add(match.single);
    }
    return List.unmodifiable(ordered);
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
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final item = items[_step];
                        final dose = _doses[item.id];
                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            BilPearlMaterialCard(
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
                                        item.title.contains(' — ')) ...[
                                      Text(
                                        item.title.split(' — ').first,
                                        key: const ValueKey(
                                          'bil-smart-plan-session-exercise',
                                        ),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.headlineSmall,
                                      ),
                                      Text(
                                        item.title.split(' — ').last,
                                        textDirection: TextDirection.ltr,
                                        textAlign: TextAlign.right,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ] else
                                      Text(
                                        item.title,
                                        key: const ValueKey(
                                          'bil-smart-plan-session-exercise',
                                        ),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.headlineSmall,
                                      ),
                                    const SizedBox(height: 12),
                                    Text(item.equipment.join(' · ')),
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
