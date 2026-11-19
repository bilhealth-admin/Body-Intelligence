import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/store_renewal_ui_fixture.dart';

// Baseline-compatible public APIs and real persisted row decoding. No new
// observation/provider imports; the old code fails on child unmount, not load.
void main() {
  testWidgets(
    'Apple cutoff retains owned content while exact access becomes Free',
    (tester) async {
      final h = await RenewalUiHarness.open(tester, provider: 'apple');
      try {
        await h.mount(tester);
        await h.tick(tester, const Duration(seconds: 5));
        expect(
          h.container.read(verifiedSubscriptionAccessProvider).value?.plan,
          CommercePlan.free,
        );
        expect(
          h.unmounts,
          0,
          reason: 'Presentation does not extend the old signed period.',
        );
        expect(find.text('Existing owned plan'), findsOneWidget);
        expect(find.text('Plans'), findsNothing);
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

  testWidgets(
    'Apple terminal nonrenewing expiry still removes content and shows Plans',
    (tester) async {
      final h = await RenewalUiHarness.open(tester, provider: 'apple');
      try {
        await h.mount(tester);
        h.row['lifecycle'] = 'expired';
        h.row['auto_renews'] = false;
        await h.tick(tester, const Duration(seconds: 5));
        expect(
          h.container.read(verifiedSubscriptionAccessProvider).value?.plan,
          CommercePlan.free,
        );
        expect(h.unmounts, 1);
        expect(find.text('Plans'), findsOneWidget);
        expect(h.writes, 0);
      } finally {
        await h.close(tester);
      }
    },
  );
}
