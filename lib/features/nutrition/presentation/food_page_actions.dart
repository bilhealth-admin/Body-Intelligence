part of '../food_page.dart';

extension _FoodPageActions on _FoodPageState {
  Future<void> _createFood([String? initialBarcode]) async {
    final created = await showDialog<_FoodDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CustomFoodDialog(
        initialBarcode: initialBarcode,
        onSave: (draft) async {
          final localeCode = Localizations.localeOf(context).toLanguageTag();
          final id = await ref
              .read(foodRepositoryProvider)
              .addFood(
                name: draft.name,
                arabicName: draft.arabicName,
                barcode: draft.barcode,
                category: 'custom',
                servingSize: draft.servingSize,
                servingUnit: draft.servingUnit,
                calories: draft.calories,
                protein: draft.protein,
                carbs: draft.carbs,
                fats: draft.fats,
                caloriesKnown: draft.caloriesKnown,
                proteinKnown: draft.proteinKnown,
                carbsKnown: draft.carbsKnown,
                fatsKnown: draft.fatsKnown,
                fiber: draft.fiber,
                sodium: draft.sodium,
                potassium: draft.potassium,
                calcium: draft.calcium,
                magnesium: draft.magnesium,
                sugar: draft.sugar,
              );
          await ref
              .read(communityFoodSyncServiceProvider)
              .publishFood(id, localeCode: localeCode);
        },
      ),
    );
    if (created == null) return;
    await _runSearch(search.text);
  }

  Future<void> _cameraBarcodeLookup() async {
    if (!await requestPremiumBarcodeAccess(context, ref) || !mounted) return;
    if (!await _ensureCameraPermission() || !mounted) return;
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const FoodBarcodeScannerPage()),
    );
    if (barcode == null || barcode.isEmpty) return;
    await _lookupBarcodeValue(barcode);
  }

  Future<bool> _ensureCameraPermission() async {
    const policy = BilRuntimePermissionPolicy();
    final current = await policy.status(BilRuntimeCapability.camera);
    if (current == BilRuntimePermissionState.granted) return true;
    if (!mounted) return false;
    final blocked =
        current == BilRuntimePermissionState.permanentlyDenied ||
        current == BilRuntimePermissionState.restricted;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.strings.text(
            blocked ? 'Camera access is off' : 'Allow camera for this action?',
          ),
        ),
        content: Text(
          context.strings.text(
            blocked
                ? 'Enable camera access in system settings to scan a barcode. Manual barcode entry remains available.'
                : 'BIL opens the camera only for the barcode scan you selected and never at startup.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.strings.text('Not now')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              context.strings.text(
                blocked ? 'Open system settings' : 'Continue',
              ),
            ),
          ),
        ],
      ),
    );
    if (proceed != true) return false;
    if (blocked) {
      await policy.openSettings();
      return false;
    }
    return await policy.request(BilRuntimeCapability.camera) ==
        BilRuntimePermissionState.granted;
  }

  Future<void> _lookupBarcodeValue(String barcode) async {
    final t = context.strings.text;
    final barcodeCopy = BarcodeRuntimeCopy.of(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final outcome = await ref
        .read(foodRuntimeSearchAuthorityProvider)
        .lookupBarcodeJourney(barcode);

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
              child: Text(t('OK')),
            ),
          ],
        ),
      );
      return;
    }

    if (outcome.found) {
      search.text = outcome.normalizedBarcode;
      _mutateFoodPage(() {
        results = _foodsInScope(outcome.foods);
        runtimeSearchState = switch (outcome.source) {
          FoodRuntimeSearchSource.catalogAndLocal =>
            _RuntimeSearchUiState.catalogAndLocal,
          FoodRuntimeSearchSource.localOnly => _RuntimeSearchUiState.localOnly,
          FoodRuntimeSearchSource.localFallback =>
            _RuntimeSearchUiState.localFallback,
        };
      });
      return;
    }

    if (outcome.product != null) {
      final arabic = Localizations.localeOf(context).languageCode == 'ar';
      final submitReview = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            productKindLabel(
              outcome.product!.kind,
              arabic: arabic,
              languageCode: Localizations.localeOf(context).languageCode,
            ),
          ),
          content: Text(
            productIdentityExplanation(
              outcome.product!,
              arabic: arabic,
              languageCode: Localizations.localeOf(context).languageCode,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                nutritionText(context, 'Submit for review', 'إرسال للمراجعة'),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t('OK')),
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

    _mutateFoodPage(() {
      runtimeSearchState = outcome.degraded
          ? _RuntimeSearchUiState.localFallback
          : _RuntimeSearchUiState.localOnly;
    });

    final action = await showDialog<_UnverifiedBarcodeAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          outcome.degraded ? t('Catalog unavailable') : t('Barcode not found'),
        ),
        content: Text(
          outcome.degraded
              ? t(
                  'The verified catalog could not be reached. BIL will not invent nutrition values. You can create this product from its label, or try again later.',
                )
              : t(
                  'No verified product matched this barcode. BIL will not invent nutrition values. You can create a food from the product label and the barcode will be prefilled.',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _UnverifiedBarcodeAction.dismiss),
            child: Text(t('Not now')),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _UnverifiedBarcodeAction.submitReview),
            child: Text(
              nutritionText(context, 'Submit for review', 'إرسال للمراجعة'),
            ),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(
              context,
              _UnverifiedBarcodeAction.scanProductLabel,
            ),
            icon: const Icon(Icons.document_scanner_rounded),
            label: Text(
              nutritionText(context, 'Scan product label', 'امسح ملصق المنتج'),
            ),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, _UnverifiedBarcodeAction.createFood),
            child: Text(t('Create custom food')),
          ),
        ],
      ),
    );

    if (action == _UnverifiedBarcodeAction.submitReview && mounted) {
      await showProductReviewSubmissionDialog(
        context,
        barcode: outcome.normalizedBarcode,
      );
    } else if (action == _UnverifiedBarcodeAction.createFood) {
      await _createFood(outcome.normalizedBarcode);
    } else if (action == _UnverifiedBarcodeAction.scanProductLabel && mounted) {
      // Barcode entitlement was enforced upstream. This screen is the
      // authoritative weekly AI Coach and paid AI Boost allowance gate; its
      // capture route is review-first and never auto-logs.
      final accepted = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => const MealImageGuidePage(),
          fullscreenDialog: true,
        ),
      );
      if (accepted == true && mounted) {
        await context.push(
          '/intelligence-center?vision=capture&barcode=${Uri.encodeQueryComponent(outcome.normalizedBarcode)}',
        );
      }
    }
  }

  Future<void> _barcodeLookup() async {
    if (!await requestPremiumBarcodeAccess(context, ref) || !mounted) return;
    final t = context.strings.text;
    final barcode = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _ManualBarcodeDialog(
        t: t,
        onCancel: () => Navigator.pop(dialogContext),
        onSubmit: (value) => Navigator.pop(dialogContext, value),
      ),
    );

    if (barcode == null) return;

    await _lookupBarcodeValue(barcode);
  }

  Future<void> _showAddFoodActions() async {
    final method = await showModalBottomSheet<_FoodAddMethod>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => _FoodAddActionSheet(showPremiumLabel: widget.embedded),
    );
    if (!mounted || method == null) return;
    switch (method) {
      case _FoodAddMethod.scanBarcode:
        await _cameraBarcodeLookup();
        return;
      case _FoodAddMethod.manualBarcode:
        await _barcodeLookup();
        return;
      case _FoodAddMethod.mealPhoto:
        final origin = widget.embedded ? '/nutrition' : '/foods';
        final route = Uri(
          path: '/daily-log',
          queryParameters: {'action': 'photo', 'from': origin},
        ).toString();
        await context.push(route);
        return;
      case _FoodAddMethod.customFood:
        await _createFood();
        return;
    }
  }
}
