part of 'daily_log_page.dart';

extension _DailyLogCaptureActions on _DailyLogPageState {
  Future<bool> _ensureCameraPermission() async {
    const policy = BilRuntimePermissionPolicy();
    final current = await policy.status(BilRuntimeCapability.camera);
    if (current == BilRuntimePermissionState.granted) return true;
    if (!mounted) return false;
    if (current == BilRuntimePermissionState.permanentlyDenied ||
        current == BilRuntimePermissionState.restricted) {
      final open = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
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
    final continueRequest = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.strings.text('Allow camera for this action?')),
        content: Text(
          context.strings.text(
            'The camera opens only for the barcode or meal photo you selected. BIL does not request access at startup.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.strings.text('Not now')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.strings.text('Continue')),
          ),
        ],
      ),
    );
    if (continueRequest != true) return false;
    return await policy.request(BilRuntimeCapability.camera) ==
        BilRuntimePermissionState.granted;
  }

  Future<void> _resolveBarcode(String rawBarcode) async {
    final barcodeCopy = BarcodeRuntimeCopy.of(
      Localizations.localeOf(context).toLanguageTag(),
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
    if (!await requestPremiumBarcodeAccess(context, ref) || !mounted) return;
    if (!await _ensureCameraPermission() || !mounted) return;
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const FoodBarcodeScannerPage()),
    );
    if (barcode != null) await _resolveBarcode(barcode);
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
      final hasPaidBoost = await ref.read(aiBoostVisionAccessProvider.future);
      if (!mounted) return;
      if (!hasPaidBoost) {
        await context.push('/plans?focus=boost');
        return;
      }
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
      final imageSource = await showModalBottomSheet<ImageSource>(
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
              ListTile(
                leading: const Icon(Icons.close_rounded),
                title: Text(visionCopy.text('cancel')),
                onTap: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        ),
      );
      if (imageSource == null || !mounted) return;
      if (imageSource == ImageSource.camera &&
          (!await _ensureCameraPermission() || !mounted)) {
        return;
      }
      XFile? image;
      try {
        image = await ImagePicker().pickImage(
          source: imageSource,
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
        if (error.failure == MealImageAnalysisFailure.boostRequired) {
          ref.invalidate(aiBoostVisionAccessProvider);
          await context.push('/plans?focus=boost');
          return;
        }
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
      ref.invalidate(aiBoostVisionAccessProvider);
      if (mounted) _updateState(() => mealImageBusy = false);
    }
  }
}
