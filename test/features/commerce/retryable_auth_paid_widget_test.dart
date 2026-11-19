import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/paid_plan_catalog.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_nutrition_glass.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/retryable_auth_fixture.dart';

SubscriptionState _paid(DateTime until) => SubscriptionState(
  plan: CommercePlan.premium,
  entitlements: PaidPlanCatalog.composedEntitlementsFor(CommercePlan.premium),
  authority: EntitlementAuthority.verifiedServer,
  provider: SubscriptionProvider.apple,
  lifecycle: SubscriptionLifecycle.active,
  startedAt: DateTime.utc(2026, 11, 18),
  currentPeriodEndsAt: until,
  isPurchasable: false,
  canRestorePurchases: true,
);

// Match the exact fixture label as one complete merged semantics line. Flutter
// may combine it with its Text child; hidden values still have no such node.
Finder get _paidValueSemantics =>
    find.bySemanticsLabel(RegExp(r'(^|\n)offline paid value(\n|$)'));

void main() {
  for (final networkOnly in [true, false]) {
    testWidgets(
      'actual paid values retain only typed same-owner transport error=$networkOnly',
      (tester) async {
        final auth = RetryableAuthFixture();
        final now = DateTime.utc(2026, 11, 19, 3);
        final until = now.add(const Duration(minutes: 2));
        var checkedAt = now;
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            verifiedEntitlementAuthClientProvider.overrideWithValue(auth),
            verifiedEntitlementClockProvider.overrideWithValue(() => checkedAt),
            verifiedEntitlementLoaderProvider.overrideWithValue(
              () async => _paid(until),
            ),
          ],
        );
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: Scaffold(
                  body: PremiumNutritionGlass(
                    showLabel: false,
                    child: Semantics(
                      label: 'offline paid value',
                      child: const Text('Protein 24 g'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            container.read(verifiedEntitlementOwnerProvider).requireValue,
            'offline-owner-a',
          );
          expect(
            container
                .read(verifiedSubscriptionAccessProvider)
                .requireValue
                .plan,
            CommercePlan.premium,
          );
          expect(
            container
                .read(verifiedSubscriptionAccessProvider)
                .requireValue
                .authority,
            EntitlementAuthority.verifiedServer,
          );
          expect(_paidValueSemantics, findsOneWidget);
          final originalVisit = container.read(
            verifiedEntitlementOwnerVisitProvider,
          );
          auth.fail(
            networkOnly
                ? AuthRetryableFetchException(statusCode: '503')
                : StateError('unexpected auth failure'),
          );
          await tester.pumpAndSettle();
          expect(
            _paidValueSemantics,
            networkOnly ? findsOneWidget : findsNothing,
          );
          expect(
            container.read(verifiedEntitlementOwnerProvider).hasError,
            !networkOnly,
          );
          if (networkOnly) {
            expect(
              container.read(verifiedEntitlementOwnerVisitProvider),
              originalVisit,
            );
            checkedAt = until;
            container.invalidate(verifiedSubscriptionAccessProvider);
            await tester.pumpAndSettle();
            expect(
              _paidValueSemantics,
              findsNothing,
              reason:
                  'No network error may extend the verified billing boundary.',
            );
            expect(
              container.read(verifiedSubscriptionAccessProvider).value?.plan,
              CommercePlan.free,
            );
          }
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
          final closed = auth.changes.close();
          await tester.pump();
          await tester.runAsync(() async => closed);
          semantics.dispose();
        }
      },
    );
  }

  testWidgets('real signed-out and owner A B A retire paid authority', (
    tester,
  ) async {
    final auth = RetryableAuthFixture();
    var calls = 0;
    final now = DateTime.utc(2026, 11, 19, 3);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        verifiedEntitlementAuthClientProvider.overrideWithValue(auth),
        verifiedEntitlementClockProvider.overrideWithValue(() => now),
        verifiedEntitlementLoaderProvider.overrideWithValue(() async {
          calls++;
          return calls == 1
              ? _paid(now.add(const Duration(days: 1)))
              : FreePlan.createState();
        }),
      ],
    );
    final listener = container.listen(
      verifiedSubscriptionAccessProvider,
      (_, _) {},
    );
    // Own the real visit observer before delivering any broadcast transition.
    final visitListener = container.listen(
      verifiedEntitlementOwnerVisitProvider,
      (_, _) {},
    );
    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: PremiumNutritionGlass(
                showLabel: false,
                child: Text('Owner-bound paid value'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(auth.changes.hasListener, isTrue);
      expect(
        container.read(verifiedEntitlementOwnerProvider).requireValue,
        'offline-owner-a',
      );
      expect(container.read(verifiedEntitlementOwnerVisitProvider), 0);
      expect(
        container.read(verifiedSubscriptionAccessProvider).value?.plan,
        CommercePlan.premium,
      );
      auth.owner('offline-owner-b');
      await tester.pumpAndSettle();
      expect(
        container.read(verifiedEntitlementOwnerProvider).requireValue,
        'offline-owner-b',
      );
      expect(container.read(verifiedEntitlementOwnerVisitProvider), 1);
      auth.owner('offline-owner-a');
      await tester.pumpAndSettle();
      expect(
        container.read(verifiedEntitlementOwnerProvider).requireValue,
        'offline-owner-a',
      );
      expect(container.read(verifiedEntitlementOwnerVisitProvider), 2);
      expect(
        container.read(verifiedSubscriptionAccessProvider).value?.plan,
        CommercePlan.free,
      );
      auth.owner(null);
      await tester.pumpAndSettle();
      expect(
        container.read(verifiedEntitlementOwnerProvider).requireValue,
        isNull,
      );
      expect(
        container.read(verifiedSubscriptionAccessProvider).value?.plan,
        isNot(CommercePlan.premium),
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      listener.close();
      visitListener.close();
      container.dispose();
      final closed = auth.changes.close();
      await tester.pump();
      await tester.runAsync(() async => closed);
    }
  });
}
