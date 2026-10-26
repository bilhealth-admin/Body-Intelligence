part of 'food_log_page.dart';

extension _FoodLogActions on _FoodLogPageState {
  Future<void> _addFood(BuildContext context, Food food) async {
    if (!addingFoodIds.add(food.id)) return;
    _updateState(() {});
    final preferences = ref.read(preferencesRepositoryProvider);
    final meals = ref.read(mealRepositoryProvider);
    final foods = ref.read(foodRepositoryProvider);
    bool ownerIsCurrent() =>
        mounted &&
        identical(preferences, ref.read(preferencesRepositoryProvider));
    try {
      final messenger = ScaffoldMessenger.of(context);
      final addedCopy = _t(context, 'Added to diary');
      final errorCopy = _t(context, 'Could not add food');
      var enteredQuantity = food.servingSize.toString();
      var showQuantityGuide = _tourVisible;
      var quantityEdited = false;
      var dialogSubmitted = false;
      String? quantityError;
      final quantity = await showDialog<double>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, refreshDialog) {
            final quantityGuide = showQuantityGuide && !quantityEdited
                ? FirstUseContextCoachmark(
                    key: const Key('food-log-quantity-guide'),
                    compact: true,
                    title: _foodTourText(
                      dialogContext,
                      en: 'Make it accurate',
                      ar: 'خلّي الكمية دقيقة',
                      fr: 'Soyez précis',
                      es: 'Ajusta la cantidad',
                      tr: 'Miktarı doğru gir',
                    ),
                    message: _foodTourText(
                      dialogContext,
                      en: 'Adjust the serving size, then confirm below. No food is saved until you press Add.',
                      ar: 'عدّل حجم الحصة ثم أكّد بالأسفل. لن نحفظ شيئًا قبل الضغط على إضافة.',
                      fr: 'Ajustez la portion et confirmez avec Ajouter.',
                      es: 'Ajusta la porción y confirma con Añadir.',
                      tr: 'Porsiyonu ayarla ve Ekle ile onayla.',
                    ),
                    icon: Icons.scale_rounded,
                    accent: const Color(0xFFFFDB95),
                    onSkip: () {
                      refreshDialog(() => showQuantityGuide = false);
                      _dismissFoodTour();
                    },
                    skipKey: const Key('food-log-quantity-guide-skip'),
                  )
                : null;
            final saveGuide = showQuantityGuide && quantityEdited
                ? FirstUseContextCoachmark(
                    key: const Key('food-log-save-guide'),
                    compact: true,
                    title: _foodTourText(
                      dialogContext,
                      en: 'Ready to save?',
                      ar: 'جاهز لحفظ وجبتك؟',
                      fr: 'Prêt à enregistrer ?',
                      es: '¿Listo para guardar?',
                      tr: 'Kaydetmeye hazır mısın?',
                    ),
                    message: _foodTourText(
                      dialogContext,
                      en: 'Review your portion, then tap Add. Your meal is saved only after confirmation.',
                      ar: 'راجع الكمية ثم اضغط إضافة. نحفظ وجبتك بعد تأكيدك فقط.',
                      fr: 'Vérifiez la portion, puis appuyez sur Ajouter.',
                      es: 'Revisa la porción y pulsa Añadir.',
                      tr: 'Porsiyonu kontrol et ve Ekle’ye dokun.',
                    ),
                    icon: Icons.check_circle_outline_rounded,
                    onSkip: () {
                      refreshDialog(() => showQuantityGuide = false);
                      _dismissFoodTour();
                    },
                    skipKey: const Key('food-log-save-guide-skip'),
                  )
                : null;
            return BilPearlAlertDialog(
              title: Text(_t(dialogContext, 'Choose a serving')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FirstUseTargetGuide(
                      preferBelow: false,
                      guide: quantityGuide,
                      child: TextFormField(
                        onChanged: (value) {
                          enteredQuantity = value;
                          refreshDialog(() {
                            quantityEdited = true;
                            quantityError = null;
                          });
                        },
                        key: const Key('food-log-serving-quantity-field'),
                        initialValue: enteredQuantity,
                        autofocus: !showQuantityGuide,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText:
                              '${food.servingUnit} ${_t(dialogContext, 'Quantity')}',
                          error: quantityError == null
                              ? null
                              : Text(
                                  quantityError!,
                                  key: const Key('food-log-serving-error'),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (dialogSubmitted) return;
                    dialogSubmitted = true;
                    Navigator.pop(dialogContext);
                  },
                  child: Text(_t(dialogContext, 'Cancel')),
                ),
                FirstUseTargetGuide(
                  preferBelow: false,
                  guide: saveGuide,
                  child: FilledButton(
                    key: const Key('food-log-serving-confirm'),
                    onPressed: () {
                      if (dialogSubmitted) return;
                      final value = parseNutritionNumber(enteredQuantity);
                      if (value == null || value <= 0 || value > 100000) {
                        refreshDialog(() {
                          quantityError = nutritionEntryText(
                            dialogContext,
                            'Enter a quantity greater than 0 and at most 100000.',
                            'أدخل كمية أكبر من صفر ولا تتجاوز 100000.',
                          );
                        });
                        return;
                      }
                      dialogSubmitted = true;
                      Navigator.pop(dialogContext, value);
                    },
                    child: Text(_t(dialogContext, 'Add')),
                  ),
                ),
              ],
            );
          },
        ),
      );
      if (!mounted || quantity == null || !quantity.isFinite || quantity <= 0) {
        return;
      }
      if (!ownerIsCurrent()) return;
      try {
        await meals.addReviewedMealItemsAtomically(
          date: ref.read(selectedLogDateProvider),
          mealType: mealType,
          items: [(foodId: food.id, quantity: quantity)],
          quantitiesInGrams: false,
        );
        try {
          await foods.recordRecent(food.id);
        } on Object {
          // The diary commit already succeeded. Ranking metadata is best effort
          // and must never make a saved meal look unsuccessful.
        }
        if (!ownerIsCurrent()) return;
        ref.invalidate(foodLogPopularFoodsProvider);
        ref.invalidate(dailyMealsProvider);
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(addedCopy)));
        // Food Log is the first-use route opened from Home. A successful
        // atomic repository commit is the only point allowed to celebrate.
        if (_tourVisible) {
          await _dismissFoodTour(completed: true);
        }
        if (!context.mounted) return;
        await FirstMealCelebration.showIfPending(
          context,
          preferences,
          ownerIsCurrent: ownerIsCurrent,
          targetContext: _foodTargets[food.id]?.currentContext,
          onFinished: () {
            if (!ownerIsCurrent()) return;
            _updateState(() {
              _postSaveOwner = preferences.localOwnerId;
              _postSaveGuide = true;
            });
          },
        );
      } on Object {
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(errorCopy)));
      }
    } finally {
      addingFoodIds.remove(food.id);
      if (mounted) _updateState(() {});
    }
  }

  Future<bool> _scanBarcode() async {
    if (barcodeBusy) return true;
    barcodeBusy = true;
    try {
      if (!await requestPremiumBarcodeAccess(context, ref) || !mounted) {
        return false;
      }
      if (!await _ensureCameraPermission() || !mounted) return false;
      final barcode = await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(
          builder: (_) => const FoodBarcodeScannerPage(),
        ),
      );
      if (!mounted || barcode == null || barcode.trim().isEmpty) return false;
      try {
        final outcome = await ref
            .read(foodRuntimeSearchAuthorityProvider)
            .lookupBarcodeJourney(barcode);
        if (!mounted) return true;
        if (outcome.found) {
          search.text = outcome.normalizedBarcode;
          _updateState(() {
            searchResults = outcome.foods.take(30).toList(growable: false);
            searchLoading = false;
          });
          return true;
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
        if (!mounted) return true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t(context, 'Barcode lookup failed'))),
        );
      }
      return true;
    } finally {
      barcodeBusy = false;
    }
  }

  Future<bool> _voiceSearch() async {
    if (voiceBusy) return true;
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
        return false;
      }
      search.text = result.foodQuery.trim();
      _scheduleSearch(search.text);
      return true;
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
      final open = await showBilPearlPermissionDecision(
        context,
        title: context.strings.text('Camera access is off'),
        description: context.strings.text(
          'BIL only uses the camera after you choose barcode or meal-photo capture. Enable camera access in system settings, or continue with manual entry.',
        ),
        cancelLabel: context.strings.text('Not now'),
        confirmLabel: context.strings.text('Open system settings'),
      );
      if (open && mounted) await policy.openSettings();
      return false;
    }
    final result = await policy.request(BilRuntimeCapability.camera);
    return mounted && result == BilRuntimePermissionState.granted;
  }

  Future<void> _analyzeMealImage({
    bool directCamera = false,
    XFile? initialImage,
  }) async {
    if (mealPhotoRequestInFlight) return;
    mealPhotoRequestInFlight = true;
    try {
      await _analyzeMealImageWithSource(
        directCamera: directCamera,
        initialImage: initialImage,
      );
    } finally {
      mealPhotoRequestInFlight = false;
    }
  }

  Future<void> _analyzeMealImageWithSource({
    required bool directCamera,
    XFile? initialImage,
  }) async {
    // Leave the existing Log Food form mounted while checking access,
    // presenting camera/gallery and confirming a selected image.
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
        await explainVisionAccess(context, ref);
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
          builder: (dialogContext) => BilPearlAlertDialog(
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
        final source = await showBilPearlBottomSheet<ImageSource>(
          context: context,
          showDragHandle: true,
          builder: (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    Theme.of(context).platform == TargetPlatform.iOS
                        ? CupertinoIcons.camera
                        : Icons.photo_camera_outlined,
                  ),
                  title: Text(visionCopy.text('take')),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
                ),
                ListTile(
                  leading: Icon(
                    Theme.of(context).platform == TargetPlatform.iOS
                        ? CupertinoIcons.photo
                        : Icons.photo_library_outlined,
                  ),
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
        if (source == ImageSource.gallery && image != null && mounted) {
          final reviewed = await showBilMediaReviewSheet<XFile>(
            context,
            entries: [
              BilMediaReviewEntry(
                value: image,
                preview: FileImage(File(image.path)),
              ),
            ],
          );
          if (!mounted || reviewed == null || reviewed.isEmpty) return;
          image = reviewed.single;
        }
      }
      if (image == null || !mounted) return;
      // The analysis indicator belongs to AI work AFTER image selection, not
      // to the photo source chooser or the camera/gallery permission flow.
      _updateState(() => mealImageBusy = true);
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
        imagePath: image.path,
        mealType: mealType,
        photographedAt: DateTime.now(),
      );
      if (selections == null || selections.isEmpty || !mounted) return;
      final confirmed =
          <({Food food, double quantity, bool quantityInGrams})>[];
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${selection.candidate.name}: ${visionCopy.text('no_match')}',
              ),
            ),
          );
          continue;
        }
        final reviewed = await showReviewedVisionFoodMatchDialog(
          context,
          recognizedName: selection.candidate.name,
          foods: foods,
          reviewedAmount: selection.amount,
          reviewedUnit: selection.unit,
          imagePath: image.path,
        );
        if (!mounted || reviewed == null) continue;
        final portion = mealImageReviewedQuantity(
          amount: reviewed.amount,
          unit: reviewed.unit,
          servingSize: reviewed.food.servingSize,
          servingUnit: reviewed.food.servingUnit,
        );
        if (portion == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${selection.candidate.name}: ${visionCopy.text('unit_mismatch')} '
                '(${reviewed.food.servingUnit})',
              ),
            ),
          );
          continue;
        }
        confirmed.add((
          food: reviewed.food,
          quantity: portion.quantity,
          quantityInGrams: portion.quantityInGrams,
        ));
      }
      if (confirmed.isEmpty || !mounted) return;
      await ref
          .read(mealRepositoryProvider)
          .addReviewedVisionItemsAtomically(
            date: ref.read(selectedLogDateProvider),
            mealType: mealType,
            visionRequestId: analysis.requestId,
            items: [
              for (final item in confirmed)
                (
                  foodId: item.food.id,
                  quantity: item.quantity,
                  quantityInGrams: item.quantityInGrams,
                ),
            ],
          );
      for (final item in confirmed) {
        try {
          await ref.read(foodRepositoryProvider).recordRecent(item.food.id);
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
      // Show the same one-time first-food celebration after a fully reviewed,
      // atomic photo log. A cancelled or rejected image never reaches here.
      if (!mounted) return;
      if (_tourVisible) await _dismissFoodTour(completed: true);
      if (!mounted) return;
      await FirstMealCelebration.showIfPending(
        context,
        ref.read(preferencesRepositoryProvider),
      );
    } on MealImageAnalysisException catch (error) {
      if (!mounted) return;
      if (error.failure == MealImageAnalysisFailure.boostRequired) {
        ref.invalidate(aiVisionCreditStateProvider);
        ref.invalidate(aiBoostVisionAccessProvider);
        await explainVisionAccess(context, ref);
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
      ref.invalidate(aiVisionCreditStateProvider);
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
      // Quick Add writes a real diary snapshot. Only the repository milestone
      // may arm the effect, and cancellation never claims it.
      if (_tourVisible) await _dismissFoodTour(completed: true);
      if (!mounted) return;
      await FirstMealCelebration.showIfPending(
        context,
        ref.read(preferencesRepositoryProvider),
      );
    } finally {
      quickAddBusy = false;
    }
  }
}
