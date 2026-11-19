import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_route_glass_gate.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/providers/store_renewal_recheck_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/store_renewal_ui_fixture.dart';

void main() {
  testWidgets(
    'fresh Free-plan credits remain usable before a future store period starts',
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
        expect(h.container.read(aiCoachCreditAccessProvider).value, false);
        final futureStart = h.now.add(const Duration(seconds: 30));
        h.row = h.period(end: futureStart.add(const Duration(minutes: 3)))
          ..['started_at'] = futureStart.toIso8601String()
          ..['revision'] = 2;
        h.container.invalidate(verifiedSubscriptionStateProvider);
        await renewalFlush(tester);
        expect(
          h.container.read(verifiedSubscriptionAccessProvider).value?.plan,
          CommercePlan.free,
          reason: 'No subscription rights may begin early across this gap.',
        );
        expect(
          h.container.read(storeRenewalObservationProvider)?.periodStart,
          futureStart,
        );
        final before = h.usageReads;
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
        expect(h.usageReads, greaterThan(before));
        expect(h.container.read(aiCoachCreditAccessProvider).value, true);
        final quota = h.container.read(aiCoachAccessSnapshotStoreProvider);
        expect(quota.usageResponseFresh, isTrue);
        expect(quota.verifiedUsagePlan, 'free');
        expect(quota.usageObservedAt!.isBefore(futureStart), isTrue);
        expect(h.mounts, 1);
        expect(h.unmounts, 0);
        expect(h.writes, 0);
        await tester.tap(
          find.byKey(const Key('protected-plan-write')),
          warnIfMissed: false,
        );
        await renewalFlush(tester);
        expect(
          h.attempts,
          1,
          reason:
              'Current reserved-aware quota is independent of a future subscription start.',
        );
        expect(h.writes, 1);
        expect(
          h.container.read(verifiedSubscriptionAccessProvider).value?.plan,
          CommercePlan.free,
        );
      } finally {
        await h.close(tester);
      }
    },
  );
}
