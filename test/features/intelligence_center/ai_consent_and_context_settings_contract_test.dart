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

  test('Coach settings uses consent policy v3 and exposes every context focus', () {
    final page = File(
      'lib/features/intelligence_center/presentation/ai_coach_settings_page.dart',
    ).readAsStringSync();
    final components = File(
      'lib/features/intelligence_center/presentation/'
      'ai_coach_settings_components.dart',
    ).readAsStringSync();
    final settingsBody = File(
      'lib/features/intelligence_center/presentation/'
      'ai_coach_settings_body.dart',
    ).readAsStringSync();
    final coordinator = File(
      'lib/features/intelligence_center/services/'
      'remote_ai_consent_coordinator.dart',
    ).readAsStringSync();

    expect(page, contains('sharedRemoteAiConsentCoordinator()'));
    expect(page, contains('coordinator.grantAndVerify()'));
    expect(page, contains('coordinator.revokeAndVerify()'));
    expect(
      page,
      contains("if (!verified) throw StateError('consent_readback_failed')"),
    );
    expect(coordinator, contains("client.rpc('bil_get_remote_ai_consent')"));
    expect(
      "'p_policy_version': '3'".allMatches(coordinator),
      hasLength(2),
      reason: 'Both Allow and withdrawal write the current server policy.',
    );
    expect(coordinator, contains("'p_purpose': 'remote_ai'"));
    expect(coordinator, contains("'p_granted': true"));
    expect(coordinator, contains("'p_granted': false"));
    expect(coordinator, contains('isCurrentRemoteAiConsentGranted(receipt)'));
    expect(page, isNot(contains("policyVersion = '1'")));
    expect(coordinator, isNot(contains("'p_policy_version': '1'")));
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
      settingsBody,
      contains(
        'When enabled, your question and selected weight/body, nutrition, activity, sleep, habit, and recent conversation context can be sent to Google Gemini, a third-party AI service operated by Google, only to answer your request. Turn this off at any time; local BIL features remain available.',
      ),
      reason: 'The visible consent disclosure must name its bounded data uses.',
    );
  });

  test('in-conversation consent prompt states the actual speech boundary', () {
    final page = File(
      'lib/features/intelligence_center/presentation/intelligence_center_page.dart',
    ).readAsStringSync();
    expect(page, contains("part 'intelligence_query_guard_flow.dart';"));
    final source = File(
      'lib/features/intelligence_center/presentation/intelligence_query_guard_flow.dart',
    ).readAsStringSync();

    expect(source, contains('Send selected personal data to Google Gemini?'));
    expect(source, contains('third-party AI service operated by Google'));
    expect(
      source,
      contains(
        'BIL sends Gemini only recognized text, never raw microphone audio.',
      ),
    );
    expect(source, contains("Don't Allow"));
    expect(source, contains('Allow & Continue'));
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

  test(
    'Arabic AI disclosure declines data transfer while retaining local features',
    () {
      // Check the public resolver used by the actual privacy surfaces, including
      // regional Arabic tags. A translation must not say to refuse local features.
      const disclosures = <String>[
        'If you agree, BIL sends your question and only the context you selected—such as weight, goals and measurements; meals, nutrition, water and preferences; activity and training; sleep and habits; plus up to 12 recent conversation turns—to Google Gemini, a third-party AI service operated by Google, to generate your requested answer. Raw microphone audio is not sent to BIL or Google Gemini. You can decline and keep using BIL’s local features, and withdraw consent later in AI Coach settings.',
        'AI Coach is optional. With consent, selected personal context is sent to Google Gemini, a third-party AI service operated by Google, only to answer your request. You may decline and keep local features.',
        'BIL sends your questions and only the categories you select—weight, goals and measurements; meals, nutrition, water and preferences; activity and training; sleep and habits; plus up to 12 recent conversation turns—to Google Gemini, a third-party AI service operated by Google, to generate requested answers. Raw microphone audio is not sent. You can decline and keep using local features, or withdraw later in AI Coach settings.',
      ];
      for (final locale in ['ar', 'ar-EG', 'ar_SA']) {
        for (final disclosure in disclosures) {
          final visible = RuntimeCopy.resolve(disclosure, locale);
          expect(
            visible,
            isNotNull,
            reason: 'Every Arabic consent surface resolves.',
          );
          expect(visible, contains('Google Gemini'));
          expect(visible, contains('تديرها Google'));
          expect(
            visible,
            contains(
              'يمكنك رفض إرسال البيانات ومواصلة استخدام ميزات BIL المحلية',
            ),
            reason:
                'Refusal applies to data transmission; local features stay available.',
          );
          expect(visible, isNot(contains('رفض الميزات المحلية')));
          expect(visible, isNot(contains('رفض ميزات BIL المحلية')));
        }
        for (final disclosure in [disclosures.first, disclosures.last]) {
          final visible = RuntimeCopy.resolve(disclosure, locale)!;
          expect(visible, contains('12 دورًا من المحادثة'));
          expect(
            visible,
            contains('سحب هذه الموافقة لاحقًا من إعدادات AI Coach'),
          );
          expect(visible, contains('صوت الميكروفون الخام'));
        }
      }
    },
  );
}
