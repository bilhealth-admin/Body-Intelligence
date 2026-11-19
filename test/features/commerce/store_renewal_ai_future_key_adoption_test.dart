import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_route_glass_gate.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/providers/store_renewal_recheck_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/store_renewal_ui_fixture.dart';

void main() {
  testWidgets(
    'fresh independent credits survive same-State rebuild after future canonical key adoption',
    (tester) async {
      final h = await RenewalUiHarness.open(
        tester,
        feature: PremiumGateFeature.aiCoach,
      );
      try {
        await h.mount(tester);
        h.usage = {
          'plan': 'free',
          'credits': {'total_remaining': 0},
        };
        await h.tick(tester, const Duration(seconds: 5));
        await tester.pump(Duration.zero);
        await renewalFlush(tester);
        h.container.invalidate(aiCoachCreditAccessProvider);
        await renewalFlush(tester);
        final oldHint = h.container.read(storeRenewalObservationProvider)!;
        expect(oldHint.pendingAt(h.now), isTrue);
        expect(h.container.read(aiCoachCreditAccessProvider).value, false);

        final futureStart = h.now.add(const Duration(seconds: 30));
        h.row = h.period(end: futureStart.add(const Duration(minutes: 3)))
          ..['started_at'] = futureStart.toIso8601String()
          ..['revision'] = 2;
        h.container.invalidate(verifiedSubscriptionStateProvider);
        await renewalFlush(tester);
        final futureHint = h.container.read(storeRenewalObservationProvider)!;
        expect(futureHint.periodKey, isNot(oldHint.periodKey));
        expect(futureHint.periodStart, futureStart);
        expect(futureHint.pendingAt(h.now), isTrue);
        expect(
          h.container.read(verifiedSubscriptionAccessProvider).value?.plan,
          CommercePlan.free,
        );

        h.usage = {
          'plan': 'free',
          'credits': {
            'total_remaining': 80,
            'paid_remaining': 80,
            'included_remaining': 0,
          },
        };
        h.container.invalidate(aiCoachCreditAccessProvider);
        await renewalFlush(tester);
        final quota = h.container.read(aiCoachAccessSnapshotStoreProvider);
        expect(h.container.read(aiCoachCreditAccessProvider).value, true);
        expect(quota.usageResponseFresh, isTrue);
        expect(quota.verifiedUsagePlan, 'free');
        final reads = h.usageReads;
        final requestedAt = quota.usageRequestedAt;
        expect(requestedAt, isNotNull);
        expect(requestedAt!.isBefore(futureStart), isTrue);
        expect(h.mounts, 1);
        expect(h.unmounts, 0);

        // Stay before the burst's next2s read. Pump the SAME keyed gate State
        // with a later clock; neither a quota read nor a replacement child may
        // mask an unnecessarily re-armed freshness threshold.
        await h.tick(tester, const Duration(seconds: 1));
        await h.mount(tester);
        expect(h.now.isBefore(futureStart), isTrue);
        expect(h.usageReads, reads);
        expect(
          h.container.read(aiCoachAccessSnapshotStoreProvider),
          same(quota),
        );
        expect(quota.usageRequestedAt, requestedAt);
        expect(quota.usageResponseFresh, isTrue);
        expect(h.container.read(aiCoachCreditAccessProvider).value, true);
        expect(
          h.container.read(verifiedSubscriptionAccessProvider).value?.plan,
          CommercePlan.free,
          reason: 'Current credits grant no early subscription rights.',
        );
        expect(h.mounts, 1);
        expect(h.unmounts, 0);
        expect(find.text('Get AI Boost'), findsNothing);
        await tester.tap(
          find.byKey(const Key('protected-plan-write')),
          warnIfMissed: false,
        );
        await renewalFlush(tester);
        expect(
          h.attempts,
          1,
          reason:
              'A rebuild must preserve the already fresh independent quota proof.',
        );
        expect(h.writes, 1);
        expect(h.usageReads, reads);
        expect(tester.takeException(), isNull);
      } finally {
        await h.close(tester);
      }
    },
  );
}
