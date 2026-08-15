import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final page = File(
    'lib/features/intelligence_center/presentation/'
    'intelligence_center_page.dart',
  ).readAsStringSync();
  final shell = File(
    'lib/app/router/responsive_app_shell.dart',
  ).readAsStringSync();

  test('AI Coach composer has explicit text, voice, and send contracts', () {
    expect(page, contains("Key('ai-coach-question-field')"));
    expect(page, contains('textInputAction: TextInputAction.send'));
    expect(page, contains('onSubmitted: (_) => ask()'));
    expect(page, contains("Key('ai-coach-voice-button')"));
    expect(page, contains("Key('ai-coach-send-button')"));
    expect(page, contains('_showVoiceUnavailable()'));
    expect(page, contains('تعذر تشغيل الإدخال الصوتي الآن'));
  });

  test('AI Coach stays pinned to the newest message', () {
    expect(page, contains('with SingleTickerProviderStateMixin, WidgetsBindingObserver'));
    expect(page, contains('void didChangeMetrics()'));
    expect(page, contains('_scrollToLatest();'));
    expect(page, contains('conversationScroll.position.maxScrollExtent'));
  });

  test('technical runtime diagnostics are not presented as chat copy', () {
    expect(page, contains('_presentationSafeMessage('));
    expect(page, contains("'ai context is not accepted'"));
    expect(page, contains("'bil did not expose an action'"));
    expect(page, contains('تعذر إكمال هذا الرد الآن'));
  });

  test('dashboard quick add cannot cover non-dashboard composers', () {
    expect(
      shell,
      contains('floatingActionButton: isDashboard ? quickButton : null'),
    );
  });
}
