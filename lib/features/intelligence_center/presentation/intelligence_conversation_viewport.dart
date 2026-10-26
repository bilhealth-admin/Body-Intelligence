part of 'intelligence_center_page.dart';

extension _IntelligenceConversationViewport on _IntelligenceCenterPageState {
  Widget _buildConversationHistory(
    List<IntelligenceMessage> visibleMessages, {
    required CoachDailyBrief? dailyBrief,
    required bool showLiveVoiceDraft,
    required bool showReplyThinking,
    required bool showReplyFailure,
  }) {
    // The daily brief is already the opening Coach surface. Do not stack the
    // synthetic welcome beneath it; retain it as the fallback when context is
    // unavailable. This is presentation-only: user turns/history are untouched.
    final openingMessage = visibleMessages
        .where((message) => message.id.startsWith('welcome'))
        .firstOrNull;
    final presentedMessages = visibleMessages
        .where((message) => !message.id.startsWith('welcome'))
        .toList(growable: false);
    final showOpeningSurface = dailyBrief != null || openingMessage != null;
    // Keep the opening surface as one scrollable row after the first turn.
    // Pending/failed context still must not advertise saved data.
    final showStarters = dailyBrief != null;
    final ids = <String>[
      // One anchored identity for the welcome transcript and its data-backed
      // replacement prevents refreshes from resetting the reading position.
      if (showOpeningSurface) 'coach-session-brief',
      ...presentedMessages.map((message) => message.id),
      if (showLiveVoiceDraft) 'coach-live-draft',
      if (showReplyThinking) 'coach-reply-thinking',
      if (showReplyFailure) 'coach-reply-failure',
    ];
    return CoachAnchoredHistory(
      controller: conversationScroll,
      rowIds: ids,
      itemBuilder: (context, index) {
        final id = ids[index];
        if (id == 'coach-session-brief') {
          final brief = dailyBrief;
          if (brief == null) {
            return _buildMessage(openingMessage!, messageFeedback);
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _InlineCoachDecision(
                brief: brief,
                onAction: () {
                  if (brief.kind == CoachDailyBriefKind.experiment) {
                    context.push('/experiments');
                  } else {
                    usePrompt(brief.suggestedPrompt);
                  }
                },
              ),
              if (showStarters) _CoachStarterPrompts(onPrompt: usePrompt),
            ],
          );
        }
        if (id == 'coach-live-draft') {
          return _LiveVoiceTranscript(
            text: pendingVoiceTranscript.trim(),
            liveCall: voiceMode == _CoachVoiceMode.liveCall,
          );
        }
        if (id == 'coach-reply-thinking') {
          return const _CoachThinkingIndicator();
        }
        if (id == 'coach-reply-failure') {
          return _CoachReplyFailure(
            onDismiss: _cancelCurrentCoachRequest,
            onRetry: failedRequest == null ? null : _retryFailedCoachRequest,
            retryLabel: _coachRetryLabel,
          );
        }
        return _buildMessage(
          presentedMessages[index - (showOpeningSurface ? 1 : 0)],
          messageFeedback,
        );
      },
    );
  }
}
