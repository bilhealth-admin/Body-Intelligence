import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final page =
      [
            'intelligence_center_page.dart',
            'intelligence_center_widgets.dart',
            'intelligence_center_message_widgets.dart',
            'intelligence_center_voice_widgets.dart',
            'intelligence_conversation_voice.dart',
            'intelligence_query_flow.dart',
            'intelligence_action_flow.dart',
          ]
          .map(
            (name) => File(
              'lib/features/intelligence_center/presentation/$name',
            ).readAsStringSync(),
          )
          .join('\n');
  final shell = File(
    'lib/app/router/responsive_app_shell.dart',
  ).readAsStringSync();

  test('AI Coach has direct text, voice, camera, and send contracts', () {
    expect(page, contains("Key('ai-coach-question-field')"));
    expect(page, contains('textInputAction: TextInputAction.send'));
    expect(page, contains('onSubmitted: (_) => ask()'));
    expect(page, contains("Key('ai-coach-voice-button')"));
    expect(page, contains("Key('ai-coach-send-button')"));
    expect(page, contains("Key('ai-coach-food-image-button')"));
    expect(page, contains('const source = ImageSource.camera'));
    expect(page, contains('_showVoiceUnavailable()'));
    expect(page, contains("String pendingVoiceTranscript = ''"));
    expect(page, contains('pendingVoiceTranscript = transcript'));
    expect(page, contains('question.value = TextEditingValue('));
    expect(page, contains('if (await _startNativeVoiceCapture()) return;'));
    expect(page, contains('_LiveVoiceTranscript'));
    expect(page, contains('Writing your words'));
    expect(page, contains('Live call transcript'));
    expect(page, contains('Duration(seconds: 2)'));
    expect(page, contains('_submitVoiceTranscript()'));
  });

  test('bottom dictation and top live call are separate state machines', () {
    expect(
      page,
      contains('enum _CoachVoiceMode { idle, dictation, liveCall }'),
    );
    expect(page, contains('_toggleDictation()'));
    expect(page, contains('_toggleLiveCall()'));
    expect(page, contains('autoSpeakReply: autoSpeakReply'));
    expect(page, contains('voiceMode == _CoachVoiceMode.liveCall'));
    expect(page, contains("Key('ai-coach-live-call-stop')"));
    expect(page, contains('_resumeLiveCallIfNeeded'));
    expect(page, contains('await _startVoiceCapture();'));
    expect(page, contains('CoachVoiceEntryPoint.composerDictation'));
    expect(page, contains('CoachVoiceEntryPoint.liveCall'));
  });

  test('slow and failed replies remain visible and actionable', () {
    expect(page, contains('enum _CoachReplyPhase'));
    expect(page, contains("Key('ai-coach-reply-progress')"));
    expect(page, contains("Key('ai-coach-cancel-request')"));
    expect(page, contains("Key('ai-coach-retry')"));
    expect(page, contains('Searching your BIL context'));
    expect(page, contains('timeout(const Duration(seconds: 50))'));
  });

  test('typed and voice turns have separate presentation contracts', () {
    expect(page, contains('IntelligenceMessageModality.voice'));
    expect(page, contains('inputChannel == CoachInputChannel.voice'));
    expect(page, isNot(contains("Key('ai-coach-speak-\${message.id}')")));
    expect(page, isNot(contains('Replay voice reply')));
    expect(page, contains('final String text;'));
    expect(page, contains('final visibleMessages = messages.toList'));
  });

  test('session greeting and day-one decision remain visible', () {
    expect(page, contains('_sessionWelcome(displayName)'));
    expect(page, contains('_InlineCoachDecision'));
    expect(page, contains('final showIntroBrief = introVisible'));
    expect(page, contains("ValueKey('ai-coach-hero')"));
    expect(page, contains("Key('ai-coach-hero-start')"));
    expect(page, contains('bil_male_smart_coach_v1.png'));
    expect(page, contains('colors: [Color(0xFF12394E), Color(0xFF071923)]'));
    expect(page, contains("tr('Ready', 'جاهز')"));
    expect(page, contains('Thinking with your BIL data'));
    expect(page, contains('final visibleMessages = messages'));
    expect(
      page,
      isNot(
        contains(
          "!message.id.startsWith('welcome') &&\n"
          '              !(message.role',
        ),
      ),
    );
  });

  test('AI Coach stays pinned to the newest message', () {
    expect(page, contains('with WidgetsBindingObserver'));
    expect(page, contains('void didChangeMetrics()'));
    expect(page, contains('_scrollToLatest();'));
    expect(page, contains('reverse: true'));
    expect(page, contains('conversationScroll.position.minScrollExtent'));
  });

  test('technical runtime diagnostics are not presented as chat copy', () {
    expect(page, contains('_presentationSafeMessage('));
    expect(page, contains("'ai context is not accepted'"));
    expect(page, contains("'bil did not expose an action'"));
  });

  test('assistant feedback is a stateful reaction, not dead icons', () {
    expect(page, contains('final messageFeedback = <String, bool>{}'));
    expect(page, contains('_QuickFeedbackBar'));
    expect(page, contains('_FeedbackReaction'));
    expect(page, contains('messageFeedback[message.id] = helpful'));
    expect(page, contains('selected: selected'));
    expect(page, contains('HapticFeedback.selectionClick()'));
  });

  test('every generated answer exposes an in-app safety report path', () {
    expect(page, contains("Key('ai-coach-report-\${message.id}')"));
    expect(page, contains("Key('ai-coach-confirm-report')"));
    expect(page, contains('Report unsafe or offensive answer'));
    expect(page, contains("onReport('unsafe')"));
    expect(page, contains('reason: reason'));
  });

  test('AI Coach is immersive and dashboard actions cannot cover it', () {
    expect(
      shell,
      contains('floatingActionButton: isDashboard ? quickButton : null'),
    );
    expect(
      shell,
      contains("final immersiveCoach = currentPath == '/intelligence-center'"),
    );
    expect(shell, contains('bottomNavigationBar: immersiveCoach'));
  });

  test('premium chat removes fixed prompt strips and nested answer cards', () {
    expect(page, isNot(contains('class _QuickQuestions')));
    expect(page, isNot(contains('ExpansionTile(')));
    expect(page, contains('_showMessageDetails(context, message)'));
    expect(page, contains('showModalBottomSheet<void>'));
    expect(page, contains('_messageTextDirection(message.text)'));
  });

  test('coach voice and controls use the premium in-conversation surface', () {
    expect(page, contains('const _CoachMenuSheet()'));
    expect(page, contains('_openCoachMenuSheet()'));
    expect(page, contains('Icons.graphic_eq_rounded'));
    expect(page, contains('_VoiceListeningWave('));
    expect(page, isNot(contains('PopupMenuButton<String>')));
    expect(page, isNot(contains('Icons.stop_rounded')));
    expect(page, isNot(contains('Icons.mic_rounded')));
    expect(page, isNot(contains('_CoachConversationHeader')));
  });
}
