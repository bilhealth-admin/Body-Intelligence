part of 'food_log_page.dart';

extension _FoodLogActions on _FoodLogPageState {
  Future<void> _addFood(BuildContext context, Food food) async {
    if (!addingFoodIds.add(food.id)) return;
    try {
      final messenger = ScaffoldMessenger.of(context);
      final addedCopy = _t(context, 'Added to diary');
      final errorCopy = _t(context, 'Could not add food');
      final controller = TextEditingController(
        text: food.servingSize.toString(),
      );
      final quantity = await (() async {
        try {
          return await showDialog<double>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(_t(dialogContext, 'Choose a serving')),
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText:
                      '${food.servingUnit} ${_t(dialogContext, 'quantity')}',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(_t(dialogContext, 'Cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    double.tryParse(controller.text.replaceAll(',', '.')),
                  ),
                  child: Text(_t(dialogContext, 'Add')),
                ),
              ],
            ),
          );
        } finally {
          controller.dispose();
        }
      })();
      if (!mounted || quantity == null || !quantity.isFinite || quantity <= 0) {
        return;
      }
      try {
        await ref
            .read(mealRepositoryProvider)
            .addReviewedMealItemsAtomically(
              date: ref.read(selectedLogDateProvider),
              mealType: mealType,
              items: [(foodId: food.id, quantity: quantity)],
            );
        try {
          await ref.read(foodRepositoryProvider).recordRecent(food.id);
        } on Object {
          // The diary commit already succeeded. Ranking metadata is best effort
          // and must never make a saved meal look unsuccessful.
        }
        ref.invalidate(foodLogPopularFoodsProvider);
        ref.invalidate(dailyMealsProvider);
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(addedCopy)));
      } on Object {
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(errorCopy)));
      }
    } finally {
      addingFoodIds.remove(food.id);
    }
  }

  Future<void> _scanBarcode() async {
    if (barcodeBusy) return;
    barcodeBusy = true;
    try {
      if (!await requestPremiumBarcodeAccess(context, ref) || !mounted) return;
      final barcode = await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(
          builder: (_) => const FoodBarcodeScannerPage(),
        ),
      );
      if (!mounted || barcode == null || barcode.trim().isEmpty) return;
      try {
        final outcome = await ref
            .read(foodRuntimeSearchAuthorityProvider)
            .lookupBarcodeJourney(barcode);
        if (!mounted) return;
        if (outcome.found) {
          search.text = outcome.normalizedBarcode;
          _updateState(() {
            searchResults = outcome.foods.take(30).toList(growable: false);
            searchLoading = false;
          });
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              outcome.invalid
                  ? _t(context, 'Invalid barcode')
                  : _t(context, 'No verified food matched this barcode'),
            ),
          ),
        );
      } on Object {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t(context, 'Barcode lookup failed'))),
        );
      }
    } finally {
      barcodeBusy = false;
    }
  }

  Future<void> _voiceSearch() async {
    if (voiceBusy) return;
    voiceBusy = true;
    try {
      final locale = Localizations.localeOf(context);
      final localeTag = BilLocalePolicy.canonicalTag(locale);
      final result = await MealVoiceInputService(SpeechToText()).capture(
        context: context,
        localeId: localeTag,
        arabic: localeTag == 'ar',
      );
      if (!mounted || result == null || result.foodQuery.trim().isEmpty) {
        return;
      }
      search.text = result.foodQuery.trim();
      _scheduleSearch(search.text);
    } finally {
      voiceBusy = false;
    }
  }

  Future<bool> _ensureCameraPermission() async {
    const policy = BilRuntimePermissionPolicy();
    final current = await policy.status(BilRuntimeCapability.camera);
    if (current == BilRuntimePermissionState.granted) return true;
    if (!mounted) return false;
    if (current == BilRuntimePermissionState.permanentlyDenied ||
        current == BilRuntimePermissionState.restricted) {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await policy.openSettings();
        return false;
      }
      final open = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog.adaptive(
          title: Text(context.strings.text('Camera access is off')),
          content: Text(
            context.strings.text(
              'BIL only uses the camera after you choose barcode or meal-photo capture. Enable camera access in system settings, or continue with manual entry.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.strings.text('Not now')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.strings.text('Open system settings')),
            ),
          ],
        ),
      );
      if (open == true) await policy.openSettings();
      return false;
    }
    return await policy.request(BilRuntimeCapability.camera) ==
        BilRuntimePermissionState.granted;
  }

  Future<void> _analyzeMealImage({
    bool directCamera = false,
    XFile? initialImage,
  }) async {
    if (mealImageBusy) return;
    _updateState(() => mealImageBusy = true);
    final visionCopy = MealVisionUiCopy.ofLocale(
      Localizations.localeOf(context),
    );
    late final bool hasVisionTokens;
    try {
      hasVisionTokens = await ref.read(aiBoostVisionAccessProvider.future);
    } on Object {
      if (!mounted) return;
      _updateState(() => mealImageBusy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(visionCopy.text('camera_failed'))));
      return;
    }
    if (!mounted) return;
    if (!hasVisionTokens) {
      try {
        await context.push('/plans?focus=boost');
      } finally {
        if (mounted) _updateState(() => mealImageBusy = false);
      }
      return;
    }
    final service = MealImageAnalysisService(
      requestedLocale: BilLocalePolicy.canonicalTag(
        Localizations.localeOf(context),
      ),
    );
    if (!service.configured) {
      try {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog.adaptive(
            title: Text(visionCopy.text('unavailable')),
            content: Text(
              const MealImageAnalysisException(
                MealImageAnalysisFailure.notConfigured,
              ).message(
                arabic:
                    BilLocalePolicy.canonicalTag(
                      Localizations.localeOf(context),
                    ) ==
                    'ar',
                languageCode: BilLocalePolicy.canonicalTag(
                  Localizations.localeOf(context),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(visionCopy.text('ok')),
              ),
            ],
          ),
        );
      } finally {
        if (mounted) _updateState(() => mealImageBusy = false);
      }
      return;
    }
    if (!await ensureMealVisionConsent(context) || !mounted) {
      _updateState(() => mealImageBusy = false);
      return;
    }

    XFile? image = initialImage;
    try {
      if (image != null) {
        // Quick Add captured before Food Log mounted; proceed directly to
        // analysis so the idle browser never flashes before the camera.
      } else if (directCamera) {
        if (!await _ensureCameraPermission() || !mounted) return;
        image = await Navigator.of(context).push<XFile>(
          MaterialPageRoute<XFile>(
            builder: (_) => BilCameraCapturePage(
              title: visionCopy.text('take'),
              captureLabel: visionCopy.text('take'),
            ),
          ),
        );
      } else {
        final source = await showModalBottomSheet<ImageSource>(
          context: context,
          showDragHandle: true,
          builder: (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_rounded),
                  title: Text(visionCopy.text('take')),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: Text(visionCopy.text('choose')),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
        if (source == null || !mounted) return;
        if (source == ImageSource.camera &&
            (!await _ensureCameraPermission() || !mounted)) {
          return;
        }
        image = source == ImageSource.camera
            ? await Navigator.of(context).push<XFile>(
                MaterialPageRoute<XFile>(
                  builder: (_) => BilCameraCapturePage(
                    title: visionCopy.text('take'),
                    captureLabel: visionCopy.text('take'),
                  ),
                ),
              )
            : await BilRecoverableImagePicker.instance.pickImage(
                purpose: BilImagePickerPurpose.mealPhoto,
                source: source,
                imageQuality: 88,
                maxWidth: 1800,
              );
      }
      if (image == null || !mounted) return;
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
        if (!mounted || foods.isEmpty) continue;
        final reviewed = await showTrustedVisionFoodMatchDialog(
          context,
          recognizedName: selection.candidate.name,
          foods: foods,
        );
        if (!mounted || reviewed == null) continue;
        final quantity = mealImageAmountInGrams(
          amount: selection.amount,
          unit: selection.unit,
          servingSize: reviewed.servingSize,
          servingUnit: reviewed.servingUnit,
        );
        if (quantity != null) confirmed.add((reviewed, quantity));
      }
      if (confirmed.isEmpty || !mounted) return;
      await ref
          .read(mealRepositoryProvider)
          .addReviewedMealItemsAtomically(
            date: ref.read(selectedLogDateProvider),
            mealType: mealType,
            items: [
              for (final (food, quantity) in confirmed)
                (foodId: food.id, quantity: quantity),
            ],
          );
      for (final (food, _) in confirmed) {
        try {
          await ref.read(foodRepositoryProvider).recordRecent(food.id);
        } on Object {
          // The diary write is authoritative; recency is best effort.
        }
      }
      ref.invalidate(foodLogPopularFoodsProvider);
      ref.invalidate(dailyMealsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(visionCopy.text('confirmed_added'))),
        );
      }
    } on MealImageAnalysisException catch (error) {
      if (!mounted) return;
      if (error.failure == MealImageAnalysisFailure.boostRequired) {
        ref.invalidate(aiBoostVisionAccessProvider);
        await context.push('/plans?focus=boost');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message(
              arabic:
                  BilLocalePolicy.canonicalTag(
                    Localizations.localeOf(context),
                  ) ==
                  'ar',
              languageCode: BilLocalePolicy.canonicalTag(
                Localizations.localeOf(context),
              ),
            ),
          ),
        ),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(visionCopy.text('camera_failed'))));
    } finally {
      if (mounted) _updateState(() => mealImageBusy = false);
      ref.invalidate(aiBoostVisionAccessProvider);
    }
  }

  Future<void> _showQuickAdd() async {
    if (quickAddBusy) return;
    quickAddBusy = true;
    final locale = Localizations.localeOf(context);
    String copy(String english, String arabic) =>
        locale.languageCode.toLowerCase() == 'ar' ? arabic : english;
    try {
      final saved = await showQuickMacroEntryDialog(
        context: context,
        copy: copy,
        mealLabel: _mealTitle(context, mealType),
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
      if (!mounted || saved != true) return;
      ref.invalidate(dailyMealsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t(context, 'Quick Add saved locally.'))),
      );
    } finally {
      quickAddBusy = false;
    }
  }
}
