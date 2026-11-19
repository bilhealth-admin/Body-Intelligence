part of 'intelligence_center_page.dart';

extension _IntelligenceContextRecovery on _IntelligenceCenterPageState {
  // This only explains an already-proven local permission boundary. It never
  // changes categories, action mode, remote consent or provider permissions.
  void _offerCoachSettingsGuidance({
    CoachContextFocus? focus,
    bool actionPermission = false,
    bool appendReceipt = true,
  }) {
    if (!mounted || !_coachMessageVisitIsCurrent()) return;
    final ownerIsCurrent = _captureCoachSettingsOwnerGuard();
    final epoch = conversationPersistenceEpoch;
    final conversation = activeConversationId;
    bool current() =>
        mounted &&
        ownerIsCurrent() &&
        _coachMessageVisitIsCurrent() &&
        epoch == conversationPersistenceEpoch &&
        conversation == activeConversationId;
    if (!current() || !actionPermission && focus == null) return;
    final category = switch (focus) {
      CoachContextFocus.nutrition => tr(
        'Nutrition and meals',
        'التغذية والوجبات',
      ),
      CoachContextFocus.training => tr(
        'Training and activity',
        'التدريب والنشاط',
      ),
      CoachContextFocus.habits => tr(
        'Sleep, fasting and habits',
        'النوم والصيام والعادات',
      ),
      CoachContextFocus.analytics => tr('Progress analytics', 'تحليلات التقدم'),
      null => '',
    };
    final text = actionPermission
        ? tr(
            'Coach actions are set to Read only. Review permissions in Coach settings. Nothing was changed.',
            'إجراءات المدرب مضبوطة على «قراءة فقط». راجع الصلاحيات في إعدادات المدرب. لم يتغير شيء.',
          )
        : tr(
            'This request needs access to {category}. Review this category in Coach settings. Nothing was changed.',
            'يحتاج هذا الطلب إلى الوصول إلى «{category}». راجع هذه الفئة في إعدادات المدرب. لم يتغير شيء.',
          ).replaceAll('{category}', category);
    if (appendReceipt) _appendToolReceipt(text, verifiedResult: false);
    final media = MediaQuery.of(context);
    final guidanceHeight =
        ((media.size.height -
                    media.viewInsets.bottom -
                    media.padding.vertical) *
                .45)
            .clamp(80.0, 360.0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.fixed,
        content: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: guidanceHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    text,
                    key: const Key('coach-permission-guidance-body'),
                  ),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: SnackBarAction(
                  label: tr('Coach settings', 'إعدادات المدرب'),
                  onPressed: () {
                    if (current()) {
                      unawaited(
                        _openCoachRoute('/settings/ai-coach', push: true),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _readVerifiedWeightHistoryInChat(
    String questionText,
    String locale,
    int generation, {
    required bool autoSpeakReply,
  }) async {
    // All supported locales still use the general Coach flow. This
    // deterministic in-chat readout is limited to reviewed Arabic/English copy.
    if (!locale.startsWith('ar') && !locale.startsWith('en')) return false;
    final readQuestion = _resolvedWeightHistoryReadQuestion(questionText);
    if (!isCoachWeightHistoryReadRequest(readQuestion)) return false;

    final ownerAtStart = conversationPreferences.localOwnerId;
    final epoch = conversationPersistenceEpoch;
    CoachContextSnapshot? snapshot;
    try {
      snapshot = await readCoachContextSnapshot(
        ProviderScope.containerOf(context, listen: false),
      );
    } on Object {
      // A timeout is an unknown dataset, never a verified empty history.
    }
    if (!mounted ||
        generation != requestGeneration ||
        epoch != conversationPersistenceEpoch ||
        coachMessageVisitCancelled ||
        ownerAtStart != conversationPreferences.localOwnerId) {
      return true;
    }
    final text =
        snapshot != null &&
            snapshot.weightReadStatus == CoachWeightReadStatus.verified
        ? CoachWeightHistoryReadout.build(
            snapshot: snapshot,
            question: readQuestion,
            languageTag: locale,
            now: ref.read(intelligenceConversationClockProvider)(),
          ).message
        : CoachWeightHistoryReadout.statusMessage(
            status:
                snapshot?.weightReadStatus ?? CoachWeightReadStatus.unavailable,
            languageTag: locale,
          );
    final message = IntelligenceMessage(
      id: 'coach-verified-weight-${DateTime.now().microsecondsSinceEpoch}',
      role: IntelligenceMessageRole.bil,
      kind: IntelligenceMessageKind.coach,
      text: text,
      createdAt: DateTime.now(),
      evidence: const ['owner-scoped-local-weight-history'],
      confidence: 1,
      modality: autoSpeakReply
          ? IntelligenceMessageModality.voice
          : IntelligenceMessageModality.text,
    );
    _updateState(() {
      messages.add(message);
      animatedResponseIds.add(message.id);
    });
    if (snapshot?.weightReadStatus == CoachWeightReadStatus.withheld) {
      _offerCoachSettingsGuidance(
        focus: CoachContextFocus.analytics,
        appendReceipt: false,
      );
    }
    _scrollToLatest();
    unawaited(_saveConversation());
    if (autoSpeakReply) {
      await _speakCoachText(message.text, locale);
      await _resumeLiveCallIfNeeded(generation);
    }
    return true;
  }
}
