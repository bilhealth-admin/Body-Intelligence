part of 'food_log_page.dart';

extension _FoodLogPhotoActions on _FoodLogPageState {
  Future<void> _analyzeMealImage({
    bool directCamera = false,
    XFile? initialImage,
  }) async {
    if (mealPhotoRequestInFlight) return;
    final estimateDatabase =
        const bool.fromEnvironment('BIL_GEMINI_PHOTO_ESTIMATES_V2')
        ? ref.read(databaseProvider)
        : null;
    final estimateVisit = estimateDatabase == null
        ? null
        : MealVisionEstimateVisit.capture(
            database: estimateDatabase,
            isCurrentDatabase: () =>
                mounted &&
                identical(ref.read(databaseProvider), estimateDatabase),
          );
    if (estimateDatabase != null && estimateVisit == null) return;
    final estimateDay = ref.read(selectedLogDateProvider);
    final estimateMealType = mealType;
    mealPhotoRequestInFlight = true;
    try {
      await _analyzeMealImageWithSource(
        directCamera: directCamera,
        initialImage: initialImage,
        estimateVisit: estimateVisit,
        estimateDay: estimateDay,
        estimateMealType: estimateMealType,
      );
    } finally {
      estimateVisit?.dispose();
      mealPhotoRequestInFlight = false;
    }
  }

  Future<void> _analyzeMealImageWithSource({
    required bool directCamera,
    XFile? initialImage,
    MealVisionEstimateVisit? estimateVisit,
    required DateTime estimateDay,
    required String estimateMealType,
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
      if ((!mounted || estimateVisit?.current == false)) return;
      _updateState(() => mealImageBusy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(visionCopy.text('camera_failed'))));
      return;
    }
    if ((!mounted || estimateVisit?.current == false)) return;
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
    final consent = service.usesGeminiEstimates
        ? await ensureMealVisionEstimateConsent(
            context,
            isCurrent: () => estimateVisit?.current == true,
          )
        : await ensureMealVisionConsent(context);
    if (!consent || (!mounted || estimateVisit?.current == false)) {
      _updateState(() => mealImageBusy = false);
      return;
    }

    XFile? image = initialImage;
    try {
      if (image != null) {
        // Quick Add captured before Food Log mounted; proceed directly to
        // analysis so the idle browser never flashes before the camera.
      } else if (directCamera) {
        if (!await _ensureCameraPermission() ||
            (!mounted || estimateVisit?.current == false)) {
          return;
        }
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
        if (source == null || (!mounted || estimateVisit?.current == false)) {
          return;
        }
        if (source == ImageSource.camera &&
            (!await _ensureCameraPermission() ||
                (!mounted || estimateVisit?.current == false))) {
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
          if ((!mounted || estimateVisit?.current == false) ||
              reviewed == null ||
              reviewed.isEmpty) {
            return;
          }
          image = reviewed.single;
        }
      }
      if (image == null || (!mounted || estimateVisit?.current == false)) {
        return;
      }
      // The analysis indicator belongs to AI work AFTER image selection, not
      // to the photo source chooser or the camera/gallery permission flow.
      _updateState(() => mealImageBusy = true);
      final analysis = service.usesGeminiEstimates
          ? await service.analyzeForOwner(
              image,
              isCurrent: () => estimateVisit?.current == true,
            )
          : await service.analyze(image);
      if ((!mounted || estimateVisit?.current == false)) return;
      if (analysis.candidates.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(visionCopy.text('none'))));
        return;
      }
      if (analysis.schemaVersion == 2) {
        if (estimateVisit == null || !estimateVisit.current) return;
        final saved = await reviewGeminiVisionForDiary(
          context,
          analysis: analysis,
          visit: estimateVisit,
          day: estimateDay,
          mealType: estimateMealType,
          imagePath: image.path,
        );
        if (saved && mounted && estimateVisit.current) {
          ref.invalidate(foodLogPopularFoodsProvider);
          ref.invalidate(dailyMealsProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(visionCopy.text('confirmed_added'))),
          );
          if (_tourVisible) await _dismissFoodTour(completed: true);
          if (mounted && estimateVisit.current) {
            await FirstMealCelebration.showIfPending(
              context,
              ref.read(preferencesRepositoryProvider),
            );
          }
        }
        return;
      }
      final selections = await showMealImageReviewDialog(
        context,
        analysis: analysis,
        imagePath: image.path,
        mealType: mealType,
        photographedAt: DateTime.now(),
      );
      if (selections == null ||
          selections.isEmpty ||
          (!mounted || estimateVisit?.current == false)) {
        return;
      }
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
        if ((!mounted || estimateVisit?.current == false)) return;
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
        if ((!mounted || estimateVisit?.current == false) || reviewed == null) {
          continue;
        }
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
      if (confirmed.isEmpty || (!mounted || estimateVisit?.current == false)) {
        return;
      }
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
      if ((!mounted || estimateVisit?.current == false)) return;
      if (_tourVisible) await _dismissFoodTour(completed: true);
      if ((!mounted || estimateVisit?.current == false)) return;
      await FirstMealCelebration.showIfPending(
        context,
        ref.read(preferencesRepositoryProvider),
      );
    } on MealImageAnalysisException catch (error) {
      if ((!mounted || estimateVisit?.current == false)) return;
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
      if ((!mounted || estimateVisit?.current == false)) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(visionCopy.text('camera_failed'))));
    } finally {
      if (mounted) {
        _updateState(() => mealImageBusy = false);
        ref.invalidate(aiVisionCreditStateProvider);
        ref.invalidate(aiBoostVisionAccessProvider);
      }
    }
  }
}
