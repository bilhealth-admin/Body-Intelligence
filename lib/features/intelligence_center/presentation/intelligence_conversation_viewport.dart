part of 'intelligence_center_page.dart';

extension _IntelligenceConversationViewport on _IntelligenceCenterPageState {
  Widget _buildConversationHistory(
    List<IntelligenceMessage> visibleMessages, {
    required CoachDailyBrief? dailyBrief,
    required bool showLiveVoiceDraft,
    required bool showReplyFailure,
  }) {
    final ids = <String>[
      if (dailyBrief != null) 'coach-session-brief',
      ...visibleMessages.map((message) => message.id),
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
          visibleMessages[index - (dailyBrief == null ? 0 : 1)],
          messageFeedback,
        );
      },
    );
  }
}
