part of 'intelligence_center_page.dart';

extension _IntelligenceQueryGuardFlow on _IntelligenceCenterPageState {
  // Inherit only the immediately preceding weight-read topic, never a plan,
  // diary write, older chat, or another owner-scoped conversation.
  String _resolvedWeightHistoryReadQuestion(String text) {
    if (isCoachWeightHistoryReadRequest(text)) return text;
    final users = messages.reversed
        .where((message) => message.role == IntelligenceMessageRole.user)
        .take(2)
        .toList(growable: false);
    if (users.length != 2 || users.first.text != text) return text;
    final previous = users.last;
    final age = DateTime.now().difference(previous.createdAt);
    if (age.isNegative || age > const Duration(minutes: 5)) return text;
    return resolveCoachWeightHistoryFollowUp(
      text,
      previousUserRequest: previous.text,
    );
  }

  IntelligenceAction? _latestPendingAction() {
    for (final message in messages.reversed) {
      for (final action in message.actionLinks.reversed) {
        if (!action.isTrusted) continue;
        final candidate = action.toAction();
        final binding = const CoachActionAdmission().bind(
          candidate,
          requireOperationId: true,
        );
        if (binding?.descriptor?.requiresConfirmation == true ||
            binding?.action.requiresFreshConfirmation == true) {
          return binding!.action;
        }
      }
    }
    return null;
  }

  IntelligenceAction? _latestSafeNavigationAction() {
    const policy = CoachActionPresentationPolicy();
    for (final message in messages.reversed) {
      if (message.role != IntelligenceMessageRole.bil) continue;
      if (message.modality == IntelligenceMessageModality.system) continue;
      for (final action in message.actionLinks.reversed) {
        if (!action.isTrusted) continue;
        final candidate = action.toAction();
        if (policy.isNavigation(candidate)) return candidate;
      }
      // Pronouns such as "open it" may only bind to the immediately previous
      // Coach response. Never replay an older screen action by accident.
      return null;
    }
    return null;
  }

  void _cancelCurrentCoachRequest() {
    if (listening || voiceCaptureStarting) {
      unawaited(
        _stopVoiceCapture(resetMode: voiceMode != _CoachVoiceMode.liveCall),
      );
    }
    requestGeneration += 1;
    replyDelayTimer?.cancel();
    _updateState(() {
      sending = false;
      replyPhase = _CoachReplyPhase.idle;
      failedRequest = null;
    });
    if (voiceMode == _CoachVoiceMode.liveCall) {
      liveCallPaused = true;
    }
    unawaited(const BilTextToSpeech().stop());
  }

  Future<_RemoteAiConsentChoice> _offerPersonalIntelligence() {
    final inFlight = consentChoiceInFlight;
    if (inFlight != null) return inFlight;
    final operation = _runPersonalIntelligenceOffer();
    consentChoiceInFlight = operation;
    return operation.whenComplete(() {
      consentChoiceInFlight = null;
    });
  }

  Future<_RemoteAiConsentChoice> _runPersonalIntelligenceOffer() async {
    if (consentPromptVisible || !mounted) {
      return _RemoteAiConsentChoice.alreadyOpen;
    }
    consentPromptVisible = true;
    try {
      final client = Supabase.instance.client;
      final owner = client.auth.currentUser?.id;
      final database = ref.read(databaseProvider);
      final preferences = ref.read(preferencesRepositoryProvider);
      final generation = requestGeneration;
      final epoch = conversationPersistenceEpoch;
      final conversationId = activeConversationId;
      if (owner == null || database.localOwnerId != owner) {
        return _RemoteAiConsentChoice.failed;
      }
      return await CommunityOwnerOperation.run<_RemoteAiConsentChoice>(
        client: client,
        ownerId: owner,
        isCurrentOwner: () =>
            mounted &&
            identical(Supabase.instance.client, client) &&
            generation == requestGeneration &&
            epoch == conversationPersistenceEpoch &&
            conversationId == activeConversationId &&
            identical(ref.read(databaseProvider), database) &&
            identical(ref.read(preferencesRepositoryProvider), preferences) &&
            identical(conversationPreferences, preferences),
        action: (ownerVisit) async {
          final enabled = await showBilPremiumAiConsentSheet(
            context: context,
            title: tr(
              'Send selected personal data to Google Gemini?',
              'إرسال بيانات شخصية محددة إلى Google Gemini؟',
            ),
            intro: tr(
              'BIL uses Google Gemini, a third-party AI service operated by Google, only to generate the answer you request.',
              'يستخدم BIL خدمة Google Gemini، وهي خدمة ذكاء اصطناعي تابعة لجهة خارجية وتديرها Google، فقط لإنشاء الإجابة التي تطلبها.',
            ),
            points: [
              BilPremiumAiConsentPoint(
                icon: Icons.tune_rounded,
                title: tr(
                  'Only the context you choose',
                  'فقط السياق الذي تختاره',
                ),
                body: tr(
                  'Your question; selected weight, goals and measurements; meals, nutrition, water and preferences; activity and training; sleep and habits; plus up to 12 recent conversation turns.',
                  'سؤالك؛ وما تختاره من الوزن والأهداف والقياسات؛ والوجبات والتغذية والماء والتفضيلات؛ والنشاط والتدريب؛ والنوم والعادات؛ إضافة إلى ما يصل إلى آخر 12 رسالة.',
                ),
              ),
              BilPremiumAiConsentPoint(
                icon: Icons.mic_off_rounded,
                title: tr(
                  'Your platform handles speech recognition',
                  'يتولى جهازك أو نظامه التعرّف على الكلام',
                ),
                body: tr(
                  'Your device or platform speech service may process microphone audio under its own terms. When you submit a Coach request, BIL sends Gemini only recognized text, never raw microphone audio.',
                  'قد تعالج خدمة التعرّف على الكلام في جهازك أو منصتك صوت الميكروفون وفق شروطها. عند إرسال طلب إلى Coach، يرسل BIL إلى Gemini النص المتعرّف عليه فقط، ولا يرسل صوت الميكروفون الخام.',
                ),
              ),
              BilPremiumAiConsentPoint(
                icon: Icons.verified_user_outlined,
                title: tr('You stay in control', 'التحكم يبقى بيدك'),
                body: tr(
                  'You can decline and keep using local BIL features, or withdraw this consent later in AI Coach settings.',
                  'يمكنك الرفض ومتابعة استخدام ميزات BIL المحلية، أو سحب هذه الموافقة لاحقًا من إعدادات AI Coach.',
                ),
              ),
            ],
            allowLabel: tr('Allow & Continue', 'السماح والمتابعة'),
            declineLabel: tr("Don't Allow", 'عدم السماح'),
            allowKey: const Key('ai-coach-remote-consent-accept'),
            declineKey: const Key('ai-coach-remote-consent-decline'),
          );
          ownerVisit.check();
          if (enabled != true) return _RemoteAiConsentChoice.declined;
          final verified = await sharedRemoteAiConsentCoordinator(
            client,
          ).grantAndVerify();
          ownerVisit.check();
          return verified
              ? _RemoteAiConsentChoice.granted
              : _RemoteAiConsentChoice.failed;
        },
      );
    } on Object {
      return _RemoteAiConsentChoice.failed;
    } finally {
      consentPromptVisible = false;
    }
  }

  IntelligenceMessage _presentationSafeMessage(IntelligenceMessage message) {
    if (message.role == IntelligenceMessageRole.user) return message;
    final normalized = message.text.toLowerCase();
    const technicalMarkers = <String>[
      'local-coach-runtime',
      'ai context is not accepted',
      'decision memory evidence',
      'safety boundary did not approve',
      'bil did not expose an action',
      'accepted ai context',
      'source summary is required',
      'one best action output',
    ];
    if (!technicalMarkers.any(normalized.contains)) return message;
    return IntelligenceMessage(
      id: message.id,
      role: message.role,
      kind: IntelligenceMessageKind.safety,
      text: tr(
        'AI Coach could not complete this reply. Your data was not changed; try again.',
        'تعذر إكمال هذا الرد الآن. لم تتغير بياناتك؛ أعد المحاولة.',
      ),
      createdAt: message.createdAt,
      confidence: 1,
      modality: message.modality,
    );
  }
}
