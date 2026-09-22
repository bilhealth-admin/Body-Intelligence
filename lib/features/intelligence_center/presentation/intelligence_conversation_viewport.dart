part of 'intelligence_center_page.dart';

extension _IntelligenceConversationViewport on _IntelligenceCenterPageState {
  Widget _buildConversationHistory(
    List<IntelligenceMessage> visibleMessages, {
    required CoachDailyBrief? dailyBrief,
    required bool showLiveVoiceDraft,
    required bool showReplyFailure,
  }) {
    // The daily brief is already the opening Coach surface. Do not stack the
    // synthetic welcome beneath it; retain it as the fallback when context is
    // unavailable. This is presentation-only: user turns/history are untouched.
    final presentedMessages = dailyBrief == null
        ? visibleMessages
        : visibleMessages
              .where((message) => !message.id.startsWith('welcome'))
              .toList(growable: false);
    final ids = <String>[
      if (dailyBrief != null) 'coach-session-brief',
      ...presentedMessages.map((message) => message.id),
      if (showLiveVoiceDraft) 'coach-live-draft',
      if (showReplyFailure) 'coach-reply-failure',
    ];
    return CoachAnchoredHistory(
      controller: conversationScroll,
      rowIds: ids,
      itemBuilder: (context, index) {
        final id = ids[index];
        if (id == 'coach-session-brief') {
          final brief = dailyBrief!;
          return _InlineCoachDecision(
            brief: brief,
            onAction: () {
              if (brief.kind == CoachDailyBriefKind.experiment) {
                context.push('/experiments');
              } else {
                usePrompt(brief.suggestedPrompt);
              }
            },
          );
        }
        if (id == 'coach-live-draft') {
          return _LiveVoiceTranscript(
            text: pendingVoiceTranscript.trim(),
            liveCall: voiceMode == _CoachVoiceMode.liveCall,
          );
        }
        if (id == 'coach-reply-failure') {
          return _CoachReplyFailure(
            onDismiss: _cancelCurrentCoachRequest,
            onRetry: failedRequest == null ? null : _retryFailedCoachRequest,
          );
        }
        return _buildMessage(
          presentedMessages[index - (dailyBrief == null ? 0 : 1)],
          messageFeedback,
        );
      },
    );
  }
}
