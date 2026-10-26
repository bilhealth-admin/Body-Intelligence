part of 'bil_smart_plan_page.dart';

extension _BilSmartPlanAdaptation on _BilSmartPlanPageState {
  Future<void> _swapMealDates(BilPlanDay day, BilPlanMeal meal) async {
    final current = _plan;
    final epoch = _ownerEpoch;
    if (current == null) return;
    final today = BilPlanDate.iso(ref.read(bilSmartPlanClockProvider)());
    final candidates = current.days
        .where(
          (d) =>
              d.date.compareTo(today) >= 0 &&
              d.date != day.date &&
              d.meals.any(
                (m) => m.slot == meal.slot && m.recipeId != meal.recipeId,
              ),
        )
        .toList();
    if (candidates.isEmpty) {
      throw StateError('smart_plan_no_alternative_meal_date');
    }
    var target = candidates.first.date;
    final locale = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    const catalog = BilSmartPlanCatalog();
    final confirmed = await _confirmDialog(
      context: context,
      builder: (dialog) => BilPearlMaterialAlertDialog(
        scrollable: true,
        title: Text(_t('Swap meal dates', 'تبديل موعد الوجبة')),
        content: StatefulBuilder(
          builder: (context, update) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${day.date} · ${_mealSlot(meal.slot)}\n${catalog.recipeTitle(meal.recipeId, locale: locale)}',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: const ValueKey('bil-smart-plan-meal-target-date'),
                initialValue: target,
                isExpanded: true,
                itemHeight: null,
                decoration: InputDecoration(
                  labelText: _t('Swap with', 'التبديل مع'),
                ),
                items: [
                  for (final d in candidates)
                    DropdownMenuItem(
                      value: d.date,
                      child: Text(
                        '${d.date}\n${catalog.recipeTitle(d.meals.singleWhere((m) => m.slot == meal.slot).recipeId, locale: locale)}',
                      ),
                    ),
                ],
                onChanged: (v) => update(() => target = v ?? target),

                icon: const BilCrystalArrow(
                  extent: 36,
                  child: Icon(Icons.keyboard_arrow_down_rounded),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _t(
                  'Only planned meals exchange dates. No food intake or nutrition target is recorded.',
                  'يتبدل موعد الوجبتين المخططتين فقط. لا يُسجل طعام مأكول ولا يتغير هدف التغذية.',
                ),
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
    _checkAccess();
    await _save(
      current.swapMealDates(
        date: BilPlanDate.parse(day.date),
        target: BilPlanDate.parse(target),
        slot: meal.slot,
        now: ref.read(bilSmartPlanClockProvider)(),
      ),
      prior: current.revision,
    );
  }

  Future<void> _replaceWorkout(BilPlanDay day) async {
    final current = _plan;
    final epoch = _ownerEpoch;
    if (current == null || _busy) return;
    _mutate(() => _busy = true);
    try {
      _checkAccess();
      const catalog = BilSmartPlanCatalog();
      final source = current.setup?.environment == BilPlanEnvironment.home
          ? await catalog.homeSessions(current.setup!)
          : await catalog.gymSessions(
              sessionMinutes:
                  current.setup?.sessionMinutes ?? day.workout!.minutes,
            );
      final choices = source
          .where((s) => s.id != day.workout?.templateId)
          .toList();
      if (!mounted || epoch != _ownerEpoch) return;
      if (choices.isEmpty) {
        throw StateError('smart_plan_no_verified_alternative');
      }
      var selected = choices.first;
      var reason = BilPlanChangeReason.equipment;
      final confirmed = await _confirmDialog(
        context: context,
        builder: (dialog) => BilPearlMaterialAlertDialog(
          scrollable: true,
          title: Text(
            _t('Review alternative session', 'مراجعة الجلسة البديلة'),
          ),
          content: StatefulBuilder(
            builder: (context, update) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${day.date}\n${_workoutTitle(day.workout!.templateId)}'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const ValueKey('bil-smart-plan-alternative-session'),
                  initialValue: selected.id,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: InputDecoration(
                    labelText: _t('Verified alternative', 'بديل موثق'),
                  ),
                  items: [
                    for (final choice in choices)
                      DropdownMenuItem(
                        value: choice.id,
                        child: Text(
                          '${_workoutTitle(choice.id)} · ${choice.exerciseIds.length}',
                        ),
                      ),
                  ],
                  onChanged: (v) => update(
                    () => selected = choices.singleWhere((s) => s.id == v),
                  ),

                  icon: const BilCrystalArrow(
                    extent: 36,
                    child: Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                for (final id in selected.exerciseIds)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(_exerciseTitle(id)),
                  ),
                DropdownButtonFormField<BilPlanChangeReason>(
                  initialValue: reason,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: InputDecoration(
                    labelText: _t('Reason for change', 'سبب التعديل'),
                  ),
                  items: [
                    for (final r in [
                      BilPlanChangeReason.equipment,
                      BilPlanChangeReason.fatigue,
                    ])
                      DropdownMenuItem(value: r, child: Text(_changeReason(r))),
                  ],
                  onChanged: (v) => update(() => reason = v ?? reason),

                  icon: const BilCrystalArrow(
                    extent: 36,
                    child: Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _t(
                    'Review the full session before confirming. A catalog alternative is not a medical assessment of fatigue or injury.',
                    'راجع الجلسة كاملة قبل التأكيد. البديل من المكتبة لا يُعد تقييمًا طبيًا للتعب أو الإصابة.',
                  ),
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
      _checkAccess();
      final next = current.replaceWorkout(
        date: BilPlanDate.parse(day.date),
        replacement: BilPlanWorkout(
          templateId: selected.id,
          exerciseIds: selected.exerciseIds,
          minutes: current.setup?.sessionMinutes ?? selected.minutes,
        ),
        now: ref.read(bilSmartPlanClockProvider)(),
        reason: reason,
      );
      await _save(next, prior: current.revision);
    } on Object catch (error) {
      if (mounted && epoch == _ownerEpoch) {
        _mutate(() => _error = error.toString());
      }
    } finally {
      if (mounted && epoch == _ownerEpoch) _mutate(() => _busy = false);
    }
  }
}
