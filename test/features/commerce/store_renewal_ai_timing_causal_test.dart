import 'dart:async';

import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_route_glass_gate.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/providers/store_renewal_recheck_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/store_renewal_ui_fixture.dart';

void main() {
  testWidgets(
    'natural AI cutoff starts a bounded read burst without a quota invalidation',
    (tester) async {
      var refreshes = 0;
      final h = await RenewalUiHarness.open(
        tester,
        feature: PremiumGateFeature.aiCoach,
        refreshSubscription: () async {
          refreshes++;
        },
      );
      try {
        await h.mount(tester);
        final initialUsageReads = h.usageReads;
        expect(initialUsageReads, greaterThan(0));
        expect(refreshes, 0);
        h.usage = {
          'plan': 'free',
          'credits': {'total_remaining': 0},
        };

        // No provider read or manual invalidation may manufacture the wake.
        await h.tick(tester, const Duration(seconds: 5));
        await tester.pump(Duration.zero);
        await renewalFlush(tester);
        expect(
          refreshes,
          1,
          reason: 'The mounted AI route observes the exact cutoff timer.',
        );
        expect(h.usageReads, greaterThan(initialUsageReads));
        expect(h.container.read(aiCoachCreditAccessProvider).value, false);
        expect(
          h.container.read(verifiedSubscriptionAccessProvider).value?.plan,
          CommercePlan.free,
        );
        final observation = h.container.read(storeRenewalObservationProvider)!;
        final burst = h.container.read(storeRenewalRecheckProvider);
        expect(observation.pendingAt(h.now), isTrue);
        expect(burst.timedOut(observation), isFalse);
        expect(h.mounts, 1);
        expect(h.unmounts, 0);
        expect(find.text('Get AI Boost'), findsNothing);
        await tester.tap(
          find.byKey(const Key('protected-plan-write')),
          warnIfMissed: false,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
        await renewalFlush(tester);
        expect(h.attempts, 0);
        expect(h.writes, 0);
      } finally {
        await h.close(tester);
      }
    },
  );

  testWidgets(
    'a pre-cutoff quota request arriving late cannot unlock pending chat',
    (tester) async {
      final storeHold = Completer<void>();
      final usageHold = Completer<void>();
      final usageEntered = Completer<void>();
      var refreshes = 0;
      final h = await RenewalUiHarness.open(
        tester,
        feature: PremiumGateFeature.aiCoach,
        refreshSubscription: () {
          refreshes++;
          return storeHold.future;
        },
      );
      // Isolate response freshness from the separate natural-wake regression.
      // Keep the existing access timer alive on both baseline and candidate.
      final accessSubscription = h.container.listen(
        verifiedSubscriptionAccessProvider,
        (_, _) {},
        fireImmediately: true,
      );
      try {
        await h.mount(tester);
        await h.tick(tester, const Duration(seconds: 4));
        final requestBegan = h.now;
        final usageReads = h.usageReads;
        h.holdNextUsageRead = usageHold;
        h.nextUsageReadEntered = usageEntered;
        h.container.invalidate(aiCoachCreditAccessProvider);
        await renewalFlush(tester);
        expect(usageEntered.isCompleted, isTrue);
        expect(usageHold.isCompleted, isFalse);
        expect(h.usageReads, usageReads + 1);
        expect(requestBegan.isBefore(h.boundary), isTrue);
        h.usage = {
          'plan': 'free',
          'credits': {'total_remaining': 0},
        };

        await h.tick(tester, const Duration(seconds: 1));
        await tester.pump(Duration.zero);
        await renewalFlush(tester);
        expect(refreshes, 1);
        expect(h.usageReads, usageReads + 1);
        await h.tick(tester, const Duration(seconds: 1));
        usageHold.complete();
        await renewalFlush(tester);
        final quota = h.container.read(aiCoachAccessSnapshotStoreProvider);
        expect(h.container.read(aiCoachCreditAccessProvider).value, true);
        expect(quota.usageResponseFresh, isTrue);
        expect(quota.usageObservedAt!.isAfter(h.boundary), isTrue);
        expect(h.usageReads, usageReads + 1);
        expect(
          h.container.read(verifiedSubscriptionAccessProvider).value?.plan,
          CommercePlan.free,
        );
        expect(h.mounts, 1);
        expect(h.unmounts, 0);
        expect(find.text('Get AI Boost'), findsNothing);
        await tester.tap(
          find.byKey(const Key('protected-plan-write')),
          warnIfMissed: false,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
        await renewalFlush(tester);
        expect(
          h.attempts,
          0,
          reason: 'Arrival after expiry does not turn an old request fresh.',
        );
        expect(h.writes, 0);

        h.usage = {
          'plan': 'free',
          'credits': {'total_remaining': 80},
        };
        h.container.invalidate(aiCoachCreditAccessProvider);
        await renewalFlush(tester);
        expect(h.usageReads, usageReads + 2);
        expect(h.container.read(aiCoachCreditAccessProvider).value, true);
        expect(
          h.container.read(verifiedSubscriptionAccessProvider).value?.plan,
          CommercePlan.free,
        );
        await tester.tap(find.byKey(const Key('protected-plan-write')));
        await renewalFlush(tester);
        expect(h.attempts, 1);
        expect(h.writes, 1);
        expect(h.mounts, 1);
        expect(h.unmounts, 0);
      } finally {
        if (!usageHold.isCompleted) usageHold.complete();
        if (!storeHold.isCompleted) storeHold.complete();
        accessSubscription.close();
        await h.close(tester);
      }
    },
  );
}
