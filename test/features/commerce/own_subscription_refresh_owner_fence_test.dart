import 'dart:async';

import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/providers/store_renewal_recheck_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/store_renewal_ui_fixture.dart';

void main() {
  testWidgets(
    'own-refresh held integrity authorization retires on owner ABA before HTTP',
    (tester) async {
      final h = await RenewalUiHarness.open(tester);
      final held = Completer<Map<String, Object?>>();
      final entered = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          ownSubscriptionIntegrityProtectorProvider.overrideWithValue(({
            required action,
            required payload,
          }) {
            expect(action, 'store.refresh_subscription');
            expect(payload, const {'action': 'refresh_subscription'});
            entered.complete();
            return held.future;
          }),
        ],
      );
      final subscription = container.listen(
        ownSubscriptionRefreshProvider,
        (_, _) {},
      );
      try {
        await tester.pump(Duration.zero);
        await renewalFlush(tester);
        final visit = container.read(verifiedEntitlementOwnerVisitProvider);
        var retired = false;
        final result = container
            .read(ownSubscriptionRefreshProvider)()
            .then<void>(
              (_) {},
              onError: (Object _, StackTrace _) {
                retired = true;
              },
            );
        await tester.pump();
        expect(entered.isCompleted, isTrue);
        await tester.runAsync(
          () => h.signIn('00000000-0000-4000-8000-000000009999'),
        );
        await tester.pump(Duration.zero);
        await renewalFlush(tester);
        expect(
          container.read(verifiedEntitlementOwnerIdProvider),
          '00000000-0000-4000-8000-000000009999',
        );
        await tester.runAsync(() => h.signIn(h.owner));
        await tester.pump(Duration.zero);
        await renewalFlush(tester);
        expect(container.read(verifiedEntitlementOwnerIdProvider), h.owner);
        expect(
          container.read(verifiedEntitlementOwnerVisitProvider),
          greaterThanOrEqualTo(visit + 2),
        );
        held.complete({
          'action': 'refresh_subscription',
          '_integrity': {'grant_id': 'synthetic-grant'},
        });
        await tester.pump();
        await result;
        expect(retired, isTrue);
        expect(h.refreshCalls, 0);
      } finally {
        subscription.close();
        container.dispose();
        await h.close(tester);
      }
    },
  );
}
