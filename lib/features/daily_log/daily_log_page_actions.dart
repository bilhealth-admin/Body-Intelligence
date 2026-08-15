part of 'daily_log_page.dart';

extension _DailyLogPageActions on _DailyLogPageState {
  Future<void> _quickAddMacrosV2() async {
    if (!await _ensureDiaryOpen() || !mounted) return;
    final saved = await showQuickMacroEntryDialog(
      context: context,
      copy: _tr,
      mealLabel: _mealCopy(mealType),
      onSave: (draft) async {
        final date = ref.read(selectedLogDateProvider);
        await ref
            .read(mealRepositoryProvider)
            .addQuickMacroEntry(
              date: date,
              mealType: mealType,
              calories: draft.calories,
              protein: draft.protein,
              carbohydrates: draft.carbohydrates,
              fat: draft.fat,
              caloriesKnown: draft.caloriesKnown,
              proteinKnown: draft.proteinKnown,
              carbohydratesKnown: draft.carbohydratesKnown,
              fatKnown: draft.fatKnown,
              occurredAt: DateTime(
                date.year,
                date.month,
                date.day,
                draft.time.hour,
                draft.time.minute,
              ),
            );
      },
    );
    if (saved != true) return;
    ref.invalidate(selectedDailyLedgerProvider);
    if (mounted) {
      _message(
        _tr('Quick Add saved locally.', 'تم حفظ الإضافة السريعة محليًا.'),
      );
    }
  }

  // Legacy fallback retained for one persisted-draft migration window. New
  // entry points use the extracted V2 dialog above.
  // ignore: unused_element
  Future<void> _quickAddMacros() async {
    if (!await _ensureDiaryOpen() || !mounted) return;
    final formKey = GlobalKey<FormState>();
    final calories = TextEditingController();
    final protein = TextEditingController();
    final carbohydrates = TextEditingController();
    final fat = TextEditingController();
    var time = TimeOfDay.now();
    var saving = false;
    String? saveError;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          double value(TextEditingController controller) =>
              double.parse(controller.text.trim().replaceAll(',', '.'));
          String? validateNumber(String? raw, double maximum) {
            final normalized = (raw ?? '').trim().replaceAll(',', '.');
            if (normalized.isEmpty) return null;
            final parsed = double.tryParse(normalized);
            if (parsed == null ||
                !parsed.isFinite ||
                parsed < 0 ||
                parsed > maximum) {
              return _tr(
                'Enter a non-negative number.',
                'أدخل رقمًا غير سالب.',
              );
            }
            return null;
          }

          return PopScope(
            canPop: !saving,
            child: AlertDialog(
              title: Text(_tr('Quick Add macros', 'إضافة سريعة للمغذيات')),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final field in [
                        (
                          controller: calories,
                          label: _tr('Calories', 'السعرات'),
                          maximum: 10000.0,
                        ),
                        (
                          controller: protein,
                          label: _tr('Protein (g)', 'البروتين (جم)'),
                          maximum: 2000.0,
                        ),
                        (
                          controller: carbohydrates,
                          label: _tr('Carbohydrates (g)', 'الكربوهيدرات (جم)'),
                          maximum: 2000.0,
                        ),
                        (
                          controller: fat,
                          label: _tr('Fat (g)', 'الدهون (جم)'),
                          maximum: 2000.0,
                        ),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TextFormField(
                            controller: field.controller,
                            enabled: !saving,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(labelText: field.label),
                            validator: (value) =>
                                validateNumber(value, field.maximum),
                          ),
                        ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.schedule_rounded),
                        title: Text(_tr('Time', 'الوقت')),
                        trailing: Text(time.format(context)),
                        enabled: !saving,
                        onTap: saving
                            ? null
                            : () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: time,
                                );
                                if (picked != null) {
                                  setDialogState(() => time = picked);
                                }
                              },
                      ),
                      if (saveError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            saveError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: Text(_tr('Cancel', 'إلغاء')),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          FocusScope.of(dialogContext).unfocus();
                          await Future<void>.delayed(
                            const Duration(milliseconds: 120),
                          );
                          double optionalValue(
                            TextEditingController controller,
                          ) => controller.text.trim().isEmpty
                              ? 0
                              : value(controller);
                          final values = [
                            calories,
                            protein,
                            carbohydrates,
                            fat,
                          ].map(optionalValue).toList(growable: false);
                          final known = [calories, protein, carbohydrates, fat]
                              .map(
                                (controller) =>
                                    controller.text.trim().isNotEmpty,
                              )
                              .toList(growable: false);
                          if (values.every((entry) => entry == 0)) {
                            setDialogState(
                              () => saveError = _tr(
                                'Enter at least one valid calorie or macro value.',
                                'أدخل قيمة صحيحة واحدة على الأقل للسعرات أو المغذيات.',
                              ),
                            );
                            return;
                          }
                          setDialogState(() {
                            saving = true;
                            saveError = null;
                          });
                          final date = ref.read(selectedLogDateProvider);
                          try {
                            await ref
                                .read(mealRepositoryProvider)
                                .addQuickMacroEntry(
                                  date: date,
                                  mealType: mealType,
                                  calories: values[0],
                                  protein: values[1],
                                  carbohydrates: values[2],
                                  fat: values[3],
                                  caloriesKnown: known[0],
                                  proteinKnown: known[1],
                                  carbohydratesKnown: known[2],
                                  fatKnown: known[3],
                                  occurredAt: DateTime(
                                    date.year,
                                    date.month,
                                    date.day,
                                    time.hour,
                                    time.minute,
                                  ),
                                );
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext, true);
                            }
                          } catch (_) {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                saving = false;
                                saveError = _tr(
                                  'Could not save this entry. Try again.',
                                  'تعذر حفظ هذه الإضافة. حاول مرة أخرى.',
                                );
                              });
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_tr('Add', 'إضافة')),
                ),
              ],
            ),
          );
        },
      ),
    );
    // These short-lived controllers are intentionally left to GC. Android's
    // IME schedules caret callbacks beyond the dialog route animation; manual
    // disposal here causes use-after-dispose and inherited-element teardown
    // assertions on real devices.
    if (saved != true) return;
    ref.invalidate(selectedDailyLedgerProvider);
    if (mounted) {
      _message(
        _tr('Quick Add saved locally.', 'تم حفظ الإضافة السريعة محليًا.'),
      );
    }
  }

  Future<bool> _ensureDiaryOpen() async {
    final ledger = await ref
        .read(dailyLogRepositoryProvider)
        .readLedger(ref.read(selectedLogDateProvider));
    if (ledger.state != DayLifecycleState.closed) return true;
    if (mounted) {
      _message(
        _tr(
          'Reopen the completed diary before making changes.',
          'أعد فتح اليوميات المكتملة قبل إجراء تغييرات.',
        ),
      );
    }
    return false;
  }

  Future<void> _completeDiary() async {
    final date = ref.read(selectedLogDateProvider);
    final repository = ref.read(dailyLogRepositoryProvider);
    final ledger = await repository.readLedger(date);
    if (ledger.state == DayLifecycleState.notStarted) {
      await repository.startDay(date);
    }
    await repository.closeDay(date);
    ref.invalidate(selectedDailyLogProvider);
    ref.invalidate(selectedDailyLedgerProvider);
    if (mounted) {
      _message(_tr('Diary completed', 'اكتملت اليوميات'));
    }
  }

  Future<void> _reopenDiary() async {
    final date = ref.read(selectedLogDateProvider);
    await ref.read(dailyLogRepositoryProvider).reopenDay(date);
    ref.invalidate(selectedDailyLogProvider);
    ref.invalidate(selectedDailyLedgerProvider);
    if (mounted) {
      _message(_tr('Diary reopened', 'أُعيد فتح اليوميات'));
    }
  }

  Future<void> _copyPreviousDayMeals() async {
    final destination = ref.read(selectedLogDateProvider);
    final source = destination.subtract(const Duration(days: 1));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_tr('Copy yesterday’s meals?', 'نسخ وجبات اليوم السابق؟')),
        content: Text(
          _arabic
              ? 'ستُنسخ الوجبات وكمياتها إلى هذا اليوم. لن تُستبدل أي وجبات موجودة.'
              : 'Meals and their quantities will be copied to this day. Existing meals will not be replaced.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_tr('Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_tr('Copy', 'نسخ')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final copied = await ref
          .read(mealRepositoryProvider)
          .copyDay(sourceDate: source, destinationDate: destination);
      if (!mounted) return;
      _message(
        _arabic
            ? copied == 0
                  ? 'لا توجد وجبات في اليوم السابق.'
                  : 'تم نسخ $copied وجبة بعد مراجعتك.'
            : copied == 0
            ? 'There were no meals on the previous day.'
            : '$copied meals copied after your confirmation.',
      );
    } on StateError {
      _message(
        _arabic
            ? 'يحتوي هذا اليوم على وجبات بالفعل. لم يتم استبدالها أو مضاعفتها.'
            : 'This day already has meals. Nothing was replaced or duplicated.',
      );
    }
  }

  Future<void> _copyToMultipleDays() async {
    if (!await _ensureDiaryOpen() || !mounted) return;
    final count = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_tr('Copy to multiple days', 'نسخ إلى عدة أيام')),
        content: Text(
          _tr(
            'Choose how many upcoming empty days receive this diary. Existing days are never replaced.',
            'اختر عدد الأيام الفارغة القادمة التي ستستقبل هذه اليومية. لن تُستبدل الأيام الموجودة.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_tr('Cancel', 'إلغاء')),
          ),
          for (final days in const [2, 3, 7])
            FilledButton.tonal(
              onPressed: () => Navigator.pop(dialogContext, days),
              child: Text('$days'),
            ),
        ],
      ),
    );
    if (count == null || !mounted) return;
    final source = ref.read(selectedLogDateProvider);
    final destinations = List.generate(
      count,
      (index) => source.add(Duration(days: index + 1)),
    );
    try {
      final result = await ref
          .read(mealRepositoryProvider)
          .copyDayToDates(sourceDate: source, destinationDates: destinations);
      ref.invalidate(selectedDailyLedgerProvider);
      if (mounted) {
        _message(
          _tr(
            'Diary copied to {count} days.',
            'تم نسخ اليومية إلى ${result.length} أيام.',
          ).replaceAll('{count}', '${result.length}'),
        );
      }
    } on StateError {
      if (mounted) {
        _message(
          _tr(
            'One of the selected days already has meals. Nothing was copied.',
            'يحتوي أحد الأيام المحددة على وجبات. لم يتم نسخ أي شيء.',
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!await _ensureDiaryOpen()) return;
    final date = ref.read(selectedLogDateProvider);
    final repository = ref.read(dailyLogRepositoryProvider);
    await repository.save(
      date: date,
      notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
      exerciseNotes: exerciseNotes.text.trim().isEmpty
          ? null
          : exerciseNotes.text.trim(),
    );
    ref.invalidate(selectedDailyLedgerProvider);
    if (!mounted) return;
    context.go('/dashboard');
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
      unit: food.servingUnit,
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
        );
      } catch (_) {
        // Connected-health export is best effort after the local commit.
      }
      quantity.text = quantityValue.toStringAsFixed(
        quantityValue.truncateToDouble() == quantityValue ? 0 : 1,
      );
      if (!mounted) return;
      _updateState(() {
        if (selectedFood?.id == food.id) selectedFood = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('Meal saved locally.'))),
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
  }) async {
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

  Future<void> _addWater([int? quickAmount]) async {
    if (waterSaving) return;
    if (!await _ensureDiaryOpen()) return;
    final amount = quickAmount ?? int.tryParse(water.text);
    if (amount == null || amount <= 0 || amount > 5000) {
      _message('Enter a water amount from 1 to 5000 ml.');
      return;
    }
    final date = ref.read(selectedLogDateProvider);
    final now = DateTime.now();
    final outcome = await waterMutations.add(
      repository: ref.read(waterRepositoryProvider),
      occurredAt: DateTime(
        date.year,
        date.month,
        date.day,
        now.hour,
        now.minute,
      ),
      amountMl: amount,
    );
    if (outcome == WaterMutationOutcome.success) {
      water.clear();
    } else if (outcome == WaterMutationOutcome.failure) {
      _message('Water could not be saved. Try again.');
    }
  }

  Future<void> _deleteWater(int id) async {
    final outcome = await waterMutations.delete(
      repository: ref.read(waterRepositoryProvider),
      id: id,
    );
    if (outcome == WaterMutationOutcome.failure) {
      _message('Water entry could not be removed. Try again.');
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
      builder: (dialogContext) => AlertDialog(
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
      builder: (dialogContext) => AlertDialog(
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
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              enabled: activeFood,
              title: Text(_tr('Edit quantity', 'تعديل الكمية')),
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
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

  Future<void> _resolveBarcode(String rawBarcode) async {
    final barcodeCopy = BarcodeRuntimeCopy.of(
      Localizations.localeOf(context).languageCode,
    );
    final outcome = await ref
        .read(foodRuntimeSearchAuthorityProvider)
        .lookupBarcodeJourney(rawBarcode);
    if (!mounted) return;

    if (outcome.invalid) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(barcodeCopy.invalidTitle),
          content: Text(barcodeCopy.invalidBody),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.strings.text('OK')),
            ),
          ],
        ),
      );
      return;
    }

    if (outcome.foods.isNotEmpty) {
      final reviewed = await showBarcodeFoodReviewDialog(
        context,
        barcode: outcome.normalizedBarcode,
        candidates: outcome.foods,
      );
      if (reviewed == null || !mounted) return;
      _updateState(() => selectedFood = reviewed);
      foodSearch.text = reviewed.name;
      return;
    }

    if (outcome.product != null) {
      final submitReview = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            productKindLabel(
              outcome.product!.kind,
              arabic: _arabic,
              languageCode: Localizations.localeOf(context).languageCode,
            ),
          ),
          content: Text(
            productIdentityExplanation(
              outcome.product!,
              arabic: _arabic,
              languageCode: Localizations.localeOf(context).languageCode,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_tr('Submit for review', 'إرسال للمراجعة')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.strings.text('OK')),
            ),
          ],
        ),
      );
      if (submitReview == true && mounted) {
        await showProductReviewSubmissionDialog(
          context,
          barcode: outcome.normalizedBarcode,
          suggestedProduct: outcome.product,
        );
      }
      return;
    }

    final submitReview = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.strings.text(
            outcome.degraded
                ? barcodeCopy.unavailableTitle
                : barcodeCopy.notFoundTitle,
          ),
        ),
        content: Text(
          outcome.degraded
              ? barcodeCopy.unavailableBody
              : barcodeCopy.notFoundBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_tr('Submit for review', 'إرسال للمراجعة')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.strings.text('OK')),
          ),
        ],
      ),
    );
    if (submitReview == true && mounted) {
      await showProductReviewSubmissionDialog(
        context,
        barcode: outcome.normalizedBarcode,
      );
    }
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const FoodBarcodeScannerPage()),
    );
    if (barcode != null) await _resolveBarcode(barcode);
  }

  Future<void> _manualBarcode() async {
    final controller = TextEditingController();
    final barcode = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.strings.text('Manual barcode lookup')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 14,
          decoration: InputDecoration(
            labelText: context.strings.text('Barcode digits'),
            helperText: context.strings.text(
              'Enter an 8, 12, 13, or 14 digit GTIN.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(context.strings.text('Search')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (barcode != null && barcode.isNotEmpty) {
      await _resolveBarcode(barcode);
    }
  }

  Future<void> _captureMealVoice() async {
    final service = MealVoiceInputService(SpeechToText());
    final result = await service.capture(
      context: context,
      localeId: Localizations.localeOf(context).languageCode,
      arabic: _arabic,
    );
    if (!mounted || result == null || result.foodQuery.isEmpty) return;

    foodSearch.text = result.foodQuery;
    final foods = await ref
        .read(foodRuntimeSearchAuthorityProvider)
        .search(result.foodQuery, limit: 10);
    if (!mounted) return;
    if (foods.isEmpty) {
      _message(
        _arabic
            ? 'تم تدوين كلامك، لكن لا يوجد تطابق غذائي موثوق. راجع العبارة أو أنشئ طعامًا مخصصًا.'
            : 'Your words were captured, but no trusted food matched them. Review the phrase or create a custom food.',
      );
      return;
    }
    _updateState(() => selectedFood = foods.first);
  }

  Future<void> _analyzeMealImage() async {
    if (mealImageBusy) return;
    _updateState(() => mealImageBusy = true);
    try {
      final visionCopy = MealVisionUiCopy.ofLocale(
        Localizations.localeOf(context),
      );
      final acceptedGuide = await openMealImageGuide(context);
      if (acceptedGuide != true || !mounted) return;
      final service = MealImageAnalysisService(
        requestedLocale: Localizations.localeOf(context).languageCode,
      );
      if (!service.configured) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(visionCopy.text('unavailable')),
            content: Text(
              const MealImageAnalysisException(
                MealImageAnalysisFailure.notConfigured,
              ).message(
                arabic: _arabic,
                languageCode: Localizations.localeOf(context).languageCode,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(visionCopy.text('ok')),
              ),
            ],
          ),
        );
        return;
      }
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(visionCopy.text('take')),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(visionCopy.text('choose')),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null) return;
      XFile? image;
      try {
        image = await ImagePicker().pickImage(
          source: source,
          imageQuality: 88,
          maxWidth: 1800,
        );
      } catch (_) {
        if (!mounted) return;
        _message(visionCopy.text('camera_failed'));
        return;
      }
      if (image == null || !mounted) return;
      try {
        final analysis = await service.analyze(image);
        if (!mounted) return;
        if (analysis.candidates.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(visionCopy.text('none'))));
          return;
        }
        final selections = await showMealImageReviewDialog(
          context,
          analysis: analysis,
        );
        if (selections == null || selections.isEmpty || !mounted) return;
        final confirmed = <(Food, double)>[];
        for (final selection in selections) {
          final authority = ref.read(foodRuntimeSearchAuthorityProvider);
          final exactId = selection.candidate.verifiedFoodRecordId;
          final exact = exactId == null
              ? null
              : await authority.findExact(exactId);
          final requiresExact =
              selection.candidate.nutritionResolution ==
              MealNutritionResolution.verifiedFoodRecord;
          final foods = requiresExact
              ? exact != null && exact.verified
                    ? <Food>[exact]
                    : const <Food>[]
              : (await authority.search(
                  selection.candidate.name,
                  limit: 10,
                )).where((food) => food.verified).toList(growable: false);
          if (!mounted) return;
          if (foods.isEmpty) {
            foodSearch.text = selection.candidate.name;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${selection.candidate.name}: ${visionCopy.text('no_match')}',
                ),
              ),
            );
            continue;
          }
          final reviewed = await showTrustedVisionFoodMatchDialog(
            context,
            recognizedName: selection.candidate.name,
            foods: foods,
          );
          if (!mounted) return;
          if (reviewed != null) {
            final quantityGrams = mealImageAmountInGrams(
              amount: selection.amount,
              unit: selection.unit,
              servingSize: reviewed.servingSize,
              servingUnit: reviewed.servingUnit,
            );
            if (quantityGrams == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${selection.candidate.name}: '
                    '${visionCopy.text('unit_mismatch')} '
                    '(${reviewed.servingUnit})',
                  ),
                ),
              );
              continue;
            }
            confirmed.add((reviewed, quantityGrams));
          }
        }
        if (confirmed.isEmpty || !await _ensureDiaryOpen()) return;
        final repository = ref.read(mealRepositoryProvider);
        await repository.addReviewedMealItemsAtomically(
          date: ref.read(selectedLogDateProvider),
          mealType: mealType,
          items: [
            for (final (food, quantityGrams) in confirmed)
              (foodId: food.id, quantity: quantityGrams),
          ],
        );
        for (final (food, _) in confirmed) {
          try {
            await ref.read(foodRepositoryProvider).recordRecent(food.id);
          } on Object {
            // The atomic diary commit already succeeded. Recency is a
            // best-effort ranking signal and must never make a saved meal look
            // like a failed operation that the user should repeat.
          }
        }
        ref.invalidate(selectedDailyLedgerProvider);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(visionCopy.text('confirmed_added'))),
        );
      } on MealImageAnalysisException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.message(
                arabic: _arabic,
                languageCode: Localizations.localeOf(context).languageCode,
              ),
            ),
          ),
        );
      } catch (_) {
        if (!mounted) return;
        const failure = MealImageAnalysisException(
          MealImageAnalysisFailure.serviceUnavailable,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failure.message(
                arabic: _arabic,
                languageCode: Localizations.localeOf(context).languageCode,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) _updateState(() => mealImageBusy = false);
    }
  }
}
