import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/providers/store_renewal_recheck_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/store_renewal_ui_fixture.dart';

void main() {
  for (final provider in ['google', 'apple']) {
    testWidgets(
      '$provider confirmed Free row retires pending renewal display',
      (tester) async {
        final h = await RenewalUiHarness.open(tester, provider: provider);
        final listener = h.container.listen(
          storeRenewalPresentationPendingProvider,
          (_, _) {},
        );
        try {
          await h.mount(tester);
          await h.tick(tester, const Duration(seconds: 5));
          expect(
            h.container.read(storeRenewalPresentationPendingProvider),
            isTrue,
          );
          h.row['plan_id'] = 'free';
          h.row['lifecycle'] = 'inactive';
          h.row['revision'] = 2;
          h.container.invalidate(verifiedSubscriptionStateProvider);
          await renewalFlush(tester);
          expect(
            h.container.read(storeRenewalPresentationPendingProvider),
            isFalse,
          );
          expect(h.unmounts, 1);
          expect(find.text('Plans'), findsOneWidget);
          expect(h.writes, 0);
        } finally {
          listener.close();
          await h.close(tester);
        }
      },
    );
  }
}
