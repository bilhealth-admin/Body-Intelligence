part of 'daily_log_page.dart';

bool dailyLogShouldExportNutritionSample({
  required DateTime selectedDate,
  required DateTime now,
}) => !DateUtils.dateOnly(selectedDate).isAfter(DateUtils.dateOnly(now));

extension _DailyLogMutationActions on _DailyLogPageState {
  Future<void> _save() async {
    if (logSaving || mealSaving) return;
    final date = ref.read(selectedLogDateProvider);
    final repository = ref.read(dailyLogRepositoryProvider);
    bool current() =>
        mounted &&
        identical(ref.read(dailyLogRepositoryProvider), repository) &&
        DateUtils.isSameDay(ref.read(selectedLogDateProvider), date);
    _updateState(() => logSaving = true);
    try {
      final existing = await repository.getForDay(date);
      final ledger = await repository.readLedger(date);
      if (!current()) return;
      final exerciseNotesWereEdited =
          exerciseNotesDraftDate != null &&
          DateUtils.isSameDay(exerciseNotesDraftDate, date);
      final nextExerciseNotes = exerciseNotesWereEdited
          ? DailyExerciseNotesCodec.decode(
              existing?.exerciseNotes,
            ).compose(manualText: exerciseNotes.text)
          : existing?.exerciseNotes;
      // The exercise field is an explicit draft. Preserve the repository value
      // when it was not touched, and merge edits with structured workout rows
      // instead of replacing them with the text controller.
      // Save/Done acknowledges this day. It does not implicitly reopen it.
      if (ledger.state == DayLifecycleState.closed && exerciseNotesWereEdited) {
        if (mounted && current()) {
          _message(
            _tr(
              'Reopen the completed diary before making changes.',
              'أعد فتح اليوميات المكتملة قبل إجراء تغييرات.',
            ),
          );
        }
        return;
      }
      if (ledger.state != DayLifecycleState.closed) {
        await repository.saveNotesAtomically(
          date: date,
          expectedNotes: existing?.notes,
          expectedExerciseNotes: existing?.exerciseNotes,
          notes: existing?.notes,
          exerciseNotes: nextExerciseNotes,
        );
        if (!current()) return;
        final committed = await repository.getForDay(date);
        if (!current()) return;
        if (committed == null ||
            committed.notes != existing?.notes ||
            committed.exerciseNotes != nextExerciseNotes) {
          throw StateError('diary_save_readback_mismatch');
        }
        if (exerciseNotesWereEdited &&
            DateUtils.isSameDay(exerciseNotesDraftDate, date)) {
          exerciseNotesDraftDate = null;
        }
      }
      if (!mounted || !current()) return;
      ref.invalidate(selectedDailyLedgerProvider);
      ref.invalidate(selectedDailyLogProvider);
      context.go('/dashboard');
    } on Object {
      if (current()) {
        _message(
          _tr(
            'Could not confirm the save. Your saved entries are unchanged; retry.',
            'تعذر تأكيد الحفظ. بقيت مدخلاتك المحفوظة كما هي؛ أعد المحاولة.',
          ),
        );
      }
    } finally {
      if (mounted) _updateState(() => logSaving = false);
    }
  }

  Future<void> _saveMeal() async {
    if (mealSaving) return;
    final food = selectedFood;
    if (food == null) return;
    final quantityValue = _parsePositiveQuantity(quantity.text);
    if (quantityValue == null) {
      _message('Enter a quantity from 0.1 to 100000.');
      return;
    }

    final quantityGrams = dailyLogAmountInGrams(
      amount: quantityValue,
      unit: mealQuantityUnit,
    );
    if (quantityGrams == null ||
        !quantityGrams.isFinite ||
        quantityGrams > 100000) {
      _message('Enter a quantity from 0.1 to 100000.');
      return;
    }
    final committedMealType = mealType;
    final committedDate = ref.read(selectedLogDateProvider);
    _updateState(() => mealSaving = true);
    try {
      if (!await _ensureDiaryOpen()) return;
      final mealId = await ref
          .read(mealRepositoryProvider)
          .addReviewedMealItemsAtomically(
            date: committedDate,
            mealType: committedMealType,
            items: [(foodId: food.id, quantity: quantityGrams)],
          );
      ref.invalidate(selectedDailyLedgerProvider);
      // A successful atomic write may finish before a table-watched join
      // publishes its next UI snapshot. Explicitly refresh the authoritative
      // meal list so the saved food becomes visible in this same meal.
      // Never refresh or show a success state before the repository commits.
      ref.invalidate(dailyMealsProvider);
      if (mounted) {
        _updateState(() {
          if (selectedFood?.id == food.id) selectedFood = null;
          // A successful save completes this query. It must not reopen the
          // separate search or displace the saved meal list.
          foodSearch.clear();
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !scrollController.hasClients) return;
          scrollController.jumpTo(0);
        });
      }
      try {
        await ref.read(foodRepositoryProvider).recordRecent(food.id);
      } catch (_) {
        // Recents are convenience metadata and must not make a committed meal
        // look unsuccessful or invite an accidental duplicate retry.
      }
      try {
        await _exportFoodToConnectedHealth(
          food: food,
          quantityGrams: quantityGrams,
          mealId: mealId,
          committedMealType: committedMealType,
          committedDate: committedDate,
        );
      } catch (_) {
        // Connected-health export is best effort after the local commit.
      }
      quantity.text = quantityValue.toStringAsFixed(
        quantityValue.truncateToDouble() == quantityValue ? 0 : 1,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('Meal saved locally.'))),
      );
      // The shared repository creates this marker only after an atomic,
      // successful food write. The overlay does not touch Log Food layout.
      await FirstMealCelebration.showIfPending(
        context,
        ref.read(preferencesRepositoryProvider),
      );
    } catch (_) {
      if (!mounted) return;
      _message('Your saved data was not changed. Try again.');
    } finally {
      if (mounted) _updateState(() => mealSaving = false);
    }
  }

  Future<void> _exportFoodToConnectedHealth({
    required Food food,
    required double quantityGrams,
    required int mealId,
    required String committedMealType,
    required DateTime committedDate,
  }) async {
    // A future diary entry is a plan, not evidence that food was consumed.
    // Keep it in BIL, but never export it as a measured nutrition sample.
    if (!dailyLogShouldExportNutritionSample(
      selectedDate: committedDate,
      now: DateTime.now(),
    )) {
      return;
    }
    final preference = FoodNameHealthSyncPreferenceRepository(
      ref.read(preferencesRepositoryProvider),
    );
    final status = await preference.watch().first;
    if (!status.active) return;
    try {
      final host = GlobalNativeIntegrationHost.instance;
      await host.initialize();
      final flows = host.productFlows;
      if (flows == null) return;
      final servingGrams = dailyLogAmountInGrams(
        amount: food.servingSize,
        unit: food.servingUnit,
      );
      if (servingGrams == null || servingGrams <= 0) return;
      final scale = quantityGrams / servingGrams;
      final now = DateTime.now();
      await flows.healthConnect.export(
        signals: <GlobalHealthSignal>[
          GlobalHealthSignal(
            key: 'nutrition',
            canonicalValue: food.calories * scale,
            canonicalUnit: 'kcal',
            attributes: <String, Object?>{
              'foodName': food.name,
              'mealType': switch (committedMealType) {
                'breakfast' => 1,
                'lunch' => 2,
                'dinner' => 3,
                'snack' => 4,
                _ => 0,
              },
              'proteinGrams': food.protein * scale,
              'carbohydrateGrams': food.carbs * scale,
              'fatGrams': food.fats * scale,
            },
            provenance: GlobalProvenance(
              providerId: 'manual',
              sourceId: 'bil_diary',
              recordId: 'meal-$mealId-food-${food.id}',
              observedAt: now,
              confidence: 1,
              timeZoneId: now.timeZoneName,
            ),
          ),
        ],
        consent: GlobalConsentGrant(
          scope: 'health_connect_nutrition_write',
          state: GlobalConsentState.granted,
          updatedAt: now,
        ),
      );
    } on Object catch (_) {
      // The diary remains the source of truth; native sync can be retried later.
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.strings.text(message))));
  }

  Future<void> _deleteMealItem(MealItem item, String foodName) async {
    if (!await _ensureDiaryOpen()) return;
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => BilPearlMaterialAlertDialog(
        title: Text(context.strings.text('Remove meal item?')),
        content: Text(
          '${context.strings.text('Remove')} $foodName ${context.strings.text('from this meal?')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.strings.text('Remove')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(mealRepositoryProvider).deleteMealItem(item.id);
    }
  }

  Future<void> _editMealItem(MealItem item, Food food) async {
    if (!await _ensureDiaryOpen()) return;
    if (!mounted) return;
    final controller = TextEditingController(text: item.quantity.toString());
    final updated = await showDialog<double>(
      context: context,
      builder: (dialogContext) => BilPearlMaterialAlertDialog(
        title: Text('${context.strings.text('Edit')} ${food.name}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText:
                '${context.strings.text('Quantity')} (${food.servingUnit})',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              double.tryParse(controller.text.replaceAll(',', '.')),
            ),
            child: Text(context.strings.text('Update')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (updated == null) return;
    final normalizedUpdated = _parsePositiveQuantity(updated.toString());
    if (normalizedUpdated == null) return;
    await ref
        .read(mealRepositoryProvider)
        .updateMealItem(id: item.id, quantity: normalizedUpdated);
  }

  Future<void> _showItemActions(MealItem item, Food? food) async {
    if (!await _ensureDiaryOpen()) return;
    if (!mounted) return;
    final foodName = food?.name ?? context.strings.text('Historical food');
    final activeFood = food != null && food.deletedAt == null;
    final favorite = activeFood
        ? await ref.read(foodRepositoryProvider).isFavorite(food.id)
        : false;
    if (!mounted) return;
    final action = await showBilPearlBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const BilSemanticIconBadge(
                kind: BilSemanticIconKind.notes,
              ),
              enabled: activeFood,
              title: Text(_tr('Edit quantity', 'تعديل الكمية')),
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
            ListTile(
              leading: const BilSemanticIconBadge(
                kind: BilSemanticIconKind.notes,
                iconOverride: Icons.copy_outlined,
                appleIconOverride: Icons.copy_outlined,
              ),
              title: Text(_tr('Duplicate item', 'تكرار العنصر')),
              subtitle: Text(
                _tr(
                  'Copies the same quantity and saved nutrition snapshot.',
                  'يُنسخ نفس المقدار ولقطة التغذية المحفوظة.',
                ),
              ),
              onTap: () => Navigator.pop(sheetContext, 'duplicate'),
            ),
            ListTile(
              leading: Icon(favorite ? Icons.favorite : Icons.favorite_border),
              enabled: activeFood,
              title: Text(
                favorite
                    ? _tr('Remove favorite', 'إزالة من المفضلة')
                    : _tr('Add favorite', 'إضافة إلى المفضلة'),
              ),
              onTap: () => Navigator.pop(sheetContext, 'favorite'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(_tr('Delete from meal', 'حذف من الوجبة')),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ],
        ),
      ),
    );
    switch (action) {
      case 'edit':
        await _editMealItem(item, food!);
      case 'duplicate':
        await ref.read(mealRepositoryProvider).duplicateMealItem(item.id);
      case 'favorite':
        await ref.read(foodRepositoryProvider).setFavorite(food!.id, !favorite);
      case 'delete':
        await _deleteMealItem(item, foodName);
    }
  }
}
