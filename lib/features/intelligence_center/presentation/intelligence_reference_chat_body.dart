part of 'intelligence_center_page.dart';

const _coachComposerActionInk = Color(0xFF14243A);

extension _IntelligenceReferenceChatBody on _IntelligenceCenterPageState {
  Widget _buildReferenceChat(BuildContext context) {
    if (entryWelcomeVisible) {
      return const _AiCoachEntryWelcome();
    }
    final scheme = Theme.of(context).colorScheme;
    final conversationInteractive =
        conversationReady && !conversationRestarting;
    final coachContext = ref.watch(coachHealthBriefProvider);
    // Keep the opening transcript stable for same-dependency data refreshes.
    // Dependency reloads (including owner or context-permission changes) use
    // the loading fallback instead of retaining the previous snapshot.
    final snapshot =
        coachContext.asData?.value ??
        (coachContext.isRefreshing ? coachContext.value : null);
    final dailyBrief = snapshot == null
        ? null
        : const CoachDailyBriefEngine().build(
            context: snapshot,
            now: DateTime.now(),
            locale: BilLocalePolicy.canonicalTag(
              Localizations.localeOf(context),
            ),
          );
    final visibleMessages = messages.isEmpty && sessionWelcomeMessage != null
        ? <IntelligenceMessage>[sessionWelcomeMessage!]
        : messages.toList(growable: false);
    final showLiveVoiceDraft =
        listening && pendingVoiceTranscript.trim().isNotEmpty;
    // A sent turn is already visible at the newest end of the conversation.
    // Failures are rendered once as a transcript message with its Retry
    // action; retain the progress row only as a defensive fallback if a
    // failure has no persisted message yet.
    final showReplyFailure =
        replyPhase == _CoachReplyPhase.failed &&
        retryableErrorMessageIds.isEmpty;
    final showReplyThinking = sending;
    final showIntroBrief = introVisible && dailyBrief != null;
    final coachCanvas = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : BilReferenceBottomBar(
              selected: 1,
              dark: Theme.of(context).brightness == Brightness.dark,
              onSelected: (index) => unawaited(_navigateReference(index)),
            ),
      backgroundColor: coachCanvas,
      body: BilPearlBackdrop(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.zero,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 920),
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(),
                child: Column(
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: SizedBox(
                          width: double.infinity,
                          child: _CoachHero(
                            key: const ValueKey('ai-coach-hero'),
                            interactionEnabled: conversationInteractive,
                            onBack: () {
                              questionFocus.unfocus();
                              _updateState(() => _referenceOverview = true);
                            },
                            onHistory: () =>
                                unawaited(_openConversationHistory()),
                            onMenu: () =>
                                unawaited(_openCoachMenuSheet(context)),
                          ),
                        ),
                      ),
                    ),
                    if (conversationLoadFailed)
                      _CoachReplyFailure(
                        labelOverride: tr(
                          'Conversation history',
                          'سجل المحادثات',
                        ),
                        onDismiss: () {},
                        onRetry: () => unawaited(_loadConversation()),
                      ),
                    Expanded(
                      child: CoachConversationRestartPull(
                        controller: conversationScroll,
                        enabled:
                            conversationInteractive &&
                            !sending &&
                            !listening &&
                            !voiceCaptureStarting &&
                            !voiceSubmitPending &&
                            voiceMode == _CoachVoiceMode.idle &&
                            !foodImageFlowOpening &&
                            !conversationHistoryOpening &&
                            !coachMenuOpening &&
                            !consentPromptVisible &&
                            messages.any(
                              (message) =>
                                  message.role == IntelligenceMessageRole.user,
                            ),
                        conversationIdentity: activeConversationId,
                        label: tr('Start new conversation', 'بدء محادثة جديدة'),
                        onRestart: _startNewConversation,
                        child: ChatHistoryViewport(
                          controller: conversationScroll,
                          latestMessageId: visibleMessages.isEmpty
                              ? null
                              : visibleMessages.last.id,
                          centerJumpButton: true,
                          latestTargetOffset: _coachLatestReadingOffset,
                          onLatestRequested: () => _scrollToLatest(force: true),
                          child: AbsorbPointer(
                            absorbing: !conversationInteractive,
                            // Do not paint a provisional greeting and replace it
                            // with the restored transcript one frame later. The
                            // stable surface keeps the coach shell opaque while
                            // local history is read, then paints user content
                            // exactly once.
                            child: !conversationReady
                                ? ColoredBox(color: scheme.surface)
                                : visibleMessages.isEmpty
                                ? _CoachEmptyState(
                                    onVoice: _toggleLiveCall,
                                    onCamera: _analyzeFoodImageInChat,
                                  )
                                : _buildConversationHistory(
                                    visibleMessages,
                                    dailyBrief: showIntroBrief
                                        ? dailyBrief
                                        : null,
                                    showLiveVoiceDraft: showLiveVoiceDraft,
                                    showReplyThinking: showReplyThinking,
                                    showReplyFailure: showReplyFailure,
                                  ),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: SizedBox(
                          width: double.infinity,
                          child: SafeArea(
                            top: false,
                            child: AnimatedContainer(
                              key: const Key('ai-coach-composer-surface'),
                              duration: const Duration(milliseconds: 220),
                              margin: const EdgeInsets.fromLTRB(12, 5, 12, 12),
                              padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
                              decoration: BoxDecoration(
                                gradient: BilPearlFinish.panel(
                                  context,
                                ).gradient,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: listening
                                      ? (Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? BilPearlFinish.darkEdge
                                            : BilPearlFinish.lightEdge)
                                      : scheme.outlineVariant.withValues(
                                          alpha: .55,
                                        ),
                                  width: listening ? 1.5 : .8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: scheme.shadow.withValues(alpha: .07),
                                    blurRadius: 22,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _buildCoachQuickPromptMenu(),
                                  Expanded(
                                    child: listening
                                        ? _ListeningComposerLabel(
                                            label: tr(
                                              'Listening — pause when you’re done',
                                              'أستمع — اسكت عندما تنتهي',
                                            ),
                                            transcript: pendingVoiceTranscript,
                                          )
                                        : TextField(
                                            key: const Key(
                                              'ai-coach-question-field',
                                            ),
                                            controller: question,
                                            focusNode: questionFocus,
                                            enabled: conversationInteractive,
                                            minLines: 1,
                                            maxLines:
                                                MediaQuery.viewInsetsOf(
                                                          context,
                                                        ).bottom >
                                                        0 &&
                                                    MediaQuery.sizeOf(
                                                          context,
                                                        ).height <
                                                        740
                                                ? 2
                                                : 4,
                                            textAlignVertical:
                                                TextAlignVertical.center,
                                            textInputAction:
                                                TextInputAction.send,
                                            onTap: _scrollToLatest,
                                            onTapOutside: (_) => FocusScope.of(
                                              context,
                                            ).unfocus(),
                                            onSubmitted: (_) => ask(),
                                            scrollPadding:
                                                const EdgeInsets.symmetric(
                                                  vertical: 8,
                                                ),
                                            onChanged: (_) =>
                                                _updateState(() {}),
                                            decoration: InputDecoration(
                                              hintMaxLines: 1,
                                              hintText: tr(
                                                'Ask BIL anything about your day…',
                                                'اسأل BIL أي شيء عن يومك…',
                                              ),
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              filled: false,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 8,
                                                  ),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 4),
                                  if (sending)
                                    _buildCoachComposerAction(
                                      actionKey: const Key(
                                        'ai-coach-send-button',
                                      ),
                                      label: tr('Sending', 'جارٍ الإرسال'),
                                      onPressed: null,
                                      icon: BilCrystalArrow(
                                        extent: 36,
                                        child: Icon(
                                          Icons.arrow_upward_rounded,
                                          size: 25,
                                          color: _coachComposerActionInk
                                              .withValues(alpha: .38),
                                        ),
                                      ),
                                    )
                                  else if (question.text.trim().isEmpty ||
                                      listening)
                                    _buildCoachComposerAction(
                                      actionKey: const Key(
                                        'ai-coach-voice-button',
                                      ),
                                      label:
                                          voiceMode == _CoachVoiceMode.liveCall
                                          ? tr(
                                              'End live call',
                                              'إنهاء المكالمة',
                                            )
                                          : tr('Talk to BIL', 'تحدث مع BIL'),
                                      onPressed: !conversationInteractive
                                          ? null
                                          : voiceMode ==
                                                _CoachVoiceMode.liveCall
                                          ? _stopLiveCall
                                          : _toggleLiveCall,
                                      icon: listening
                                          ? const _VoiceListeningWave(
                                              color: _coachComposerActionInk,
                                              compact: true,
                                            )
                                          : Icon(
                                              Icons.graphic_eq_rounded,
                                              color: conversationInteractive
                                                  ? _coachComposerActionInk
                                                  : _coachComposerActionInk
                                                        .withValues(alpha: .38),
                                            ),
                                    )
                                  else
                                    _buildCoachComposerAction(
                                      actionKey: const Key(
                                        'ai-coach-send-button',
                                      ),
                                      label: tr('Send', 'إرسال'),
                                      onPressed: !conversationInteractive
                                          ? null
                                          : ask,
                                      icon: BilCrystalArrow(
                                        extent: 36,
                                        child: Icon(
                                          Icons.arrow_upward_rounded,
                                          size: 25,
                                          color: conversationInteractive
                                              ? _coachComposerActionInk
                                              : _coachComposerActionInk
                                                    .withValues(alpha: .38),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 2),
                                  IconButton(
                                    key: const Key(
                                      'ai-coach-food-image-button',
                                    ),
                                    tooltip: tr('Open camera', 'افتح الكاميرا'),
                                    onPressed:
                                        !conversationInteractive ||
                                            foodImageFlowOpening ||
                                            sending
                                        ? null
                                        : _analyzeFoodImageInChat,
                                    style: IconButton.styleFrom(
                                      foregroundColor: scheme.onSurfaceVariant,
                                      minimumSize: const Size.square(44),
                                    ),
                                    icon: analyzingFoodImage
                                        ? SizedBox.square(
                                            dimension: 19,
                                            child: BilFeatureWelcomeStatus(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.camera_alt_outlined,
                                            size: 22,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoachComposerAction({
    required Key actionKey,
    required String label,
    required VoidCallback? onPressed,
    required Widget icon,
  }) {
    final contrast = MediaQuery.highContrastOf(context);
    return DecoratedBox(
      key: const Key('ai-coach-composer-action-finish'),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFECF3F8), Color(0xFFD7E4EF)],
        ),
        border: Border.all(
          color: contrast ? _coachComposerActionInk : const Color(0xFFBCCDDD),
          width: contrast ? 1.5 : .8,
        ),
        boxShadow: contrast
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x14223F58),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: IconButton(
        key: actionKey,
        tooltip: label,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          minimumSize: const Size.square(48),
          fixedSize: const Size.square(48),
          foregroundColor: _coachComposerActionInk,
          disabledForegroundColor: _coachComposerActionInk.withValues(
            alpha: .38,
          ),
          backgroundColor: Colors.transparent,
          shape: const CircleBorder(),
          visualDensity: VisualDensity.standard,
        ),
        // Plain solid glyph, as in Community: no inherited primary tint.
        icon: icon,
      ),
    );
  }
}
