import 'package:body_intelligence_log/features/commerce/providers/store_renewal_recheck_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_route_glass_gate.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/store_renewal_ui_fixture.dart';

void main() {
  testWidgets(
    'known AI renewal with fresh Free zero retains chat without a Boost offer or Send',
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
        h.container.invalidate(aiCoachCreditAccessProvider);
        await renewalFlush(tester);
        expect(
          h.container.read(verifiedSubscriptionAccessProvider).value?.plan,
          CommercePlan.free,
        );
        expect(h.container.read(aiCoachCreditAccessProvider).value, false);
        expect(h.unmounts, 0);
        expect(find.text('Existing owned plan'), findsOneWidget);
        expect(find.text('Get AI Boost'), findsNothing);
        final attempts = h.attempts;
        await tester.tap(
          find.byKey(const Key('protected-plan-write')),
          warnIfMissed: false,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
        await renewalFlush(tester);
        expect(h.attempts, attempts);
        expect(h.writes, 0);
      } finally {
        await h.close(tester);
      }
    },
  );

  testWidgets('fresh current AI quota zero remains a genuine Boost gate', (
    tester,
  ) async {
    final h = await RenewalUiHarness.open(
      tester,
      feature: PremiumGateFeature.aiCoach,
    );
    try {
      await h.mount(tester);
      h.usage = {
        'plan': 'ai_coach',
        'credits': {'total_remaining': 0},
      };
      h.container.invalidate(aiCoachCreditAccessProvider);
      await renewalFlush(tester);
      expect(h.container.read(aiCoachCreditAccessProvider).value, false);
      expect(find.text('Get AI Boost'), findsOneWidget);
      expect(h.writes, 0);
    } finally {
      await h.close(tester);
    }
  });

  testWidgets(
    'renewal proof alone grants no Send; fresh positive quota restores the same chat',
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
        h.container.invalidate(aiCoachCreditAccessProvider);
        await renewalFlush(tester);
        await h.tick(tester, const Duration(seconds: 8));
        h.row = h.period(end: h.boundary.add(const Duration(minutes: 30)))
          ..['started_at'] = h.boundary.toIso8601String()
          ..['revision'] = 2;
        h.container.invalidate(verifiedSubscriptionStateProvider);
        await renewalFlush(tester);
        expect(
          h.container.read(verifiedSubscriptionAccessProvider).value?.plan,
          CommercePlan.premiumAiCoach,
        );
        expect(h.container.read(aiCoachCreditAccessProvider).value, false);
        expect(h.unmounts, 0);
        expect(find.text('Get AI Boost'), findsNothing);
        expect(h.writes, 0);
        h.usage = {
          'plan': 'ai_coach',
          'credits': {'total_remaining': 2466},
        };
        h.container.invalidate(aiCoachCreditAccessProvider);
        await renewalFlush(tester);
        expect(h.container.read(aiCoachCreditAccessProvider).value, true);
        expect(h.mounts, 1);
        expect(h.unmounts, 0);
        await tester.tap(find.byKey(const Key('protected-plan-write')));
        expect(h.writes, 1);
      } finally {
        await h.close(tester);
      }
    },
  );

  testWidgets(
    'positive paid Boost quota stays independent of a terminal AI subscription',
    (tester) async {
      final h = await RenewalUiHarness.open(
        tester,
        feature: PremiumGateFeature.aiCoach,
      );
      try {
        await h.mount(tester);
        h.row['lifecycle'] = 'expired';
        h.row['auto_renews'] = false;
        h.usage = {
          'plan': 'free',
          'credits': {'total_remaining': 80},
        };
        await h.tick(tester, const Duration(seconds: 5));
        h.container.invalidate(aiCoachCreditAccessProvider);
        await renewalFlush(tester);
        expect(
          h.container.read(verifiedSubscriptionAccessProvider).value?.plan,
          CommercePlan.free,
        );
        expect(h.container.read(aiCoachCreditAccessProvider).value, true);
        expect(find.text('Get AI Boost'), findsNothing);
        await tester.tap(find.byKey(const Key('protected-plan-write')));
        expect(h.writes, 1);
      } finally {
        await h.close(tester);
      }
    },
  );

  testWidgets('a delivered owner A B A visit cannot retain the old chat tree', (
    tester,
  ) async {
    final h = await RenewalUiHarness.open(
      tester,
      feature: PremiumGateFeature.aiCoach,
    );
    try {
      await h.mount(tester);
      final visit = h.container.read(verifiedEntitlementOwnerVisitProvider);
      await tester.runAsync(
        () => h.signIn('00000000-0000-4000-8000-000000009999'),
      );
      await renewalFlush(tester);
      await tester.runAsync(() => h.signIn(h.owner));
      await renewalFlush(tester);
      expect(
        h.container.read(verifiedEntitlementOwnerVisitProvider),
        greaterThanOrEqualTo(visit + 2),
      );
      expect(h.unmounts, greaterThanOrEqualTo(1));
      expect(h.writes, 0);
    } finally {
      await h.close(tester);
    }
  });
  testWidgets(
    'canonical renewal cannot erase the quota deadline; Retry heals only from fresh quota',
    (tester) async {
      final h = await RenewalUiHarness.open(
        tester,
        feature: PremiumGateFeature.aiCoach,
      );
      try {
        await h.mount(tester);
        expect(h.container.read(aiCoachCreditAccessProvider).value, true);
        h.usageOffline = true;
        await h.tick(tester, const Duration(seconds: 5));
        h.container.invalidate(aiCoachCreditAccessProvider);
        await renewalFlush(tester);
        expect(h.usageFailures, greaterThan(0));
        expect(h.container.read(aiCoachAccessSnapshotStoreProvider).usageResponseFresh, isFalse);
        await tester.pump(Duration.zero);
        await renewalFlush(tester);
        final oldObservation = h.container.read(storeRenewalObservationProvider)!;
        final oldKey = oldObservation.periodKey;
        final originatingBurst = h.container.read(storeRenewalRecheckProvider);
        expect(
          h.container.read(verifiedSubscriptionAccessProvider).value?.plan,
          CommercePlan.free,
        );
        await h.tick(tester, const Duration(seconds: 8));
        h.row = h.period(end: h.boundary.add(const Duration(minutes: 30)))
          ..['started_at'] = h.boundary.toIso8601String()
          ..['revision'] = 2;
        h.container.invalidate(verifiedSubscriptionStateProvider);
        await renewalFlush(tester);
        expect(
          h.container.read(verifiedSubscriptionAccessProvider).value?.plan,
          CommercePlan.premiumAiCoach,
        );
        expect(
          h.container.read(storeRenewalObservationProvider)!.periodKey,
          isNot(oldKey),
        );
        expect(
          h.usageFailures,
          greaterThan(0),
          reason: 'The actual usage HTTP path failed.',
        );
        expect(
          h.container.read(aiCoachCreditAccessProvider).value,
          true,
          reason:
              'The existing provider retains its prior positive, without fresh quota proof.',
        );
        expect(
          h.container
              .read(aiCoachAccessSnapshotStoreProvider)
              .usageResponseFresh,
          isFalse,
        );
        await h.tick(tester, const Duration(seconds: 17));
        expect(identical(h.container.read(storeRenewalRecheckProvider), originatingBurst), isTrue,
          reason: 'Canonical renewal keeps the original read scheduler alive.');
        expect(originatingBurst.timedOut(oldObservation), isTrue,
          reason: 'The original read burst actually reached its deadline.');
        expect(h.mounts, 1);
        expect(h.unmounts, 0);
        expect(find.text('Existing owned plan'), findsOneWidget);
        expect(find.text('Get AI Boost'), findsNothing);
        expect(
          find.text('Try again'),
          findsOneWidget,
          reason:
              'The original pending quota deadline survived the new canonical period key.',
        );
        final attempts = h.attempts;
        await tester.tap(
          find.byKey(const Key('protected-plan-write')),
          warnIfMissed: false,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
        await renewalFlush(tester);
        expect(h.attempts, attempts);
        expect(h.writes, 0);
        final storeRefreshes = h.refreshCalls,
            canonicalLoads = h.loads,
            usageReads = h.usageReads;
        h.usageOffline = false;
        await tester.tap(find.text('Try again'));
        await renewalFlush(tester);
        expect(h.usageReads, greaterThan(usageReads));
        expect(
          h.container
              .read(aiCoachAccessSnapshotStoreProvider)
              .usageResponseFresh,
          isTrue,
        );
        expect(h.container.read(aiCoachCreditAccessProvider).value, true);
        expect(
          h.refreshCalls,
          storeRefreshes,
          reason:
              'Current canonical proof does not requery the old store period.',
        );
        expect(
          h.loads,
          canonicalLoads,
          reason:
              'Explicit quota recovery does not refetch already current canonical proof.',
        );
        expect(find.text('Try again'), findsNothing);
        expect(h.mounts, 1);
        expect(h.unmounts, 0);
        await tester.tap(find.byKey(const Key('protected-plan-write')));
        expect(h.writes, 1);
      } finally {
        await h.close(tester);
      }
    },
  );
}
