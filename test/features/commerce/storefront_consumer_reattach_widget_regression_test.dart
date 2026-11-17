import 'dart:async';

import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_catalog_configuration.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

final class _ImmediateStorefront extends Fake implements InAppPurchase {
  int availabilityReads = 0;
  int countryReads = 0;
  int queries = 0;
  int buys = 0;

  @override
  Future<bool> isAvailable() async {
    availabilityReads++;
    return true;
  }

  @override
  Future<String> countryCode() async {
    countryReads++;
    return 'JOR';
  }

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async {
    queries++;
    return ProductDetailsResponse(
      productDetails: [
        for (final id in StoreCatalogConfiguration.productIds)
          ProductDetails(
            id: id,
            title: id,
            description: 'Synthetic native availability boundary',
            price: 'USD 9.99',
            rawPrice: 9.99,
            currencyCode: 'USD',
          ),
      ],
      notFoundIDs: const [],
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buys++;
    return false;
  }

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    buys++;
    return false;
  }
}

final class _ReadCounts {
  int builds = 0;
  int nestedReads = 0;
  bool budgetExceeded = false;
}

final class _TargetObserver extends ProviderObserver {
  int updates = 0;

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    if (identical(context.provider, storefrontTargetPlanProvider)) updates++;
  }
}

/// Models the actual Recipe page's descendant-Builder ref.watch placement.
/// There is deliberately no extra strong provider listener masking onCancel.
final class _NestedConsumer extends ConsumerWidget {
  const _NestedConsumer(this.counts);

  final _ReadCounts counts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    counts.builds++;
    // A faulty implementation must fail promptly rather than consume a CI
    // runner indefinitely. This cutoff belongs only to the synthetic probe;
    // the assertions below reject reaching it. Production is never modified.
    if (counts.builds > 12) {
      counts.budgetExceeded = true;
      return const Text('unbounded reattach loop');
    }
    return Builder(
      builder: (_) {
        counts.nestedReads++;
        final target = ref.watch(storefrontTargetPlanProvider);
        return Text(
          target.when(
            data: (plan) => plan?.name ?? 'unknown',
            error: (_, _) => 'unexpected error',
            loading: () => 'loading',
          ),
        );
      },
    );
  }
}

void main() {
  for (final configured in [false, true]) {
    testWidgets(
      'nested storefront consumer settles without producer churn when configured=$configured',
      (tester) async {
        final sdk = _ImmediateStorefront();
        final counts = _ReadCounts();
        final observer = _TargetObserver();
        try {
          await tester.pumpWidget(
            ProviderScope(
              observers: [observer],
              overrides: [
                // Only SDK/config/normal owner I/O are substituted. The target
                // provider and its actual lifecycle logic remain under test.
                storefrontPurchaseClientProvider.overrideWithValue(sdk),
                storefrontCatalogConfiguredProvider.overrideWithValue(
                  configured,
                ),
                verifiedEntitlementOwnerSeedProvider.overrideWithValue(
                  'owner-a',
                ),
                verifiedEntitlementOwnerProvider.overrideWith(
                  (_) => Stream<String?>.value('owner-a'),
                ),
              ],
              child: MaterialApp(home: _NestedConsumer(counts)),
            ),
          );
          await tester.pumpAndSettle(
            const Duration(milliseconds: 10),
            EnginePhase.sendSemanticsUpdate,
            const Duration(seconds: 2),
          );
          expect(counts.budgetExceeded, isFalse);
          expect(counts.builds, lessThanOrEqualTo(6));
          expect(counts.nestedReads, lessThanOrEqualTo(6));
          expect(observer.updates, lessThanOrEqualTo(4));
          expect(
            find.text(
              configured ? CommercePlan.premiumAiCoach.name : 'unknown',
            ),
            findsOneWidget,
          );
          final beforeIdle = counts.builds;
          for (var frame = 0; frame < 3; frame++) {
            await tester.pump(const Duration(milliseconds: 1));
          }
          expect(counts.builds, beforeIdle);
          var realTimerCompleted = false;
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            realTimerCompleted = true;
          });
          expect(realTimerCompleted, isTrue);
          expect(sdk.availabilityReads, configured ? 1 : 0);
          expect(sdk.countryReads, configured ? 2 : 0);
          expect(sdk.queries, configured ? 1 : 0);
          expect(sdk.buys, 0);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      },
    );
  }
}
