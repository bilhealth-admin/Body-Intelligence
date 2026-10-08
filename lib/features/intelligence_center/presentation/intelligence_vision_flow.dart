part of 'intelligence_center_page.dart';

// Native I/O boundaries stay injectable so cancellation, permissions and late
// results can be exercised without opening hardware or making a paid request.
final intelligenceCoachImagePickerProvider =
    Provider<BilRecoverableImagePicker>(
      (ref) => BilRecoverableImagePicker.instance,
    );
final intelligenceCoachImageAnalysisProvider =
    Provider<MealImageAnalysisService Function(String)>(
      (ref) =>
          (locale) => MealImageAnalysisService(requestedLocale: locale),
    );
final intelligenceCoachMealVisionConsentProvider =
    Provider<Future<bool> Function(BuildContext)>((ref) {
      return ensureMealVisionConsent;
    });

final intelligenceCoachMediaRuntimePermissionProvider =
    Provider<Future<BilRuntimePermissionState> Function(BilRuntimeCapability)>(
      (ref) => const BilRuntimePermissionPolicy().status,
    );

/// Local catalog rows only. This does not call the network-first search or
/// create a second food store; an unavailable local identity stays unresolved.
final intelligenceCoachMediaCatalogProvider =
    Provider<CoachMediaCatalogLookup Function(String)>((ref) {
      final repository = ref.watch(foodRepositoryProvider);
      return (ownerKey) => (input) async {
        final rows = await repository.getFoods();
        final query = FoodSearchNormalizer.normalize(input.name ?? '');
        final barcode = input.source == CoachMediaFoodSource.barcode
            ? BarcodeIdentity.parse(input.barcode ?? '')
            : null;
        final matched = rows.where((row) {
          if (barcode != null) {
            final candidate = BarcodeIdentity.parse(row.barcode ?? '');
            return barcode.isValid &&
                candidate.isValid &&
                barcode.digits == candidate.digits;
          }
          return query.isNotEmpty &&
              (FoodSearchNormalizer.normalize(row.name) == query ||
                  FoodSearchNormalizer.normalize(row.arabicName ?? '') ==
                      query);
        });
        return [
          for (final row in matched)
            if (CoachMediaCatalogEntry.fromLocalFood(row, ownerKey: ownerKey)
                case final CoachMediaCatalogEntry entry)
              entry,
        ];
      };
    });

final class _CoachMediaPageRequest {
  _CoachMediaPageRequest({
    required this.operationId,
    required this.owner,
    required this.attempt,
  });
  final String operationId;
  final _CoachMealOwnerHandle owner;
  final CoachMediaAttempt attempt;
  ProviderSubscription<CoachActionPermissionMode>? permissionSubscription;
  final capabilities = <BilRuntimeCapability>[];
  bool retainOwner = false;
  VoidCallback? releaseVoiceDraftListener;
  void dispose() {
    attempt.dispose();
    permissionSubscription?.close();
    releaseVoiceDraftListener?.call();
    releaseVoiceDraftListener = null;
    if (!retainOwner) owner.dispose();
  }
}

extension _IntelligenceVisionFlow on _IntelligenceCenterPageState {
  _CoachMediaPageRequest _newCoachMediaRequest() {
    final owner = _captureCoachMealOwner();
    final epoch = conversationPersistenceEpoch;
    final ownerKey = LocalDatabaseScope.keyForOwner(
      owner.database.localOwnerId,
    );
    final permission = ref.read(coachActionPermissionModeProvider);
    final foodScope = CoachFoodOwnerScope(
      captured: CoachFoodOwnerStamp(ownerKey: ownerKey, epoch: epoch),
      readCurrent: () {
        owner.scope.check(owner.database.localOwnerId);
        return CoachFoodOwnerStamp(
          ownerKey: ownerKey,
          epoch: conversationPersistenceEpoch,
        );
      },
    );
    final request = _CoachMediaPageRequest(
      operationId: 'media:${const Uuid().v4()}',
      owner: owner,
      attempt: CoachMediaAttempt(
        ownerScope: foodScope,
        conversationEpoch: epoch,
        requestGeneration: requestGeneration,
        readConversationEpoch: () => conversationPersistenceEpoch,
        readRequestGeneration: () => requestGeneration,
        isAuthorized: () =>
            mounted &&
            conversationReady &&
            !coachInBackground &&
            ref.read(coachActionPermissionModeProvider) == permission,
      ),
    );
    request.permissionSubscription = ref.listenManual(
      coachActionPermissionModeProvider,
      (_, next) {
        if (next != permission) request.attempt.cancel();
      },
    );
    return request;
  }

  Future<bool> _mediaRequestCurrent(_CoachMediaPageRequest request) async {
    if (!request.attempt.isCurrent) return false;
    for (final capability in request.capabilities) {
      try {
        final status = await ref.read(
          intelligenceCoachMediaRuntimePermissionProvider,
        )(capability);
        if (!request.attempt.isCurrent ||
            status != BilRuntimePermissionState.granted) {
          request.attempt.cancel();
          return false;
        }
      } on Object {
        request.attempt.cancel();
        return false;
      }
    }
    return request.attempt.isCurrent;
  }

  void _cancelCoachMediaRequests({bool notify = true}) {
    foodMediaRequest?.dispose();
    voiceMediaRequest?.dispose();
    voiceTranscriptBridge.cancel();
    foodMediaRequest = null;
    voiceMediaRequest = null;
    queuedMediaBarcode = null;
    if (notify && mounted) {
      _updateState(() {
        analyzingFoodImage = false;
        foodImageFlowOpening = false;
      });
    }
  }

  void _finishFoodMediaRequest(_CoachMediaPageRequest request) {
    request.dispose();
    if (!identical(foodMediaRequest, request)) return;
    foodMediaRequest = null;
    if (!mounted) return;
    _updateState(() {
      analyzingFoodImage = false;
      foodImageFlowOpening = false;
    });
    final next = queuedMediaBarcode;
    queuedMediaBarcode = null;
    if (next != null) unawaited(_reviewBarcodeInChat(next));
  }

  void _showMediaIssue(CoachMediaFoodIssue issue) {
    if (!mounted) return;
    final copy = CoachMediaBridgeCopy(arabic: arabic);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${copy.issue(issue)} ${copy.noFoodLogged}')),
    );
  }

  CoachMediaFoodBridge _foodMediaBridge(_CoachMediaPageRequest request) =>
      CoachMediaFoodBridge(
        lookupLocal: ref.read(intelligenceCoachMediaCatalogProvider)(
          request.attempt.ownerScope.captured.ownerKey,
        ),
      );

  Future<CoachMediaFoodReady?> _matchMediaFood(
    _CoachMediaPageRequest request,
    CoachMediaFoodBridge bridge,
    CoachMediaFoodInput input,
  ) async {
    final found = await bridge.lookup(input: input, attempt: request.attempt);
    if (!await _mediaRequestCurrent(request) || !mounted) return null;
    if (found is! CoachMediaFoodMatches) {
      _showMediaIssue((found as CoachMediaFoodUnresolved).issue);
      return null;
    }
    // This existing picker deliberately starts with no selected food, even
    // for one result. A barcode alone must not choose the first product.
    final selected = await showTrustedVisionFoodMatchDialog(
      context,
      recognizedName: input.source == CoachMediaFoodSource.barcode
          ? '${tr('Barcode', 'الباركود')}: ${BarcodeIdentity.parse(input.barcode!).digits}'
          : input.name!,
      foods: found.candidates.map((entry) => entry.row).toList(),
    );
    if (!await _mediaRequestCurrent(request) || selected == null) return null;
    final entries = found.candidates
        .where((entry) => identical(entry.row, selected))
        .toList();
    if (entries.length != 1) {
      _showMediaIssue(CoachMediaFoodIssue.selectionRequired);
      return null;
    }
    var result = bridge.select(matches: found, selected: entries.single);
    if (result is CoachMediaFoodUnresolved &&
        const {
          CoachMediaFoodIssue.missingQuantity,
          CoachMediaFoodIssue.missingDensity,
          CoachMediaFoodIssue.missingUnitWeight,
          CoachMediaFoodIssue.unsupportedUnit,
        }.contains(result.issue)) {
      final grams = await _askMediaGrams(request, issue: result.issue);
      if (!await _mediaRequestCurrent(request) || grams == null) return null;
      result = bridge.select(
        matches: found,
        selected: entries.single,
        reviewedInput: input.withUserQuantity(grams, 'g'),
      );
    }
    if (result is CoachMediaFoodReady) return result;
    _showMediaIssue((result as CoachMediaFoodUnresolved).issue);
    return null;
  }

  Future<double?> _askMediaGrams(
    _CoachMediaPageRequest request, {
    required CoachMediaFoodIssue issue,
  }) async {
    if (!await _mediaRequestCurrent(request) || !mounted) return null;
    return showDialog<double>(
      context: context,
      builder: (_) => _CoachMediaGramsDialog(
        request: request,
        issue: issue,
        copy: CoachMediaBridgeCopy(arabic: arabic),
      ),
    );
  }

  Future<void> _reviewBarcodeInChat(String rawBarcode) async {
    if (!mounted || !conversationReady || sending) return;
    if (foodImageFlowOpening) {
      foodMediaRequest?.attempt.cancel();
      queuedMediaBarcode = rawBarcode;
      return;
    }
    final request = _newCoachMediaRequest();
    foodMediaRequest = request;
    _updateState(() => foodImageFlowOpening = true);
    if (listening || voiceCaptureStarting) {
      unawaited(_stopVoiceCapture(resetMode: true));
    }
    try {
      final bridge = _foodMediaBridge(request);
      final ready = await _matchMediaFood(
        request,
        bridge,
        CoachMediaFoodInput(
          source: CoachMediaFoodSource.barcode,
          requestId: request.operationId,
          barcode: rawBarcode,
        ),
      );
      if (ready == null || !await _mediaRequestCurrent(request)) return;
      final review = bridge.takeReview([ready]);
      if (review != null && await _mediaRequestCurrent(request)) {
        await _handoffMediaFoodReview(request, review);
      }
    } on Object {
      if (request.attempt.isCurrent) {
        _showMediaIssue(CoachMediaFoodIssue.unavailable);
      }
    } finally {
      _finishFoodMediaRequest(request);
    }
  }

  Future<void> _analyzeFoodImageInChat() async {
    if (!mounted || !conversationReady || foodImageFlowOpening || sending) {
      return;
    }
    final request = _newCoachMediaRequest();
    foodMediaRequest = request;
    _updateState(() => foodImageFlowOpening = true);
    if (listening || voiceCaptureStarting) {
      unawaited(_stopVoiceCapture(resetMode: true));
    }
    try {
      final copy = MealVisionUiCopy.ofLocale(Localizations.localeOf(context));
      final consent = await ref.read(
        intelligenceCoachMealVisionConsentProvider,
      )(context);
      if (!consent || !await _mediaRequestCurrent(request) || !mounted) return;
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                key: const Key('ai-coach-image-source-camera'),
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(copy.text('take')),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                key: const Key('ai-coach-image-source-gallery'),
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(copy.text('choose')),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
              ListTile(
                key: const Key('ai-coach-image-source-cancel'),
                leading: const Icon(Icons.close),
                title: Text(copy.text('cancel')),
                onTap: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        ),
      );
      if (source == null || !await _mediaRequestCurrent(request) || !mounted) {
        return;
      }
      final XFile? image;
      if (source == ImageSource.gallery) {
        image = await ref
            .read(intelligenceCoachImagePickerProvider)
            .pickImage(
              purpose: BilImagePickerPurpose.coachFoodPhoto,
              source: ImageSource.gallery,
              maxWidth: 2048,
              maxHeight: 2048,
              imageQuality: 88,
              requestFullMetadata: false,
            );
      } else {
        if (!await _ensureCoachRuntimePermission(
              BilRuntimeCapability.camera,
              isCurrent: () => request.attempt.isCurrent,
            ) ||
            !await _mediaRequestCurrent(request)) {
          return;
        }
        request.capabilities.add(BilRuntimeCapability.camera);
        if (!await _mediaRequestCurrent(request) || !mounted) return;
        image = await Navigator.of(context).push<XFile>(
          MaterialPageRoute<XFile>(
            builder: (_) => BilCameraCapturePage(
              title: tr('Food photo', 'صورة الطعام'),
              captureLabel: tr('Capture', 'التقاط'),
            ),
          ),
        );
      }
      if (image == null || !await _mediaRequestCurrent(request) || !mounted) {
        return;
      }
      _updateState(() => analyzingFoodImage = true);
      final analysis = await ref
          .read(intelligenceCoachImageAnalysisProvider)(
            BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
          )
          .analyze(image);
      if (!await _mediaRequestCurrent(request) || !mounted) return;
      _updateState(() => analyzingFoodImage = false);
      final selections = await showMealImageReviewDialog(
        context,
        analysis: analysis,
      );
      if (!await _mediaRequestCurrent(request) ||
          selections == null ||
          selections.isEmpty) {
        return;
      }
      final bridge = _foodMediaBridge(request);
      final ready = <CoachMediaFoodReady>[];
      for (final selection in selections) {
        final candidate = selection.candidate;
        final guessed =
            candidate.amount == selection.amount &&
            (candidate.unit ?? '').trim().toLowerCase() ==
                selection.unit.trim().toLowerCase();
        final unit =
            const {
              'piece',
              'pieces',
              'item',
              'items',
            }.contains(selection.unit.trim().toLowerCase())
            ? 'item'
            : selection.unit;
        final result = await _matchMediaFood(
          request,
          bridge,
          CoachMediaFoodInput(
            source: CoachMediaFoodSource.photo,
            requestId: request.operationId,
            name: candidate.name,
            amount: selection.amount,
            unit: unit,
            quantityKind: guessed
                ? CoachFoodQuantityKind.estimated
                : CoachFoodQuantityKind.userDeclared,
            recognitionConfidence: candidate.confidence,
          ),
        );
        if (result == null || !await _mediaRequestCurrent(request)) return;
        ready.add(result);
      }
      final review = bridge.takeReview(ready);
      if (review != null && await _mediaRequestCurrent(request)) {
        await _handoffMediaFoodReview(request, review);
      }
    } on MealImageAnalysisException catch (error) {
      if (!mounted || !request.attempt.isCurrent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message(
              arabic: arabic,
              languageCode: BilLocalePolicy.canonicalTag(
                Localizations.localeOf(context),
              ),
            ),
          ),
        ),
      );
    } on Object {
      if (!mounted || !request.attempt.isCurrent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Food image analysis failed. Nothing was logged.',
              'فشل تحليل صورة الطعام. لم يُسجّل شيء.',
            ),
          ),
        ),
      );
    } finally {
      _finishFoodMediaRequest(request);
    }
  }
}

/// The controller lives with the route's widget, including its exit animation.
/// A popped dialog's Future can finish before its TextField is unmounted.
class _CoachMediaGramsDialog extends StatefulWidget {
  const _CoachMediaGramsDialog({
    required this.request,
    required this.issue,
    required this.copy,
  });
  final _CoachMediaPageRequest request;
  final CoachMediaFoodIssue issue;
  final CoachMediaBridgeCopy copy;

  @override
  State<_CoachMediaGramsDialog> createState() => _CoachMediaGramsDialogState();
}

class _CoachMediaGramsDialogState extends State<_CoachMediaGramsDialog> {
  final controller = TextEditingController();
  bool invalid = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void confirm() {
    if (!widget.request.attempt.isCurrent) {
      Navigator.pop(context);
      return;
    }
    final text = controller.text.trim().replaceAll('٫', '.');
    final ascii = String.fromCharCodes(
      text.runes.map(
        (r) => r >= 0x660 && r <= 0x669
            ? r - 0x660 + 48
            : r >= 0x6f0 && r <= 0x6f9
            ? r - 0x6f0 + 48
            : r,
      ),
    );
    final grams = double.tryParse(ascii);
    if (grams == null || !grams.isFinite || grams < .001 || grams > 100000) {
      setState(() => invalid = true);
      return;
    }
    Navigator.pop(context, grams);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.copy.quantityTitle),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.copy.issue(widget.issue)),
        const SizedBox(height: 12),
        TextField(
          key: const Key('bil02-media-grams'),
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: widget.copy.quantityLabel,
            errorText: invalid
                ? widget.copy.issue(CoachMediaFoodIssue.missingQuantity)
                : null,
          ),
          onSubmitted: (_) => confirm(),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(intelligenceText(context, 'Cancel', 'إلغاء')),
      ),
      FilledButton(
        key: const Key('bil02-media-grams-continue'),
        onPressed: confirm,
        child: Text(intelligenceText(context, 'Continue', 'متابعة')),
      ),
    ],
  );
}
