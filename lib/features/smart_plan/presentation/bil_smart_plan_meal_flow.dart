part of 'bil_smart_plan_page.dart';

extension _BilSmartPlanMeals on _BilSmartPlanPageState {
  Future<void> _reviewMeal(BilPlanDay day, BilPlanMeal meal) async {
    final current = _plan;
    final epoch = _ownerEpoch;
    if (current == null || _busy) return;
    _mutate(() => _busy = true);
    try {
      _checkAccess();
      final dietary = await ref
          .read(dietaryPreferencesRepositoryProvider)
          .read();
      const catalog = BilSmartPlanCatalog();
      final detail = await catalog.recipeDetail(meal.recipeId, dietary);
      final choices = (await catalog.sourcedRecipes(dietary: dietary))
          .where(
            (entry) => entry.slot == meal.slot && entry.id != meal.recipeId,
          )
          .toList(growable: false);
      if (!mounted || epoch != _ownerEpoch) return;
      _checkAccess();
      final locale = BilLocalePolicy.canonicalTag(
        Localizations.localeOf(context),
      );
      final facts = detail == null ? null : catalog.sourcedNutrition(detail);
      final snapshot = await BilSmartPlanNutritionGoals.readSavedSnapshot(
        _repository.preferences,
      );
      final schedule = await ref
          .read(nutritionGoalScheduleRepositoryProvider)
          .read();
      final target = BilSmartPlanNutritionGoals.forDate(
        date: BilPlanDate.parse(day.date),
        snapshot: snapshot,
        schedule: schedule,
      );
      if (!mounted || epoch != _ownerEpoch) return;
      String? selected;
      final replacement = await _reviewSurface(
        () => showBilModalBottomSheet<String>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          builder: (sheet) => StatefulBuilder(
            builder: (sheet, update) => SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      catalog.recipeTitle(meal.recipeId, locale: locale),
                      style: Theme.of(sheet).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text('${day.date} · ${_mealSlot(meal.slot)}'),
                    const SizedBox(height: 12),
                    Text(
                      _t(
                        'Planned meal only. Nothing here records food as eaten.',
                        'وجبة مخططة فقط. لا يُسجّل الطعام كمأكول من هنا.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (target != null) ...[
                      Text(
                        _t(
                          'Saved daily nutrition goal',
                          'الهدف الغذائي اليومي المحفوظ',
                        ),
                        style: Theme.of(sheet).textTheme.titleMedium,
                      ),
                      Text('${target.values['kcal']!.round()} kcal'),
                      Text(
                        _t(
                          'This is your saved goal, not food consumed or a new recommendation. Recipes show one source serving; review portions in the recipe.',
                          'هذا هدفك المحفوظ، وليس طعامًا مستهلكًا أو توصية جديدة. تعرض الوصفات حصة من المصدر؛ راجع الحصص في الوصفة.',
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (facts != null) ...[
                      Text(
                        _t(
                          'Source-calculated values per serving',
                          'قيم محسوبة من المصدر لكل حصة',
                        ),
                        style: Theme.of(sheet).textTheme.titleMedium,
                      ),
                      Text(
                        '${facts['kcal']!.round()} kcal · ${facts['proteinG']!.toStringAsFixed(1)} ${_t('g protein', 'غ بروتين')} · '
                        '${facts['carbohydrateG']!.toStringAsFixed(1)} ${_t('g carbs', 'غ كربوهيدرات')} · ${facts['fatG']!.toStringAsFixed(1)} ${_t('g fat', 'غ دهون')}',
                      ),
                    ] else
                      Text(
                        _t(
                          'Verified nutrition values are unavailable for this suggestion.',
                          'لا تتوفر قيم غذائية موثقة لهذا الاقتراح.',
                        ),
                      ),
                    if (detail != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _smartPlanActionInk(context),
                        ),
                        onPressed: () =>
                            Navigator.pop(sheet, '__open_recipe__'),
                        icon: const Icon(Icons.menu_book_outlined),
                        label: Text(
                          _t('Recipe and sources', 'الوصفة والمصادر'),
                        ),
                      ),
                    ],
                    if (current.status == BilPlanStatus.active &&
                        day.date.compareTo(
                              BilPlanDate.iso(
                                ref.read(bilSmartPlanClockProvider)(),
                              ),
                            ) >=
                            0)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _smartPlanActionInk(context),
                        ),
                        key: const ValueKey('bil-smart-plan-meal-schedule'),
                        onPressed: () => Navigator.pop(sheet, '__reschedule__'),
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: Text(_t('Swap meal dates', 'تبديل موعد الوجبة')),
                      ),
                    if (current.status == BilPlanStatus.active &&
                        day.date.compareTo(
                              BilPlanDate.iso(
                                ref.read(bilSmartPlanClockProvider)(),
                              ),
                            ) >=
                            0 &&
                        choices.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        key: const ValueKey('bil-smart-plan-meal-replacement'),
                        itemHeight: null,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: _t(
                            'Compatible replacement',
                            'بديل متوافق',
                          ),
                        ),
                        items: [
                          for (final choice in choices)
                            DropdownMenuItem(
                              value: choice.id,
                              child: Text(
                                catalog.recipeTitle(choice.id, locale: locale),
                              ),
                            ),
                        ],
                        onChanged: (value) => update(() => selected = value),

                        icon: const BilCrystalArrow(
                          extent: 36,
                          child: Icon(Icons.keyboard_arrow_down_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: selected == null
                            ? null
                            : () => Navigator.pop(sheet, selected),
                        child: Text(
                          _t('Preview replacement', 'معاينة الاستبدال'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      if (!mounted || epoch != _ownerEpoch || replacement == null) return;
      _checkAccess();
      if (replacement == '__reschedule__') {
        await _swapMealDates(day, meal);
        return;
      }
      if (replacement == '__open_recipe__') {
        await context.push(
          '/wellness/recipes?recipe=${Uri.encodeQueryComponent(meal.recipeId)}',
        );
        return;
      }
      if (!choices.any((entry) => entry.id == replacement)) {
        throw StateError('smart_plan_dietary_boundary_changed');
      }
      final confirm = await _confirmDialog(
        context: context,
        builder: (dialog) => BilPearlMaterialAlertDialog(
          scrollable: true,
          title: Text(_t('Review meal replacement', 'مراجعة استبدال الوجبة')),
          content: Text(
            '${catalog.recipeTitle(meal.recipeId, locale: locale)}\n↓\n'
            '${catalog.recipeTitle(replacement, locale: locale)}\n\n${day.date} · ${_mealSlot(meal.slot)}',
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
      if (confirm != true || !mounted || epoch != _ownerEpoch) return;
      final next = current.replaceMeal(
        date: BilPlanDate.parse(day.date),
        slot: meal.slot,
        recipeId: replacement,
        now: ref.read(bilSmartPlanClockProvider)(),
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
