import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/providers/store_renewal_recheck_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/store_renewal_ui_fixture.dart';

void main() {
  for (final provider in ['google', 'apple']) {
    testWidgets(
      '$provider signed renewal eight seconds late restores the same child only after proof',
      (tester) async {
        final h = await RenewalUiHarness.open(tester, provider: provider);
        try {
          await h.mount(tester);
          await h.tick(tester, const Duration(seconds: 5));
          expect(
            h.container.read(verifiedSubscriptionAccessProvider).value?.plan,
            CommercePlan.free,
          );
          await h.tick(tester, const Duration(seconds: 8));
          h.row =
              h.period(
                  provider: provider,
                  end: h.boundary.add(const Duration(minutes: 3)),
                )
                ..['started_at'] = h.boundary.toIso8601String()
                ..['revision'] = 2;
          h.container.invalidate(verifiedSubscriptionStateProvider);
          await renewalFlush(tester);
          expect(
            h.container.read(verifiedSubscriptionAccessProvider).value?.plan,
            CommercePlan.premium,
          );
          expect(h.mounts, 1);
          expect(h.unmounts, 0);
          expect(h.writes, 0);
          await tester.tap(find.byKey(const Key('protected-plan-write')));
          expect(h.writes, 1);
        } finally {
          await h.close(tester);
        }
      },
    );
  }
  testWidgets(
    'Apple unresolved old expiry remains read-only beyond eighty seconds without a repurchase CTA',
    (tester) async {
      final h = await RenewalUiHarness.open(tester, provider: 'apple');
      try {
        await h.mount(tester);
        await h.tick(tester, const Duration(seconds: 5));
        for (final duration in [2, 3, 5, 10, 5, 30, 30]) {
          await h.tick(tester, Duration(seconds: duration));
        }
        expect(
          h.container.read(verifiedSubscriptionAccessProvider).value?.plan,
          CommercePlan.free,
        );
        expect(h.unmounts, 0);
        expect(find.text('Plans'), findsNothing);
        expect(find.text('Try again'), findsOneWidget);
        expect(h.writes, 0);
        expect(
          h.loads,
          lessThanOrEqualTo(10),
          reason: 'Bounded burst plus the unchanged 30-second observed reads.',
        );
      } finally {
        await h.close(tester);
      }
    },
  );
  testWidgets(
    'Apple future period with a gap grants nothing until its own verified start',
    (tester) async {
      final h = await RenewalUiHarness.open(tester, provider: 'apple');
      try {
        await h.mount(tester);
        await h.tick(tester, const Duration(seconds: 5));
        h.row =
            h.period(
                provider: 'apple',
                end: h.boundary.add(const Duration(minutes: 3)),
              )
              ..['started_at'] = h.boundary
                  .add(const Duration(seconds: 13))
                  .toIso8601String()
              ..['revision'] = 2;
        h.container.invalidate(verifiedSubscriptionStateProvider);
        await renewalFlush(tester);
        expect(
          h.container.read(verifiedSubscriptionAccessProvider).value?.plan,
          CommercePlan.free,
        );
        await h.tick(tester, const Duration(seconds: 12));
        expect(
          h.container.read(verifiedSubscriptionAccessProvider).value?.plan,
          CommercePlan.free,
        );
        expect(h.writes, 0);
        expect(h.unmounts, 0);
        await h.tick(tester, const Duration(seconds: 1));
        expect(
          h.container.read(verifiedSubscriptionAccessProvider).value?.plan,
          CommercePlan.premium,
        );
        expect(h.mounts, 1);
        expect(h.unmounts, 0);
      } finally {
        await h.close(tester);
      }
    },
  );
  testWidgets(
    'public membership pending signal never changes exact access and clears on terminal proof',
    (tester) async {
      final h = await RenewalUiHarness.open(tester, provider: 'apple');
      final listener = h.container.listen(
        storeRenewalPresentationPendingProvider,
        (_, _) {},
      );
      try {
        await h.mount(tester);
        expect(
          h.container.read(storeRenewalPresentationPendingProvider),
          isFalse,
        );
        await h.tick(tester, const Duration(seconds: 5));
        expect(
          h.container.read(storeRenewalPresentationPendingProvider),
          isTrue,
        );
        expect(
          h.container.read(verifiedSubscriptionAccessProvider).value?.plan,
          CommercePlan.free,
        );
        h.row['lifecycle'] = 'expired';
        h.row['auto_renews'] = false;
        h.container.invalidate(verifiedSubscriptionStateProvider);
        await renewalFlush(tester);
        expect(
          h.container.read(storeRenewalPresentationPendingProvider),
          isFalse,
        );
        expect(find.text('Plans'), findsOneWidget);
        expect(h.writes, 0);
      } finally {
        listener.close();
        await h.close(tester);
      }
    },
  );
}
