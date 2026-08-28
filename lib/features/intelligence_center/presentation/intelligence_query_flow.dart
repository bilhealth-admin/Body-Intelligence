part of 'intelligence_center_page.dart';

extension _IntelligenceQueryFlow on _IntelligenceCenterPageState {
  Future<void> ask({
    CoachInputChannel inputChannel = CoachInputChannel.text,
    String? detectedLanguageTag,
    String? textOverride,
    bool addUserMessage = true,
    bool autoSpeakReply = false,
  }) async {
    final text = (textOverride ?? question.text).trim();
    if (text.isEmpty || sending) return;
    final localeCode = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    final questionLocale = const CoachLanguageResolver()
        .resolve(
          input: text,
          uiLocale: localeCode,
          detectedLanguageTag: detectedLanguageTag,
        )
        .languageTag;
    final speechPlan = _IntelligenceCenterPageState._speechPolicy.planFor(text);
    final generation = ++requestGeneration;
    replyDelayTimer?.cancel();
    _updateState(() {
      sending = true;
      replyPhase = _CoachReplyPhase.preparing;
      failedRequest = null;
      introVisible = false;
      if (addUserMessage) {
        messages.add(
          IntelligenceMessage(
            id: 'user-${DateTime.now().microsecondsSinceEpoch}',
            role: IntelligenceMessageRole.user,
            kind: IntelligenceMessageKind.freeQuestion,
            text: text,
            createdAt: DateTime.now(),
            modality: inputChannel == CoachInputChannel.voice
                ? IntelligenceMessageModality.voice
                : IntelligenceMessageModality.text,
          ),
        );
      }
      if (inputChannel == CoachInputChannel.text) question.clear();
    });
    // Fast local replies stay visually quiet. Only work that crosses the
    // one-second perception threshold gets the compact cancelable indicator.
    replyDelayTimer = Timer(const Duration(milliseconds: 1100), () {
      if (!mounted || generation != requestGeneration || !sending) return;
      _updateState(() => replyPhase = _CoachReplyPhase.searching);
    });
    _scrollToLatest();
    unawaited(_saveConversation());
    if (autoSpeakReply && speechPlan != CoachSpeechPlan.directAnswer) {
      final acknowledgement = switch (speechPlan) {
        CoachSpeechPlan.dataLookup => intelligenceTextFor(
          questionLocale,
          'Please wait while I check your recorded data. I’ll write the answer on screen.',
          'من فضلك انتظر بينما أراجع بياناتك المسجلة. سأكتب الإجابة على الشاشة.',
        ),
        CoachSpeechPlan.goalAnalysis => intelligenceTextFor(
          questionLocale,
          'All right. I’m checking how exercise and diet could affect the time to your goal. I’ll write the recommendations on screen.',
          'تمام. أراجع كيف يمكن للرياضة والدايت أن يؤثرا في وقت وصولك لهدفك، وسأكتب التوصيات على الشاشة.',
        ),
        CoachSpeechPlan.extendedAnswer => intelligenceTextFor(
          questionLocale,
          'All right. I’m checking your data now. I’ll write the answer and recommendations on screen.',
          'تمام. أراجع بياناتك الآن، وسأكتب الإجابة والتوصيات على الشاشة.',
        ),
        CoachSpeechPlan.directAnswer => '',
      };
      unawaited(_speakCoachText(acknowledgement, questionLocale));
    }
    try {
      final catalogAnswer = await catalogGrounding.answer(
        question: text,
        locale: questionLocale,
      );
      if (!mounted || generation != requestGeneration) return;
      if (catalogAnswer != null) {
        final message = IntelligenceMessage(
          id: 'coach-catalog-${DateTime.now().microsecondsSinceEpoch}',
          role: IntelligenceMessageRole.bil,
          kind: IntelligenceMessageKind.coach,
          text: catalogAnswer.text,
          createdAt: DateTime.now(),
          evidence: catalogAnswer.evidence,
          links: catalogAnswer.links,
          confidence: 1,
          modality: autoSpeakReply
              ? IntelligenceMessageModality.voice
              : IntelligenceMessageModality.text,
        );
        _updateState(() => messages.add(message));
        _scrollToLatest();
        unawaited(_saveConversation());
        if (autoSpeakReply) {
          await _speakCoachText(message.text, questionLocale);
          await _resumeLiveCallIfNeeded(generation);
        }
        return;
      }
      final immediateEngine = const IntelligenceCenterEngine();
      late final IntelligenceCenterReply reply;
      if (immediateEngine.canAnswerWithoutPersonalContext(text)) {
        final fastEngine = immediateEngine.isGreetingQuestion(text)
            ? IntelligenceCenterEngine(
                localApi: ModelBackedLocalCoachApi(
                  gateway: createLocalModelGateway(),
                  context: CoachContextSnapshot.empty(),
                ),
              )
            : immediateEngine;
        final conversation = messages
            .map(
              (message) => CoachConversationTurn(
                role: message.role == IntelligenceMessageRole.user
                    ? 'user'
                    : 'assistant',
                content: message.text,
              ),
            )
            .toList(growable: false);
        reply = await fastEngine
            .answer(
              question: text,
              arabic: arabic,
              localeCode: localeCode,
              detectedLanguageTag: detectedLanguageTag,
              inputChannel: inputChannel,
              conversation: conversation,
            )
            .timeout(const Duration(seconds: 50));
      } else {
        // Both snapshots are independent. Starting both reads before awaiting
        // either removes a full local-database pass from perceived latency.
        final healthContextFuture = (() async {
          try {
            return await ref
                .read(intelligenceHealthContextProvider.future)
                .timeout(const Duration(seconds: 12));
          } on Object {
            return null;
          }
        })();
        final coachContextFuture = (() async {
          try {
            return await ref
                .read(coachContextSnapshotProvider.future)
                .timeout(const Duration(seconds: 12));
          } on Object {
            return CoachContextSnapshot.empty();
          }
        })();
        final healthContext = await healthContextFuture;
        final coachContext = await coachContextFuture;
        if (!mounted || generation != requestGeneration) return;
        final activeEngine = IntelligenceCenterEngine(
          localApi: ModelBackedLocalCoachApi(
            gateway: createLocalModelGateway(),
            context: coachContext,
          ),
        );
        final conversation = messages
            .take(messages.length)
            .map(
              (message) => CoachConversationTurn(
                role: message.role == IntelligenceMessageRole.user
                    ? 'user'
                    : 'assistant',
                content: message.text,
              ),
            )
            .toList(growable: false);
        reply = await activeEngine
            .answer(
              question: text,
              arabic: arabic,
              localeCode: localeCode,
              detectedLanguageTag: detectedLanguageTag,
              healthContext: healthContext,
              coachContext: coachContext,
              inputChannel: inputChannel,
              conversation: conversation,
            )
            .timeout(const Duration(seconds: 50));
      }
      if (!mounted || generation != requestGeneration) return;
      if (reply.serviceStatus == CoachServiceStatus.consentRequired) {
        final enabled = await _offerPersonalIntelligence();
        if (!mounted) return;
        if (enabled) {
          _updateState(() => sending = false);
          await ask(
            inputChannel: inputChannel,
            detectedLanguageTag: detectedLanguageTag,
            textOverride: text,
            addUserMessage: false,
            autoSpeakReply: autoSpeakReply,
          );
        } else {
          final localMessage = IntelligenceMessage(
            id: 'coach-local-${DateTime.now().microsecondsSinceEpoch}',
            role: IntelligenceMessageRole.bil,
            kind: IntelligenceMessageKind.coach,
            text: tr(
              'No problem. I’ll keep helping from verified data on this device.',
              'لا مشكلة. سأستمر بمساعدتك من البيانات الموثقة على هذا الجهاز.',
            ),
            createdAt: DateTime.now(),
            modality: autoSpeakReply
                ? IntelligenceMessageModality.voice
                : IntelligenceMessageModality.text,
          );
          _updateState(() => messages.add(localMessage));
          if (autoSpeakReply) {
            await _speakCoachText(localMessage.text, questionLocale);
            await _resumeLiveCallIfNeeded(generation);
          }
        }
        return;
      }
      final presented = _presentationSafeMessage(reply.message).copyWith(
        modality: autoSpeakReply
            ? IntelligenceMessageModality.voice
            : IntelligenceMessageModality.text,
      );
      final repeatedServiceNotice =
          reply.serviceStatus != CoachServiceStatus.ready &&
          lastServiceStatus == reply.serviceStatus &&
          messages.reversed.any(
            (message) =>
                message.role == IntelligenceMessageRole.bil &&
                message.text == presented.text,
          );
      _updateState(() {
        if (!repeatedServiceNotice) messages.add(presented);
        lastServiceStatus = reply.serviceStatus;
        lastRuntime = reply.runtime;
        if (reply.serviceStatus == CoachServiceStatus.temporarilyUnavailable) {
          replyPhase = _CoachReplyPhase.failed;
          failedRequest = (
            text: text,
            detectedLanguageTag: detectedLanguageTag,
            autoSpeak: autoSpeakReply,
            channel: inputChannel,
          );
        }
        if (!repeatedServiceNotice) {
          messageRuntimes[presented.id] = reply.runtime;
        }
      });
      _scrollToLatest();
      unawaited(_saveConversation());
      if (repeatedServiceNotice) return;
      final spokenReply = reply.spokenText?.trim().isNotEmpty == true
          ? reply.spokenText!.trim()
          : _compactSpokenCoachReply(presented.text);
      if (autoSpeakReply) {
        final spokenLocale = const CoachLanguageResolver()
            .resolve(
              input: text,
              uiLocale: localeCode,
              detectedLanguageTag: detectedLanguageTag,
            )
            .languageTag;
        await _speakCoachText(spokenReply, spokenLocale);
        await _resumeLiveCallIfNeeded(generation);
      }
      if (reply.actions.isNotEmpty && mounted) {
        await showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (context) =>
              _ActionSheet(actions: reply.actions, onAction: _executeAction),
        );
      }
    } on Object {
      if (!mounted || generation != requestGeneration) return;
      _updateState(() {
        replyPhase = _CoachReplyPhase.failed;
        failedRequest = (
          text: text,
          detectedLanguageTag: detectedLanguageTag,
          autoSpeak: autoSpeakReply,
          channel: inputChannel,
        );
        messages.add(
          IntelligenceMessage(
            id: 'coach-error-${DateTime.now().microsecondsSinceEpoch}',
            role: IntelligenceMessageRole.bil,
            kind: IntelligenceMessageKind.safety,
            text: tr(
              'AI Coach could not prepare your context. Your data was not changed; try again.',
              'تعذر تجهيز سياق AI Coach الآن. لم تتغير بياناتك؛ أعد المحاولة.',
            ),
            createdAt: DateTime.now(),
            evidence: const ['local-coach-runtime'],
            confidence: 1,
            modality: autoSpeakReply
                ? IntelligenceMessageModality.voice
                : IntelligenceMessageModality.text,
          ),
        );
      });
      _scrollToLatest();
      unawaited(_saveConversation());
    } finally {
      replyDelayTimer?.cancel();
      if (mounted && generation == requestGeneration) {
        _updateState(() {
          sending = false;
          if (replyPhase != _CoachReplyPhase.failed) {
            replyPhase = _CoachReplyPhase.idle;
          }
        });
        if (autoSpeakReply) {
          await _resumeLiveCallIfNeeded(generation);
        }
      }
    }
  }

  void _cancelCurrentCoachRequest() {
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

  Future<void> _retryFailedCoachRequest() async {
    final failed = failedRequest;
    if (failed == null || sending) return;
    _updateState(() {
      replyPhase = _CoachReplyPhase.idle;
      failedRequest = null;
    });
    await ask(
      inputChannel: failed.channel,
      detectedLanguageTag: failed.detectedLanguageTag,
      textOverride: failed.text,
      addUserMessage: false,
      autoSpeakReply: failed.autoSpeak,
    );
  }

  Future<bool> _offerPersonalIntelligence() async {
    if (consentPromptVisible || !mounted) return false;
    consentPromptVisible = true;
    try {
      final enabled = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) {
          final scheme = Theme.of(sheetContext).colorScheme;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.auto_awesome, color: scheme.primary),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    tr(
                      'Let BIL understand your full context?',
                      'هل تسمح لـBIL بفهم سياقك الكامل؟',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    tr(
                      'Only the bounded records needed for your question and the recognized text are sent to BIL’s Gemini service. Microphone audio stays with your device’s speech recognizer.',
                      'تُرسل فقط السجلات المحدودة اللازمة لسؤالك والنص الذي تعرّف عليه الجهاز إلى خدمة Gemini التابعة لـBIL. يبقى صوت الميكروفون داخل خدمة التعرّف على الكلام في جهازك.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: Text(
                        tr(
                          'Enable personal BIL and continue',
                          'فعّل BIL المخصص وتابع',
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(sheetContext, false),
                    child: Text(tr('Not now', 'ليس الآن')),
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (enabled != true) return false;
      await Supabase.instance.client.rpc(
        'bil_record_consent',
        params: const <String, Object?>{
          'p_purpose': 'remote_ai',
          'p_policy_version': '2',
          'p_granted': true,
        },
      );
      return true;
    } on Object {
      if (mounted) {
        _showActionCompleted(
          tr(
            'Personal BIL could not be enabled right now.',
            'تعذر تفعيل BIL المخصص الآن.',
          ),
        );
      }
      return false;
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
