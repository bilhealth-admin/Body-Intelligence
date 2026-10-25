part of 'intelligence_center_page.dart';

extension _IntelligenceQueryFlow on _IntelligenceCenterPageState {
  Future<bool> _readVerifiedWeightHistoryInChat(
    String questionText,
    String locale,
    int generation, {
    required bool autoSpeakReply,
  }) async {
    // All supported locales still use the general Coach flow. This
    // deterministic in-chat readout is limited to reviewed Arabic/English copy.
    if (!locale.startsWith('ar') && !locale.startsWith('en')) return false;
    if (!isCoachWeightHistoryReadRequest(questionText)) return false;

    final ownerAtStart = conversationPreferences.localOwnerId;
    final epoch = conversationPersistenceEpoch;
    CoachContextSnapshot? snapshot;
    try {
      snapshot = await ref
          .read(coachContextSnapshotProvider.future)
          .timeout(const Duration(seconds: 8));
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
        snapshot == null ||
            snapshot.weightReadStatus != CoachWeightReadStatus.verified
        ? intelligenceTextFor(
            locale,
            'Weight history could not be verified at this time. This does not mean you have no weigh-ins; please retry the read.',
            'تعذّر التحقق من سجل أوزانك الآن؛ هذا لا يعني عدم وجود قياسات. يرجى إعادة المحاولة.',
          )
        : CoachWeightHistoryReadout.build(
            snapshot: snapshot,
            question: questionText,
            languageTag: locale,
            now: ref.read(intelligenceConversationClockProvider)(),
          ).message;
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
    _scrollToLatest();
    unawaited(_saveConversation());
    if (autoSpeakReply) {
      await _speakCoachText(message.text, locale);
      await _resumeLiveCallIfNeeded(generation);
    }
    return true;
  }

  Future<void> ask({
    CoachInputChannel inputChannel = CoachInputChannel.text,
    String? detectedLanguageTag,
    String? textOverride,
    bool addUserMessage = true,
    bool autoSpeakReply = false,
    CoachCloudRequest? cloudRequest,
  }) async {
    if (!mounted) return;
    final submittedText = textOverride ?? question.text;
    if (inputChannel == CoachInputChannel.text) {
      // Capture the draft before focus changes and before the voice-media
      // handoff yields. This keeps a just-submitted question stable if the
      // platform IME updates its composing range while it closes.
      FocusManager.instance.primaryFocus?.unfocus();
    }
    if (inputChannel == CoachInputChannel.text &&
        textOverride == null &&
        await _submitPendingVoiceDraft()) {
      return;
    }
    if (!mounted) return;
    final rawText = submittedText.trim();
    final text = inputChannel == CoachInputChannel.voice
        ? normalizeCoachVoiceTranscript(rawText)
        : rawText;
    if (!conversationReady ||
        text.isEmpty ||
        sending ||
        consentPromptVisible ||
        foodImageFlowOpening) {
      return;
    }
    if (addUserMessage) _beginConversationForUserAction();
    final localeCode = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    final languageResolution = const CoachLanguageResolver().resolve(
      input: text,
      uiLocale: localeCode,
      detectedLanguageTag: detectedLanguageTag,
      previousClearLanguageTag: inputChannel == CoachInputChannel.text
          ? lastClearWritingLanguageTag
          : null,
    );
    final questionLocale = languageResolution.languageTag;
    final effectiveLanguageHint = languageResolution.detected
        ? languageResolution.languageTag
        : detectedLanguageTag;
    if (inputChannel == CoachInputChannel.text &&
        languageResolution.detected &&
        !languageResolution.usedPreviousInput &&
        detectedLanguageTag == null) {
      lastClearWritingLanguageTag = languageResolution.languageTag;
    }
    final speechPlan = _IntelligenceCenterPageState._speechPolicy.planFor(text);
    final generation = ++requestGeneration;
    final request = cloudRequest ?? _newCoachCloudRequest();
    replyDelayTimer?.cancel();
    _updateState(() {
      sending = true;
      replyPhase = _CoachReplyPhase.preparing;
      failedRequest = null;
      retryableErrorMessageIds.clear();
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
    _scrollToLatest(force: true);
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
    var localHealthHandled = false;
    try {
      if (_isCoachUndoRequest(text)) {
        await _undoLatestCoachAction();
        return;
      }
      const actionPresentation = CoachActionPresentationPolicy();
      if (actionPresentation.isContextualOpenFollowUp(text)) {
        final contextualNavigation = _latestSafeNavigationAction();
        if (contextualNavigation != null) {
          await _executeAction(contextualNavigation);
          return;
        }
      }
      final pendingAction = _latestPendingAction();
      final pendingDecision = coachPendingActionDecision(text);
      if (pendingAction != null &&
          pendingDecision != CoachPendingActionDecision.none) {
        if (pendingDecision == CoachPendingActionDecision.confirm) {
          await _executeAction(
            pendingAction,
            confirmationAlreadyProvided: true,
          );
        } else {
          await _retireDurableAction(pendingAction);
          _appendToolReceipt(
            tr(
              'The pending action was cancelled. Nothing was changed.',
              'تم إلغاء الإجراء المعلّق. لم يتغير شيء.',
            ),
          );
        }
        return;
      }
      if (await _readVerifiedWeightHistoryInChat(
        text,
        questionLocale,
        generation,
        autoSpeakReply: autoSpeakReply,
      )) {
        localHealthHandled = true;
        return;
      }
      if (await _answerSmartPlanIntent(text, questionLocale)) {
        localHealthHandled = true;
        return;
      }
      // A recognized health command (including an invalid one needing
      // clarification) must not be eaten by Food V2's generic "log"/"سجل"
      // prefix. Both hosts validate their own payload and ask for human review;
      // do not let the food host reinterpret exercise duration as a portion.
      localHealthHandled = await _tryCoachMealRead(
        text,
        locale: questionLocale,
      );
      if (localHealthHandled) return;
      localHealthHandled = await _answerLocalHealthIntent(
        text,
        locale: questionLocale,
      );
      if (localHealthHandled) return;
      // Food/Personal BIL owns its remaining intents and their frozen
      // nutrition evidence before any catalog/model fallback.
      if (await _tryHandleCoachFoodTurn(
        text: text,
        localeTag: questionLocale,
      )) {
        return;
      }
      final immediateEngine = const IntelligenceCenterEngine();
      final voiceGreeting =
          inputChannel == CoachInputChannel.voice &&
          immediateEngine.isGreetingQuestion(text);
      final catalogAnswer = voiceGreeting
          ? null
          : await catalogGrounding.answer(
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
        _updateState(() {
          messages.add(message);
          animatedResponseIds.add(message.id);
        });
        _scrollToLatest();
        unawaited(_saveConversation());
        if (autoSpeakReply) {
          await _speakCoachText(message.text, questionLocale);
          await _resumeLiveCallIfNeeded(generation);
        }
        return;
      }
      late final IntelligenceCenterReply reply;
      if (immediateEngine.canAnswerWithoutPersonalContext(text)) {
        final fastEngine =
            immediateEngine.isGreetingQuestion(text) &&
                !voiceGreeting &&
                !isTransliteratedArabicGreeting(text.trim().toLowerCase())
            ? IntelligenceCenterEngine(
                localApi: ModelBackedLocalCoachApi(
                  gateway: bindCoachCloudRequest(
                    ref.read(intelligenceCenterModelGatewayProvider),
                    request,
                  ),
                  context: CoachContextSnapshot.empty(),
                ),
              )
            : immediateEngine;
        final conversation = messages
            // Local render facts do not silently extend cloud/history context.
            .where((message) => message.presentationOwnerKey == null)
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
              detectedLanguageTag: effectiveLanguageHint,
              inputChannel: inputChannel,
              conversation: conversation,
            )
            .timeout(const Duration(seconds: 30));
      } else {
        // Both snapshots are independent. Starting both reads before awaiting
        // either removes a full local-database pass from perceived latency.
        final healthContextFuture = (() async {
          try {
            return await ref
                .read(intelligenceHealthContextProvider.future)
                .timeout(const Duration(seconds: 8));
          } on Object {
            return null;
          }
        })();
        final coachContextFuture = (() async {
          try {
            return await ref
                .read(coachContextSnapshotProvider.future)
                .timeout(const Duration(seconds: 8));
          } on Object {
            return CoachContextSnapshot.empty();
          }
        })();
        final healthContext = await healthContextFuture;
        final coachContext = await coachContextFuture;
        if (!mounted || generation != requestGeneration) return;
        if (isCoachWeightHistoryReadRequest(text) &&
            coachContext.weightReadStatus != CoachWeightReadStatus.verified) {
          // A repository timeout or missing analytics permission never proves
          // that the diary is empty. Do not bill for a speculative AI answer.
          localHealthHandled = true;
          final copy =
              coachContext.weightReadStatus == CoachWeightReadStatus.withheld
              ? intelligenceTextFor(
                  questionLocale,
                  'Weight history is not available to Coach under your current context-sharing settings. No records were changed.',
                  'سجل الوزن غير متاح للمدرب وفق إعدادات مشاركة السياق الحالية. لم يتغير أي سجل.',
                )
              : intelligenceTextFor(
                  questionLocale,
                  'I could not verify your weight history right now. This does not mean that you have no records. Please retry the read.',
                  'تعذّر التحقق من سجل أوزانك الآن، وهذا لا يعني عدم وجود سجلات. يرجى إعادة محاولة القراءة.',
                );
          final notice = IntelligenceMessage(
            id: 'coach-weight-read-unavailable-${DateTime.now().microsecondsSinceEpoch}',
            role: IntelligenceMessageRole.bil,
            kind: IntelligenceMessageKind.coach,
            text: copy,
            createdAt: DateTime.now(),
            evidence: const ['local-weight-context-read-status'],
            confidence: 1,
          );
          _updateState(() {
            messages.add(notice);
            animatedResponseIds.add(notice.id);
          });
          _scrollToLatest();
          unawaited(_saveConversation());
          return;
        }
        final activeEngine = IntelligenceCenterEngine(
          localApi: ModelBackedLocalCoachApi(
            gateway: bindCoachCloudRequest(
              ref.read(intelligenceCenterModelGatewayProvider),
              request,
            ),
            context: coachContext,
          ),
        );
        final conversation = messages
            .take(messages.length)
            .where((message) => message.presentationOwnerKey == null)
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
              detectedLanguageTag: effectiveLanguageHint,
              healthContext: healthContext,
              coachContext: coachContext,
              inputChannel: inputChannel,
              conversation: conversation,
            )
            .timeout(const Duration(seconds: 30));
      }
      if (!mounted || generation != requestGeneration) return;
      if (reply.serviceStatus == CoachServiceStatus.consentRequired) {
        // An authoritative server denial outranks a cached positive receipt.
        // Invalidate before the sheet so Allow performs a fresh write/readback.
        sharedRemoteAiConsentCoordinator().invalidate();
        // Consent is a pending local decision, not an in-flight AI request.
        // Clear all progress UI before presenting the single-flight sheet.
        _updateState(() {
          sending = false;
          replyPhase = _CoachReplyPhase.idle;
        });
        replyDelayTimer?.cancel();
        final choice = await _offerPersonalIntelligence();
        if (!mounted || generation != requestGeneration) return;
        if (choice == _RemoteAiConsentChoice.granted) {
          await ask(
            inputChannel: inputChannel,
            detectedLanguageTag: effectiveLanguageHint,
            textOverride: text,
            addUserMessage: false,
            autoSpeakReply: autoSpeakReply,
          );
        } else if (choice == _RemoteAiConsentChoice.declined) {
          final localMessage = IntelligenceMessage(
            id: 'coach-local-${DateTime.now().microsecondsSinceEpoch}',
            role: IntelligenceMessageRole.bil,
            kind: IntelligenceMessageKind.coach,
            text: intelligenceTextFor(
              questionLocale,
              'No problem. I’ll keep helping from verified data on this device.',
              'لا مشكلة. سأستمر بمساعدتك من البيانات الموثقة على هذا الجهاز.',
            ),
            createdAt: DateTime.now(),
            modality: autoSpeakReply
                ? IntelligenceMessageModality.voice
                : IntelligenceMessageModality.text,
          );
          _updateState(() {
            messages.add(localMessage);
            animatedResponseIds.add(localMessage.id);
          });
          if (autoSpeakReply) {
            await _speakCoachText(localMessage.text, questionLocale);
            await _resumeLiveCallIfNeeded(generation);
          }
        } else if (choice == _RemoteAiConsentChoice.failed) {
          final errorMessage = IntelligenceMessage(
            id: 'coach-consent-error-${DateTime.now().microsecondsSinceEpoch}',
            role: IntelligenceMessageRole.bil,
            kind: IntelligenceMessageKind.safety,
            text: intelligenceTextFor(
              questionLocale,
              'Remote AI consent could not be saved and verified. Nothing was sent; try again.',
              'تعذر حفظ موافقة الذكاء الاصطناعي البعيد والتحقق منها. لم يُرسل شيء؛ أعد المحاولة.',
            ),
            createdAt: DateTime.now(),
            confidence: 1,
          );
          _updateState(() {
            messages.add(errorMessage);
            animatedResponseIds.add(errorMessage.id);
            retryableErrorMessageIds.add(errorMessage.id);
            replyPhase = _CoachReplyPhase.failed;
            failedRequest = (
              text: text,
              detectedLanguageTag: effectiveLanguageHint,
              autoSpeak: autoSpeakReply,
              channel: inputChannel,
              cloudRequest: request,
            );
          });
        }
        return;
      }
      // A model suggestion cannot turn "Check nutrition", "Review my day"
      // or a weight-chart read into a Smart Plan transition.
      final allowPlanActions = coachAllowsSuggestedPlanAction(text);
      final availableActions = reply.actions
          .where(
            (action) =>
                allowPlanActions ||
                (action.type != IntelligenceActionType.smartPlan &&
                    action.type != IntelligenceActionType.openPlan),
          )
          .map(const CoachActionAdmission().admitProposal)
          .whereType<IntelligenceAction>()
          .toList(growable: false);
      final safeMessage = _presentationSafeMessage(reply.message);
      IntelligenceAction? directNavigationAction;
      if (reply.serviceStatus == CoachServiceStatus.ready) {
        for (final action in availableActions) {
          if (actionPresentation.isDirectNavigationRequest(text, action)) {
            directNavigationAction = action;
            break;
          }
        }
      }
      final persistedActions = <String, IntelligenceMessageAction>{
        for (final action in safeMessage.actionLinks)
          if (action.isTrusted)
            _coachActionExecutionKey(action.toAction()): action,
      };
      final transientActions = <IntelligenceAction>[];
      for (final action in availableActions) {
        final persisted = IntelligenceMessageAction.fromAction(action);
        if (persisted == null) {
          transientActions.add(action);
        } else {
          persistedActions[_coachActionExecutionKey(persisted.toAction())] =
              persisted;
          if (action.type == IntelligenceActionType.updateGoal) {
            // Present confirmation immediately, while retaining the bounded
            // proposal as a message chip if the sheet is dismissed.
            transientActions.add(action);
          }
        }
      }
      final allowAutomaticSpeech =
          autoSpeakReply &&
          coachServiceStatusAllowsAutomaticSpeech(reply.serviceStatus);
      final presented = safeMessage.copyWith(
        text: directNavigationAction == null
            ? safeMessage.text
            : AiCoachChatCopy.resolve(
                questionLocale,
                AiCoachChatCopy.navigationReady,
              ),
        modality: allowAutomaticSpeech
            ? IntelligenceMessageModality.voice
            : IntelligenceMessageModality.text,
        actionLinks: persistedActions.values.toList(growable: false),
      );
      final repeatedServiceNotice =
          !addUserMessage &&
          reply.serviceStatus != CoachServiceStatus.ready &&
          lastServiceStatus == reply.serviceStatus &&
          messages.reversed.any(
            (message) =>
                message.role == IntelligenceMessageRole.bil &&
                message.text == presented.text,
          );
      _updateState(() {
        if (!repeatedServiceNotice) {
          messages.add(presented);
          animatedResponseIds.add(presented.id);
        }
        lastServiceStatus = reply.serviceStatus;
        lastRuntime = reply.runtime;
        if (coachServiceStatusAllowsSameRequestRetry(reply.serviceStatus)) {
          replyPhase = _CoachReplyPhase.failed;
          failedRequest = (
            text: text,
            detectedLanguageTag: effectiveLanguageHint,
            autoSpeak: autoSpeakReply,
            channel: inputChannel,
            cloudRequest: request,
          );
          if (!repeatedServiceNotice) {
            retryableErrorMessageIds.add(presented.id);
          } else {
            // The transcript intentionally deduplicates identical service
            // notices. Attach retry to that notice, not a second failure row.
            final existing = messages.lastWhere(
              (message) =>
                  message.role == IntelligenceMessageRole.bil &&
                  message.text == presented.text,
            );
            retryableErrorMessageIds.add(existing.id);
          }
        }
        if (!repeatedServiceNotice) {
          messageRuntimes[presented.id] = reply.runtime;
        }
      });
      _scrollToLatest();
      unawaited(_saveConversation());
      if (repeatedServiceNotice) return;
      if (directNavigationAction != null) {
        await _executeAction(directNavigationAction);
        return;
      }
      final spokenReply = reply.spokenText?.trim().isNotEmpty == true
          ? reply.spokenText!.trim()
          : _compactSpokenCoachReply(presented.text);
      if (allowAutomaticSpeech) {
        final spokenLocale = const CoachLanguageResolver()
            .resolve(
              input: text,
              uiLocale: localeCode,
              detectedLanguageTag: effectiveLanguageHint,
            )
            .languageTag;
        await _speakCoachText(spokenReply, spokenLocale);
        await _resumeLiveCallIfNeeded(generation);
      }
      // Safe navigation/read actions remain as replayable chips. A validated,
      // expiring goal proposal also remains until it succeeds or is cancelled;
      // every other write and every destructive action stays transient.
      if (transientActions.isNotEmpty && mounted) {
        await showBilPearlBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (context) =>
              _ActionSheet(actions: transientActions, onAction: _executeAction),
        );
      }
    } on Object catch (error, stack) {
      if (kDebugMode) {
        // Never print the question, reply, token or provider error payload.
        debugPrint('AI Coach request failed (${error.runtimeType}).');
        debugPrintStack(stackTrace: stack);
      }
      if (!mounted || generation != requestGeneration) return;
      _updateState(() {
        replyPhase = _CoachReplyPhase.failed;
        failedRequest = (
          text: text,
          detectedLanguageTag: effectiveLanguageHint,
          autoSpeak: autoSpeakReply,
          channel: inputChannel,
          cloudRequest: request,
        );
        final errorMessage = IntelligenceMessage(
          id: 'coach-error-${DateTime.now().microsecondsSinceEpoch}',
          role: IntelligenceMessageRole.bil,
          kind: IntelligenceMessageKind.safety,
          text: tr(
            'AI Coach could not complete the reply. Your question remains in this chat; review any earlier actions before retrying.',
            'لم يتمكّن AI Coach من إكمال الرد. بقي سؤالك في المحادثة؛ راجع أي إجراءات سابقة قبل إعادة المحاولة.',
          ),
          createdAt: DateTime.now(),
          evidence: const ['local-coach-runtime'],
          confidence: 1,
          modality: autoSpeakReply
              ? IntelligenceMessageModality.voice
              : IntelligenceMessageModality.text,
        );
        messages.add(errorMessage);
        animatedResponseIds.add(errorMessage.id);
        retryableErrorMessageIds.add(errorMessage.id);
      });
      _scrollToLatest();
      unawaited(_saveConversation());
    } finally {
      if (mounted && !localHealthHandled) {
        // Refresh even when the local request generation was cancelled: the
        // server may still have settled a reservation before its reply was
        // discarded. autoDispose clears the snapshot when this page is gone.
        ref.invalidate(aiCoachCreditAccessProvider);
        ref
            .read(aiCoachUsageRefreshProvider.notifier)
            .requestAuthoritativeReload();
        ref.invalidate(aiVisionCreditStateProvider);
      }
      if (mounted && generation == requestGeneration) {
        // A cancelled, older response must not cancel the next turn's timer.
        replyDelayTimer?.cancel();
        if (question.text.trim().isEmpty && questionFocus.hasFocus) {
          questionFocus.unfocus();
        }
        // A successful settlement or a quota rejection may have changed the
        // reserved-aware total. Refresh once after the request completes so
        // zero returns the AI Coach glass immediately without polling/loops.
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
}

enum _RemoteAiConsentChoice { granted, declined, failed, alreadyOpen }
