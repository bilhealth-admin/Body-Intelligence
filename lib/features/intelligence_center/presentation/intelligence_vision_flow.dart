part of 'intelligence_center_page.dart';

extension _IntelligenceVisionFlow on _IntelligenceCenterPageState {
  Future<void> _analyzeFoodImageInChat() async {
    if (analyzingFoodImage || sending) return;
    if (!await _ensureCoachRuntimePermission(BilRuntimeCapability.camera) ||
        !mounted) {
      return;
    }
    _updateState(() {
      analyzingFoodImage = true;
      introVisible = false;
    });
    try {
      // Keep the camera in the app. Launching ImagePicker.camera hands the
      // user to the system camera and backgrounds BIL, which is shown as the
      // privacy shield in the iOS task switcher.
      final image = await Navigator.of(context).push<XFile>(
        MaterialPageRoute<XFile>(
          builder: (_) => BilCameraCapturePage(
            title: tr('Food photo', 'صورة الطعام'),
            captureLabel: tr('Capture', 'التقاط'),
          ),
        ),
      );
      if (image == null || !mounted) return;
      final analysis = await MealImageAnalysisService(
        requestedLocale: BilLocalePolicy.canonicalTag(
          Localizations.localeOf(context),
        ),
      ).analyze(image);
      if (!mounted) return;
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
                  return '${item.candidate.name}: ${item.amount} ${item.unit} ($confidence%)';
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
      if (mounted) _updateState(() => analyzingFoodImage = false);
    }
  }
}
