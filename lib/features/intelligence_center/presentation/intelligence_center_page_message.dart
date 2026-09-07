part of 'intelligence_center_page.dart';

extension on _IntelligenceCenterPageState {
  Widget _buildMessage(
    IntelligenceMessage message,
    Map<String, bool> feedback,
  ) {
    final canRate =
        message.role == IntelligenceMessageRole.bil &&
        !message.id.startsWith('welcome') &&
        !message.id.startsWith('tool-');
    return _MessageBubble(
      message: message,
      feedbackValue: feedback[message.id],
      reported: reportedMessages.contains(message.id),
      onSpeak:
          message.role == IntelligenceMessageRole.bil &&
              message.modality == IntelligenceMessageModality.voice
          ? () {
              final language = const CoachLanguageResolver()
                  .resolve(
                    input: message.text,
                    uiLocale: Localizations.localeOf(context).toLanguageTag(),
                  )
                  .languageTag;
              unawaited(
                _speakCoachText(message.text, language, showFailure: true),
              );
            }
          : null,
      onFeedback: canRate
          ? (helpful) => _recordFeedback(message, helpful)
          : null,
      onReport: canRate
          ? (reason) => _recordFeedback(message, false, reason: reason)
          : null,
      onAction: (action) => unawaited(_executeAction(action)),
    );
  }
}
