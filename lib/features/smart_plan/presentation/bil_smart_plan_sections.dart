part of 'bil_smart_plan_page.dart';

extension _BilSmartPlanSections on _BilSmartPlanPageState {
  Widget _loadingPanel() => Semantics(
    liveRegion: true,
    child: _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.calendar_month_rounded),
          const SizedBox(height: 12),
          Text(
            _t('Opening your saved plan', 'فتح خطتك المحفوظة'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            _t(
              'Loading your schedule and confirmed progress.',
              'جارٍ تحميل الجدول والتقدم المؤكد.',
            ),
          ),
        ],
      ),
    ),
  );
  Widget _panel({required Widget child, String? artwork}) => BilSmartPlanPanel(
    margin: const EdgeInsets.only(bottom: 12),
    artwork: artwork,
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );

  Widget _today(BilSmartPlan plan) {
    final day = plan.onDate(
      _requestedDay ?? ref.read(bilSmartPlanClockProvider)(),
    );
    if (day == null) {
      return _panel(
        child: Text(
          _t(
            'This period has no session for today. Review the schedule or create a new period after completion.',
            'لا توجد جلسة مقررة اليوم ضمن هذه الفترة. راجع الجدول أو أنشئ فترة جديدة بعد انتهاء الخطة.',
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panel(
          artwork: day.workout == null
              ? BilSmartPlanArt.recovery
              : BilSmartPlanArt.forWorkout(day.workout!.templateId),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BilSmartPlanSectionTitle(
                title:
                    _requestedDay != null &&
                        BilPlanDate.iso(_requestedDay!) !=
                            BilPlanDate.iso(
                              ref.read(bilSmartPlanClockProvider)(),
                            )
                    ? _t('Selected day', 'اليوم المختار')
                    : _t('Today', 'اليوم'),
                subtitle: day.date,
                icon: day.workout == null
                    ? Icons.self_improvement_rounded
                    : Icons.fitness_center_rounded,
              ),
              const SizedBox(height: 16),
              if (day.workout == null)
                Text(
                  _t(
                    'Recovery / no workout scheduled',
                    'راحة / لا يوجد تمرين مجدول',
                  ),
                )
              else ...[
                Text(
                  _workoutTitle(day.workout!.templateId),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  _t(
                        'Verified exercise references: ',
                        'عدد التمارين الموثقة: ',
                      ) +
                      day.workout!.exerciseIds.length.toString() +
                      _t(
                        ' · Session time budget: ',
                        ' · الوقت المتاح للجلسة: ',
                      ) +
                      day.workout!.minutes.toString() +
                      _t(' min', ' دقيقة'),
                ),
                const SizedBox(height: 8),
                ExpansionTile(
                  key: const ValueKey('bil-smart-plan-workout-steps'),
                  title: Text(
                    _t('Exercises in this session', 'تمارين هذه الجلسة'),
                  ),
                  children: [
                    for (final id in day.workout!.exerciseIds)
                      ListTile(
                        dense: true,
                        onTap: () => _openExercise(id),
                        trailing: const Icon(Icons.play_circle_outline_rounded),
                        title: Text(_exerciseTitle(id)),
                      ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (plan.status == BilPlanStatus.active &&
                        !day.workout!.completed)
                      FilledButton.icon(
                        key: const ValueKey('bil-smart-plan-start-session'),
                        onPressed: _busy ? null : () => _startSession(day),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(_t('Start workout', 'ابدأ التمرين')),
                      ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _smartPlanActionInk(context),
                      ),
                      onPressed: () =>
                          context.push('/wellness/workouts/routines'),
                      icon: const Icon(Icons.fitness_center_outlined),
                      label: Text(
                        _t(
                          'Verified workout library',
                          'مكتبة التمارين الموثقة',
                        ),
                      ),
                    ),
                    if (plan.status == BilPlanStatus.active)
                      FilledButton.icon(
                        key: const ValueKey('bil-smart-plan-complete-workout'),
                        onPressed: _busy ? null : () => _confirmWorkout(day),
                        icon: Icon(
                          day.workout!.completed
                              ? Icons.undo_rounded
                              : Icons.check_circle_outline,
                        ),
                        label: Text(
                          day.workout!.completed
                              ? _t('Undo completion', 'تراجع')
                              : _t('Mark completed', 'إكمال التمرين'),
                        ),
                      ),
                    if (plan.status == BilPlanStatus.active &&
                        !day.workout!.completed)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _smartPlanActionInk(context),
                        ),
                        key: const ValueKey('bil-smart-plan-replace-session'),
                        onPressed: _busy ? null : () => _replaceWorkout(day),
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: Text(_t('Alternative session', 'جلسة بديلة')),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (day.meals.isNotEmpty)
          _panel(
            artwork: BilSmartPlanArt.meals,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BilSmartPlanSectionTitle(
                  title: _t('Suggested meals', 'الوجبات المقترحة'),
                  subtitle: _t(
                    'Suggestions are not meal log entries.',
                    'الاقتراحات لا تعني أن الوجبات تم تناولها أو تسجيلها.',
                  ),
                  icon: Icons.restaurant_rounded,
                ),
                const SizedBox(height: 12),
                for (final meal in day.meals)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.restaurant_menu_rounded),
                    onTap: _busy ? null : () => _reviewMeal(day, meal),
                    title: Text(
                      const BilSmartPlanCatalog().recipeTitle(meal.recipeId),
                    ),
                    subtitle: Text(_mealSlot(meal.slot)),
                  ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _smartPlanActionInk(context),
                  ),
                  onPressed: () => context.push('/meal-planner'),
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: Text(_t('Review meals', 'مراجعة الوجبات')),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _workoutTitle(String id) => switch (id) {
    'push-a' || 'push-b' => _t('Push session', 'تمارين الدفع'),
    'pull-a' || 'pull-b' => _t('Pull session', 'تمارين السحب'),
    'legs-a' || 'legs-b' => _t('Leg session', 'تمارين الرجلين'),
    final home
        when home.startsWith('home-strength-v1-') &&
            home.endsWith('-dumbbells') =>
      _t('Home strength · dumbbells', 'قوة منزلية · أوزان يدوية'),
    final home
        when home.startsWith('home-strength-v1-') &&
            home.endsWith('-kettlebell') =>
      _t('Home strength · kettlebell', 'قوة منزلية · كرة حديدية'),
    final home
        when home.startsWith('home-strength-v1-') && home.endsWith('-b') =>
      _t('Home full-body B', 'قوة منزلية لكامل الجسم · ب'),
    final home when home.startsWith('home-strength-v1-') => _t(
      'Home full-body A',
      'قوة منزلية لكامل الجسم · أ',
    ),
    _ => _t('Verified training session', 'جلسة تدريب موثقة'),
  };

  String _exerciseTitle(String id) =>
      const BilSmartPlanPrescriptions().exerciseTitle(
        id,
        locale: BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
      ) ??
      const BilSmartPlanCatalog().exerciseTitle(id);

  String _horizonName(BilPlanHorizon value) => switch (value) {
    BilPlanHorizon.week => _t('One week', 'أسبوع'),
    BilPlanHorizon.month => _t('One month', 'شهر'),
    BilPlanHorizon.threeMonths => _t('Three months', '3 أشهر'),
    BilPlanHorizon.sixMonths => _t('Six months', '6 أشهر'),
  };

  String _statusName(BilPlanStatus value) => switch (value) {
    BilPlanStatus.draft => _t('Draft', 'مسودة'),
    BilPlanStatus.active => _t('Active', 'نشطة'),
    BilPlanStatus.paused => _t('Paused', 'متوقفة مؤقتًا'),
    BilPlanStatus.completed => _t('Completed', 'مكتملة'),
  };

  String _mealSlot(BilPlanMealSlot slot) => switch (slot) {
    BilPlanMealSlot.breakfast => _t('Breakfast', 'الفطور'),
    BilPlanMealSlot.lunch => _t('Lunch', 'الغداء'),
    BilPlanMealSlot.dinner => _t('Dinner', 'العشاء'),
  };

  Widget _schedule(BilSmartPlan plan) {
    final first = _weekOffset * 7;
    final visible = plan.days.skip(first).take(7).toList(growable: false);
    return Column(
      children: [
        _panel(
          artwork: BilSmartPlanArt.schedule,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                key: const ValueKey('bil-smart-plan-previous-week'),
                onPressed: first <= 0
                    ? null
                    : () => _mutate(() => _weekOffset--),
                icon: Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_right_rounded
                      : Icons.chevron_left_rounded,
                ),
              ),
              Text(
                _t('Week ', 'الأسبوع ') + (_weekOffset + 1).toString(),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              IconButton(
                key: const ValueKey('bil-smart-plan-next-week'),
                onPressed: first + 7 >= plan.days.length
                    ? null
                    : () => _mutate(() => _weekOffset++),
                icon: Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                ),
              ),
            ],
          ),
        ),
        for (final day in visible)
          _panel(
            artwork: day.workout == null
                ? BilSmartPlanArt.recovery
                : BilSmartPlanArt.forWorkout(day.workout!.templateId),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                day.workout == null
                    ? Icons.self_improvement_rounded
                    : Icons.fitness_center_outlined,
              ),
              title: Text(
                day.date,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                day.workout == null
                    ? _t('Rest / recovery', 'راحة / استشفاء')
                    : _workoutTitle(day.workout!.templateId),
              ),
              trailing: day.workout?.completed == true
                  ? Icon(
                      Icons.check_circle_outline_rounded,
                      color: _smartPlanActionInk(context),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: () => _showDay(day),
            ),
          ),
      ],
    );
  }

  Future<void> _deferDay(
    BilPlanDay day, {
    BilPlanChangeReason initialReason = BilPlanChangeReason.schedule,
  }) async {
    final current = _plan;
    final epoch = _ownerEpoch;
    if (current == null || _busy) return;
    try {
      final now = ref.read(bilSmartPlanClockProvider)();
      final today = BilPlanDate.iso(now);
      final available = current.days
          .where(
            (candidate) =>
                candidate.date.compareTo(today) >= 0 &&
                candidate.date != day.date &&
                candidate.workout == null &&
                current.recoveryAllowsMove(
                  date: BilPlanDate.parse(day.date),
                  target: BilPlanDate.parse(candidate.date),
                ),
          )
          .toList(growable: false);
      if (available.isEmpty) throw StateError('smart_plan_no_recovery_day');
      var destination = available.first.date;
      var reason = initialReason;
      final confirmed = await _confirmDialog(
        context: context,
        builder: (dialog) => BilPearlMaterialAlertDialog(
          scrollable: true,
          title: Text(_t('Review schedule change', 'مراجعة تعديل الجدول')),
          content: StatefulBuilder(
            builder: (context, update) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _t(
                    'Move only this session. Training volume and food targets will not increase to make up for a missed day.',
                    'انقل هذه الجلسة فقط. لن يزيد حجم التدريب أو يتغير هدف الطعام لتعويض يوم فائت.',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: destination,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: _t('New session date', 'موعد الجلسة الجديد'),
                  ),
                  items: [
                    for (final candidate in available)
                      DropdownMenuItem(
                        value: candidate.date,
                        child: Text(candidate.date),
                      ),
                  ],
                  onChanged: (value) =>
                      update(() => destination = value ?? destination),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<BilPlanChangeReason>(
                  initialValue: reason,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: _t('Reason for change', 'سبب التعديل'),
                  ),
                  items: [
                    for (final item in [
                      BilPlanChangeReason.schedule,
                      BilPlanChangeReason.travel,
                      BilPlanChangeReason.fatigue,
                      BilPlanChangeReason.equipment,
                    ])
                      DropdownMenuItem(
                        value: item,
                        child: Text(_changeReason(item)),
                      ),
                  ],
                  onChanged: (value) => update(() => reason = value ?? reason),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: _smartPlanActionInk(context),
              ),
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(_t('Cancel', 'إلغاء')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(_t('Confirm', 'تأكيد')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted || epoch != _ownerEpoch) return;
      final next = current.rescheduleWorkout(
        date: BilPlanDate.parse(day.date),
        target: BilPlanDate.parse(destination),
        now: ref.read(bilSmartPlanClockProvider)(),
        reason: reason,
      );
      await _save(next, prior: current.revision);
    } on Object catch (error) {
      if (mounted) _mutate(() => _error = error.toString());
    }
  }

  String _changeReason(BilPlanChangeReason reason) => switch (reason) {
    BilPlanChangeReason.status => _t('Plan status', 'حالة الخطة'),
    BilPlanChangeReason.completion => _t('Confirmed workout', 'تمرين مؤكد'),
    BilPlanChangeReason.correction => _t('Activity correction', 'تصحيح النشاط'),
    BilPlanChangeReason.schedule => _t('Schedule preference', 'تفضيل الموعد'),
    BilPlanChangeReason.travel => _t('Travel', 'السفر'),
    BilPlanChangeReason.fatigue => _t(
      'Fatigue or recovery',
      'التعب أو الاستشفاء',
    ),
    BilPlanChangeReason.equipment => _t(
      'Equipment availability',
      'توفر المعدات',
    ),
    BilPlanChangeReason.mealSwap => _t('Meal replacement', 'استبدال الوجبة'),
  };

  Future<void> _showDay(BilPlanDay day) async {
    await showBilModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            BilSmartPlanPanel(
              artwork: day.workout == null
                  ? BilSmartPlanArt.recovery
                  : BilSmartPlanArt.forWorkout(day.workout!.templateId),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: BilSmartPlanSectionTitle(
                  title: day.workout == null
                      ? _t('Recovery day', 'يوم راحة')
                      : _workoutTitle(day.workout!.templateId),
                  subtitle: day.date,
                  icon: day.workout == null
                      ? Icons.self_improvement_rounded
                      : Icons.fitness_center_rounded,
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final id in day.workout?.exerciseIds ?? const <String>[])
              ListTile(
                onTap: () {
                  Navigator.pop(context);
                  unawaited(_openExercise(id));
                },
                trailing: const Icon(Icons.play_circle_outline_rounded),
                title: Text(_exerciseTitle(id)),
              ),
            if (day.workout != null &&
                !day.workout!.completed &&
                _plan?.status == BilPlanStatus.active)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _smartPlanActionInk(context),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  unawaited(_deferDay(day));
                },
                child: Text(_t('Postpone this session', 'تأجيل هذه الجلسة')),
              ),
            for (final meal in day.meals)
              ListTile(
                title: Text(
                  const BilSmartPlanCatalog().recipeTitle(meal.recipeId),
                ),
                subtitle: Text(_mealSlot(meal.slot)),
                onTap: () {
                  Navigator.pop(context);
                  unawaited(_reviewMeal(day, meal));
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _progress(BilSmartPlan plan) {
    final week = BilSmartPlanWeekReview(
      plan,
      ref.read(bilSmartPlanClockProvider)(),
    );
    final done = plan.days
        .where((day) => day.workout?.completed == true)
        .length;
    final scheduled = plan.days.where((day) => day.workout != null).length;
    return _panel(
      artwork: BilSmartPlanArt.progress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BilSmartPlanSectionTitle(
            title: _t('Training progress', 'تقدم التدريب'),
            subtitle: _t(
              'Only confirmed sessions count as completed.',
              'تُحتسب الجلسات المؤكدة فقط بوصفها مكتملة.',
            ),
            icon: Icons.insights_rounded,
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: plan.workoutCompletion),
          const SizedBox(height: 10),
          Text(
            '$done / $scheduled${_t(' confirmed sessions', ' جلسات مؤكدة')}',
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 410
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: width,
                    child: BilSmartPlanMetric(
                      label: _t('Confirmed', 'المؤكدة'),
                      value: done.toString(),
                      icon: Icons.check_circle_outline_rounded,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: BilSmartPlanMetric(
                      label: _t('Scheduled', 'المجدولة'),
                      value: scheduled.toString(),
                      icon: Icons.calendar_today_rounded,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            _t(
              'Nutrition suggestions do not count as actual intake. Review the diary for recorded food.',
              'الوجبات المقترحة لا تُحسب كطعام مأكول. راجع سجل الطعام للاستهلاك الفعلي.',
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _t('Last seven days', 'آخر سبعة أيام'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${_t('Confirmed sessions: ', 'جلسات مؤكدة: ')}${week.confirmed} / ${week.scheduled}',
          ),
          Text(
            '${_t('Past sessions awaiting confirmation: ', 'جلسات سابقة دون تأكيد: ')}${week.unconfirmedPast}',
          ),
          Text(
            _t(
              'An unconfirmed session may simply be unrecorded. Review it before changing your schedule.',
              'قد تكون الجلسة غير المؤكدة غير مسجلة فقط. راجعها قبل تعديل جدولك.',
            ),
          ),
          if (plan.days.any((day) => day.phase.startsWith('gym-month-'))) ...[
            const SizedBox(height: 16),
            ExpansionTile(
              title: Text(
                _t('Plan phases and review', 'مراحل الخطة والمراجعة'),
              ),
              subtitle: Text(
                _t(
                  'Source guidance does not automatically change your approved training frequency.',
                  'إرشادات المصدر لا تغيّر عدد جلساتك المعتمد تلقائيًا.',
                ),
              ),
              children: [
                for (final phaseId in plan.days.map((day) => day.phase).toSet())
                  FutureBuilder<Map<String, String>?>(
                    future: const BilSmartPlanPrescriptions().phase(phaseId),
                    builder: (context, snapshot) {
                      final phase = snapshot.data;
                      if (phase == null) return const SizedBox.shrink();
                      final locale = BilLocalePolicy.canonicalTag(
                        Localizations.localeOf(context),
                      );
                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              smartPlanSourcePhaseText(phase['name']!, locale),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              smartPlanSourcePhaseText(
                                phase['progression']!,
                                locale,
                              ),
                            ),
                            Text(
                              smartPlanSourcePhaseText(
                                phase['deload']!,
                                locale,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
          if (plan.changes.isNotEmpty) ...[
            const SizedBox(height: 20),
            ExpansionTile(
              key: const ValueKey('bil-smart-plan-revision-history'),
              title: Text(_t('Plan revision history', 'سجل إصدارات الخطة')),
              subtitle: Text(
                _t(
                  'Compare recent confirmed changes. Previous versions are read only.',
                  'قارن التعديلات المؤكدة الأخيرة. الإصدارات السابقة للقراءة فقط.',
                ),
              ),
              children: [
                for (final change in plan.changes)
                  ListTile(
                    title: Text(
                      '${change.revision} · ${_changeReason(change.reason)}',
                    ),
                    subtitle: Text(BilPlanDate.iso(change.at.toLocal())),
                    trailing: const Icon(Icons.compare_arrows_rounded),
                    onTap: () => _showRevision(plan, change.revision),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _overview(BilSmartPlan plan) => _panel(
    artwork: BilSmartPlanArt.overview,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.calendar_month_outlined,
                color: _smartPlanActionInk(context),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _horizonName(plan.horizon),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.startDate,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusName(plan.status),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: _smartPlanActionInk(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(_t('A clear plan, one day at a time.', 'خطتك واضحة، يومًا بيوم.')),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 410
                ? (constraints.maxWidth - 10) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: width,
                  child: BilSmartPlanMetric(
                    label: _t('Days in plan', 'أيام الخطة'),
                    value: plan.days.length.toString(),
                    icon: Icons.date_range_rounded,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: BilSmartPlanMetric(
                    label: _t('Scheduled workouts', 'التمارين المجدولة'),
                    value: plan.days
                        .where((day) => day.workout != null)
                        .length
                        .toString(),
                    icon: Icons.fitness_center_rounded,
                  ),
                ),
              ],
            );
          },
        ),
        if (!_catalogBlocked &&
            (plan.status == BilPlanStatus.draft ||
                plan.status == BilPlanStatus.paused)) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : () => _changeStatus(BilPlanStatus.active),
            icon: const Icon(Icons.check_circle_outline),
            label: Text(_t('Approve and activate', 'اعتماد وتفعيل')),
          ),
        ],
      ],
    ),
  );
}
