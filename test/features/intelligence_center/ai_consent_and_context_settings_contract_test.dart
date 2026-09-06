import 'dart:io';

import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_preferences.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/ai_coach_settings_page.dart';
import 'package:body_intelligence_log/features/onboarding/onboarding_runtime_copy.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings usage focus decoder preserves explicit user boundaries', () {
    expect(
      coachContextFocusesFromUsage(<String>['nutrition', 'habits']),
      <CoachContextFocus>{
        CoachContextFocus.nutrition,
        CoachContextFocus.habits,
      },
    );
    expect(coachContextFocusesFromUsage(const <String>[]), isEmpty);
    expect(
      coachContextFocusesFromUsage('malformed'),
      const CoachContextPreferences().focuses,
    );
  });

  test(
    'Coach settings uses consent policy v2 and exposes every context focus',
    () {
      final page = File(
        'lib/features/intelligence_center/presentation/ai_coach_settings_page.dart',
      ).readAsStringSync();
      final components = File(
        'lib/features/intelligence_center/presentation/'
        'ai_coach_settings_components.dart',
      ).readAsStringSync();

      expect(page, contains("'p_policy_version': '2'"));
      expect(page, isNot(contains("policyVersion = '1'")));
      expect(page, contains('CoachContextPreferences.storageKey'));
      for (final focus in CoachContextFocus.values) {
        expect(
          components,
          contains("'ai-coach-context-\${option.\$1.name}'"),
          reason: 'Every rendered focus must use the stable keyed control.',
        );
        expect(components, contains('CoachContextFocus.${focus.name}'));
      }
      expect(
        page,
        contains('last 12 turns sent with that request'),
        reason: 'The disclosure must match the bounded conversation payload.',
      );
    },
  );

  test('in-conversation consent prompt states the actual speech boundary', () {
    final source = File(
      'lib/features/intelligence_center/presentation/intelligence_query_flow.dart',
    ).readAsStringSync();

    expect(source, contains('Use your selected context with BIL?'));
    expect(source, contains('through BIL’s secure gateway to Gemini'));
    expect(source, contains('Raw microphone audio is not sent'));
    expect(source, contains('platform speech service may process it'));
  });

  test('non-core locales retain reviewed Coach privacy and focus copy', () {
    const disclosure =
        'When enabled, only the bounded context needed for your question is sent to BIL’s Gemini service. Conversation history remains local except for the last 12 turns sent with that request. Turn this off at any time.';
    final germanDisclosure = RuntimeCopy.resolve(disclosure, 'de');
    expect(germanDisclosure, isNotNull);
    expect(germanDisclosure, isNot(disclosure));

    const contextTitle = 'Choose whether to use cloud AI';
    final germanContextTitle = OnboardingRuntimeCopy.resolve(
      contextTitle,
      const Locale('de'),
    );
    expect(germanContextTitle, isNot(contextTitle));
  });
}
