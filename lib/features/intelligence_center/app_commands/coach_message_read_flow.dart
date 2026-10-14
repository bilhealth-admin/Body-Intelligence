part of '../presentation/intelligence_center_page.dart';

extension _CoachMessageReadFlow on _IntelligenceCenterPageState {
  Future<bool> _tryCoachMealRead(String text, {required String locale}) async {
    final intent = const CoachMealReadParser().parse(
      text,
      referenceLocal: ref.read(intelligenceConversationClockProvider)(),
    );
    if (intent.state == CoachMealReadIntentState.ignored) return false;
    if (intent.state == CoachMealReadIntentState.clarification) {
      _appendToolReceipt(
        intelligenceTextFor(
          locale,
          'Choose one meal and date, or two meals to compare. For example: “show lunch today” or “compare lunch today with dinner yesterday”. Nothing was changed.',
          'حدد وجبة وتاريخًا، أو وجبتين للمقارنة. مثال: «اعرض الغداء اليوم» أو «قارن الغداء اليوم مع العشاء أمس». لم يتغير شيء.',
        ),
        verifiedResult: false,
      );
      return true;
    }
    final owner = _captureRecoveredCoachNativeOwner();
    CoachHealthReadGuard? guard;
    try {
      guard = await CoachHealthReadGuard.capture(
        preferences: owner.repository.preferences,
        focus: CoachContextFocus.nutrition,
        checkOwner: () => owner.scope.check(owner.database.localOwnerId),
      );
      final presentation = await CoachMessageNutritionReader(
        owner.database,
        clock: ref.read(intelligenceConversationClockProvider),
      ).readMeals(intent.request!, checkAccess: guard.check);
      await guard.verify();
      guard.check();
      if (presentation == null) return true;
      if (!mounted) return true;
      final plain =
          CoachMessagePlainCopy(
            context,
            system:
                ref.read(measurementSystemProvider).value ??
                MeasurementSystem.metric,
          ).plain(
            fallback: '',
            presentation: presentation,
            expectedOwnerKey: LocalDatabaseScope.keyForOwner(
              owner.database.localOwnerId,
            ),
            ownerVisitIsCurrent: () => owner.scope.isCurrent,
          );
      guard.check();
      if (plain == null) return true;
      final id = 'tool-meal-read-${DateTime.now().microsecondsSinceEpoch}';
      _updateState(() {
        animatedResponseIds.add(id);
        messages.add(
          IntelligenceMessage(
            id: id,
            role: IntelligenceMessageRole.bil,
            kind: IntelligenceMessageKind.evidence,
            text: plain,
            createdAt: ref.read(intelligenceConversationClockProvider)(),
            presentation: presentation,
            evidence: const ['verified_local_meal_read'],
            confidence: 1,
          ),
        );
      });
      _scrollToLatest();
      unawaited(_saveConversation());
      return true;
    } on CoachHealthContextUnavailable {
      if (mounted && owner.scope.isCurrent) {
        _appendToolReceipt(
          tr(
            'Nutrition is disabled in Coach context settings.',
            'التغذية معطلة في إعدادات سياق المدرب.',
          ),
          verifiedResult: false,
        );
      }
      return true;
    } on FormatException {
      if (mounted && owner.scope.isCurrent) {
        _appendToolReceipt(
          tr(
            'The saved nutrition details could not be read. Nothing was changed.',
            'تعذرت قراءة تفاصيل التغذية المحفوظة. لم يتغير شيء.',
          ),
          verifiedResult: false,
        );
      }
      return true;
    } finally {
      final closing = guard?.close();
      owner.dispose();
      if (closing != null) unawaited(closing.catchError((Object _) {}));
    }
  }
}
