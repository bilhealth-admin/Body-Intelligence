import 'package:body_intelligence_log/app/analytics/bil_launch_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('global launch funnel event vocabulary is complete', () {
    expect(BilLaunchEventName.values.map((value) => value.name).toSet(), {
      'signupCompleted',
      'onboardingCompleted',
      'trialStarted',
      'subscriptionPurchaseStarted',
      'subscriptionPurchaseVerified',
      'subscriptionStatusRefreshed',
      'purchasesRestored',
      'aiBoostPurchaseVerified',
      'paywallImpression',
      'paywallConversion',
      'deepLinkOpened',
      'campaignAttributionCaptured',
      'retainedDay1',
      'retainedDay7',
      'retainedDay30',
    });
  });

  test('analytics boundary rejects health data and direct identity', () async {
    final safe = BilLaunchEvent(
      name: BilLaunchEventName.paywallImpression,
      occurredAt: DateTime.now().toUtc(),
      properties: const {'tier': 'premium_ai_coach', 'locale': 'ar'},
    );
    final unsafe = BilLaunchEvent(
      name: BilLaunchEventName.signupCompleted,
      occurredAt: DateTime.now().toUtc(),
      properties: const {'email': 'person@example.invalid'},
    );
    expect(safe.privacySafe, isTrue);
    expect(unsafe.privacySafe, isFalse);
    await expectLater(
      const DisabledBilLaunchAnalyticsSink().record(unsafe),
      throwsStateError,
    );
  });
}
