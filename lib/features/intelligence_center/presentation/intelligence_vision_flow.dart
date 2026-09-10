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

extension _IntelligenceVisionFlow on _IntelligenceCenterPageState {
  Future<void> _analyzeFoodImageInChat() async {
    if (!mounted || !conversationReady || foodImageFlowOpening || sending) {
      return;
    }
    _updateState(() => foodImageFlowOpening = true);
    if (listening || voiceCaptureStarting) {
      unawaited(_stopVoiceCapture(resetMode: true));
    }
    try {
      final copy = MealVisionUiCopy.ofLocale(Localizations.localeOf(context));
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
      if (source == null || !mounted) return;
      final XFile? image;
      if (source == ImageSource.gallery) {
        // The system picker grants access only to the chosen image. Do not
        // request camera access or the entire photo library for this action.
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
        if (!await _ensureCoachRuntimePermission(BilRuntimeCapability.camera) ||
            !mounted) {
          return;
        }
        // Keep the camera in the app. Launching ImagePicker.camera hands the
        // user to the system camera and backgrounds BIL, which is shown as the
        // privacy shield in the iOS task switcher.
        image = await Navigator.of(context).push<XFile>(
          MaterialPageRoute<XFile>(
            builder: (_) => BilCameraCapturePage(
              title: tr('Food photo', 'صورة الطعام'),
              captureLabel: tr('Capture', 'التقاط'),
            ),
          ),
        );
      }
      if (image == null || !mounted) return;
      _updateState(() => analyzingFoodImage = true);
      final analysis = await ref
          .read(intelligenceCoachImageAnalysisProvider)(
            BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
          )
          .analyze(image);
      if (!mounted) return;
      _updateState(() => analyzingFoodImage = false);
      final reviewed = await showMealImageReviewDialog(
        context,
        analysis: analysis,
      );
      if (reviewed == null || !mounted) return;
      final summary = reviewed.isEmpty
          ? tr(
              'No food was confirmed. Nothing was logged.',
              'لم يتم تأكيد أي طعام. لم يُسجّل شيء.',
            )
          : reviewed
                .map((item) {
                  final confidence = (item.candidate.confidence * 100).round();
                  final unit = mealImageUnitLabel(
                    item.unit,
                    BilLocalePolicy.canonicalTag(
                      Localizations.localeOf(context),
                    ),
                  );
                  return '${item.candidate.name}: ${item.amount} $unit ($confidence%)';
                })
                .join('\n');
      _beginConversationForUserAction();
      _updateState(
        () => messages.add(
          IntelligenceMessage(
            id: 'vision-${DateTime.now().microsecondsSinceEpoch}',
            role: IntelligenceMessageRole.bil,
            kind: IntelligenceMessageKind.coach,
            text:
                '$summary\n${tr('Review and confirm a verified BIL food match before logging.', 'راجع وأكد مطابقة طعام موثقة في BIL قبل التسجيل.')}',
            createdAt: DateTime.now(),
            confidence: 1,
            modality: IntelligenceMessageModality.image,
          ),
        ),
      );
      _scrollToLatest();
      unawaited(_saveConversation());
    } on MealImageAnalysisException catch (error) {
      if (!mounted) return;
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
      if (!mounted) return;
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
      if (mounted) {
        _updateState(() {
          analyzingFoodImage = false;
          foodImageFlowOpening = false;
        });
      }
    }
  }
}
