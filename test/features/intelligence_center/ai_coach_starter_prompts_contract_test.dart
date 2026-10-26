import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starter prompts route through the real Coach query path', () {
    final viewport = File(
      'lib/features/intelligence_center/presentation/intelligence_conversation_viewport.dart',
    ).readAsStringSync();
    final widgets = File(
      'lib/features/intelligence_center/presentation/intelligence_center_widgets.dart',
    ).readAsStringSync();
    final actions = File(
      'lib/features/intelligence_center/presentation/intelligence_action_flow.dart',
    ).readAsStringSync();

    // The owner requested retaining the opening row after sending. Starters
    // still require an authorized brief, independent of transcript length.
    expect(viewport, contains('final showStarters = dailyBrief != null;'));
    expect(viewport, contains('if (showStarters) _CoachStarterPrompts'));
    expect(viewport, contains("if (showOpeningSurface) 'coach-session-brief'"));
    expect(viewport, isNot(contains("'coach-starter-prompts'")));
    expect(viewport, contains('_CoachStarterPrompts(onPrompt: usePrompt)'));
    expect(widgets, contains("ValueKey('ai-coach-starter-prompts')"));
    expect(widgets, contains("'Review my day from my saved BIL data"));
    expect(widgets, contains('without inventing missing data.'));
    expect(actions, contains('question.text = value;'));
    expect(actions, contains('ask();'));
  });
}
