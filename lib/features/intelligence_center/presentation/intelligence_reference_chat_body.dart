part of 'intelligence_center_page.dart';

extension _IntelligenceReferenceChatBody on _IntelligenceCenterPageState {
  Widget _buildReferenceChat(BuildContext context) {
    if (entryWelcomeVisible) {
      return const _AiCoachEntryWelcome();
    }
    final scheme = Theme.of(context).colorScheme;
    final coachContext = ref.watch(coachHealthBriefProvider);
    // Do not retain a previous owner's/category's brief while its current
    // bounded provider is rebuilding or access has been withdrawn.
    final snapshot = coachContext.isLoading ? null : coachContext.asData?.value;
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
    const coachNavy = Color(0xFF07111B);
    return Scaffold(
      bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : BilReferenceBottomBar(
              selected: 1,
              dark: true,
              onSelected: (index) => unawaited(_navigateReference(index)),
            ),
      backgroundColor: coachNavy,
      body: ColoredBox(
        color: coachNavy,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.zero,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 760),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.zero,
                  border: Border.all(color: Colors.transparent, width: 0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .3),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _CoachHero(
                      key: const ValueKey('ai-coach-hero'),
                      interactionEnabled: conversationReady,
                      onBack: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/dashboard');
                        }
                      },
                      onHistory: () => unawaited(_openConversationHistory()),
                      onMenu: () => unawaited(_openCoachMenuSheet()),
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
                      child: ChatHistoryViewport(
                        controller: conversationScroll,
                        latestMessageId: visibleMessages.isEmpty
                            ? null
                            : visibleMessages.last.id,
                        centerJumpButton: true,
                        child: AbsorbPointer(
                          absorbing: !conversationReady,
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
                    SafeArea(
                      top: false,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.fromLTRB(12, 5, 12, 12),
                        padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: listening
                                ? scheme.primary.withValues(alpha: .62)
                                : scheme.outlineVariant.withValues(alpha: .55),
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
                            _buildCoachPermissionMenu(),
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
                                      key: const Key('ai-coach-question-field'),
                                      controller: question,
                                      enabled: conversationReady,
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
                                      textInputAction: TextInputAction.send,
                                      onTap: _scrollToLatest,
                                      onSubmitted: (_) => ask(),
                                      scrollPadding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      onChanged: (_) => _updateState(() {}),
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
                              IconButton.filled(
                                key: const Key('ai-coach-send-button'),
                                tooltip: tr('Sending', 'جارٍ الإرسال'),
                                onPressed: null,
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFF12394E),
                                  foregroundColor: const Color(0xFFC8F3FF),
                                  disabledBackgroundColor: const Color(
                                    0xFF12394E,
                                  ).withValues(alpha: .58),
                                  disabledForegroundColor: const Color(
                                    0xFFC8F3FF,
                                  ).withValues(alpha: .58),
                                  minimumSize: const Size.square(48),
                                ),
                                icon: const Icon(Icons.arrow_upward_rounded),
                              )
                            else if (question.text.trim().isEmpty || listening)
                              IconButton.filled(
                                key: const Key('ai-coach-voice-button'),
                                tooltip: voiceMode == _CoachVoiceMode.liveCall
                                    ? tr('End live call', 'إنهاء المكالمة')
                                    : tr('Talk to BIL', 'تحدث مع BIL'),
                                onPressed: !conversationReady
                                    ? null
                                    : voiceMode == _CoachVoiceMode.liveCall
                                    ? _stopLiveCall
                                    : _toggleLiveCall,
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFF12394E),
                                  foregroundColor: const Color(0xFFC8F3FF),
                                  minimumSize: const Size.square(48),
                                ),
                                icon: listening
                                    ? const _VoiceListeningWave(
                                        color: Color(0xFFC8F3FF),
                                        compact: true,
                                      )
                                    : const Icon(Icons.graphic_eq_rounded),
                              )
                            else
                              IconButton.filled(
                                key: const Key('ai-coach-send-button'),
                                tooltip: tr('Send', 'إرسال'),
                                onPressed: !conversationReady ? null : ask,
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFF12394E),
                                  foregroundColor: const Color(0xFFC8F3FF),
                                  minimumSize: const Size.square(48),
                                ),
                                icon: const Icon(Icons.arrow_upward_rounded),
                              ),
                            const SizedBox(width: 2),
                            IconButton(
                              key: const Key('ai-coach-food-image-button'),
                              tooltip: tr('Open camera', 'افتح الكاميرا'),
                              onPressed:
                                  !conversationReady ||
                                      foodImageFlowOpening ||
                                      sending
                                  ? null
                                  : _analyzeFoodImageInChat,
                              style: IconButton.styleFrom(
                                foregroundColor: const Color(0xFFBFD0E5),
                                minimumSize: const Size.square(44),
                              ),
                              icon: analyzingFoodImage
                                  ? const SizedBox.square(
                                      dimension: 19,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
