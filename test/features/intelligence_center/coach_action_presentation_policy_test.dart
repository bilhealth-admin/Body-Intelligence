import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_action.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_action_presentation_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = CoachActionPresentationPolicy();
  const weightHistory = IntelligenceAction(
    id: 'open-weight-history',
    type: IntelligenceActionType.navigate,
    label: 'Open weight history',
    requiresConfirmation: false,
    payload: <String, Object?>{'target': 'weight_history'},
  );

  test('Arabic and English direct open requests auto-run read-only routes', () {
    expect(
      policy.isDirectNavigationRequest('استعرض سجل أوزاني', weightHistory),
      isTrue,
    );
    expect(
      policy.isDirectNavigationRequest('Open my weight history', weightHistory),
      isTrue,
    );
  });

  test('a suggested screen does not auto-open without a direct command', () {
    expect(
      policy.isDirectNavigationRequest('Build me a weekly plan', weightHistory),
      isFalse,
    );
  });

  test('review is not the navigation verb view inside another word', () {
    for (final input in [
      'Review my day from my saved BIL data and tell me the most useful next step.',
      'Review today’s nutrition from my saved BIL data. What stands out and what should I focus on next?',
      'Explain my recorded sleep trend and what it may mean for today, without inventing missing data.',
      'Based on my selected BIL context, what is the single best thing to focus on next and why?',
      'Give me an overview of my progress',
      'Preview the proposed workout without opening another screen',
      'My goals show improvement',
      'راجع يومي من بيانات BIL المحفوظة وأخبرني بأكثر خطوة مفيدة الآن.',
    ]) {
      expect(
        policy.isDirectNavigationRequest(input, weightHistory),
        isFalse,
        reason: input,
      );
    }
    for (final input in [
      'View my weight history',
      'Please open my weight history.',
      'Go to my weight history',
      'افتح سجل أوزاني',
    ]) {
      expect(
        policy.isDirectNavigationRequest(input, weightHistory),
        isTrue,
        reason: input,
      );
    }
  });

  test('short follow-up open commands can reuse the latest safe action', () {
    expect(policy.isContextualOpenFollowUp('Open it.'), isTrue);
    expect(policy.isContextualOpenFollowUp('افتحها'), isTrue);
    expect(policy.isContextualOpenFollowUp('Open my weight history'), isFalse);
  });

  test('confirmation-gated actions never auto-run', () {
    const sensitive = IntelligenceAction(
      id: 'delete-account',
      type: IntelligenceActionType.requestAccountDeletion,
      label: 'Delete account',
      requiresConfirmation: true,
      destructive: true,
    );
    expect(policy.isNavigation(sensitive), isFalse);
    expect(
      policy.isDirectNavigationRequest('Open account deletion', sensitive),
      isFalse,
    );
  });
}
