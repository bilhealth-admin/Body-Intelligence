part of 'daily_log_page.dart';

extension _DailyLogMutationActions on _DailyLogPageState {
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
      if (mounted) {
        _updateState(() {
          if (selectedFood?.id == food.id) selectedFood = null;
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
}
