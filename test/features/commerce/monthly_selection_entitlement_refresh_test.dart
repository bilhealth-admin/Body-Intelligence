import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_dynamic_store_offers.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:body_intelligence_log/features/commerce/services/store_account_visit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const monthly = BilStoreOfferMetadata(
  productId: 'bil_premium',
  kind: BilStoreProductKind.premiumSubscription,
  localizedTitle: 'Premium monthly',
  localizedPrice: 'EGP 129.99',
  currencyCode: 'EGP',
  priceMicros: 129990000,
  billingPeriodIso8601: 'P1M',
);
const annual = BilStoreOfferMetadata(
  productId: 'bil_premium_annual',
  kind: BilStoreProductKind.premiumSubscription,
  localizedTitle: 'Premium annual',
  localizedPrice: 'EGP 999.99',
  currencyCode: 'EGP',
  priceMicros: 999990000,
  billingPeriodIso8601: 'P1Y',
);

Finder tile(BilStoreOfferMetadata offer) =>
    find.byKey(ValueKey('store-offer-${offer.productId}'));
Finder checked(BilStoreOfferMetadata offer) => find.descendant(
  of: tile(offer),
  matching: find.byIcon(Icons.check_rounded),
);

SubscriptionState access(CommercePlan plan) => SubscriptionState(
  plan: plan,
  entitlements: FreePlan.entitlements,
  authority: EntitlementAuthority.verifiedServer,
  currentPeriodEndsAt: plan == CommercePlan.free
      ? null
      : DateTime.now().toUtc().add(const Duration(hours: 1)),
  isPurchasable: false,
  canRestorePurchases: true,
);

class Catalog implements BilStoreCatalogGateway {
  Catalog({this.offers = const [monthly, annual]});
  final List<BilStoreOfferMetadata> offers;
  final requested = <String>[];
  @override
  Future<List<BilStoreOfferMetadata>> loadOffers(Set<String> ids) async =>
      offers;
  @override
  Future<void> requestPurchase(BilStoreOfferMetadata offer) async {
    requested.add(offer.productId);
  }

  @override
  Future<void> restorePurchases() async {}
  @override
  Future<void> openManageSubscriptions() async {}
}

void main() {
  testWidgets(
    'monthly selection survives same iOS product identity refreshed metadata and active benefit',
    (tester) async {
      Widget surface(CommercePlan plan, List<BilStoreOfferMetadata> offers) =>
          MaterialApp(
            home: BilDynamicStoreOffers(
              locale: 'en',
              offers: offers,
              currentPlan: plan,
              onPurchaseRequested: (_) {},
              onRestore: () {},
              onManage: () {},
            ),
          );
      await tester.pumpWidget(
        surface(CommercePlan.free, const [monthly, annual]),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(tile(monthly));
      await tester.tap(tile(monthly));
      await tester.pumpAndSettle();
      expect(checked(monthly), findsOneWidget);
      await tester.pumpWidget(
        surface(CommercePlan.premium, const [annual, monthly]),
      );
      await tester.pumpAndSettle();
      expect(checked(monthly), findsOneWidget);
      expect(checked(annual), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'actual Plans keeps checked monthly across verified Free to paid parent provider refresh',
    (tester) async {
      var state = access(CommercePlan.free);
      final container = ProviderContainer(
        overrides: [
          verifiedSubscriptionStateProvider.overrideWith((_) async => state),
          verifiedEntitlementOwnerIdProvider.overrideWithValue(
            'selection-owner',
          ),
        ],
      );
      final catalog = Catalog();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: BilStorePlansPage(
              catalog: catalog,
              productIds: const {'bil_premium', 'bil_premium_annual'},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(tile(monthly));
      await tester.tap(tile(monthly));
      await tester.pumpAndSettle();
      expect(checked(monthly), findsOneWidget);
      final before = tester.state(find.byType(BilDynamicStoreOffers));
      state = access(CommercePlan.premium);
      container.invalidate(verifiedSubscriptionStateProvider);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('store-current-plan-status')),
        findsOneWidget,
      );
      expect(
        tester.state(find.byType(BilDynamicStoreOffers)),
        same(before),
        reason:
            'A verified account-status row must not remount the offer picker.',
      );
      expect(checked(monthly), findsOneWidget);
      expect(checked(annual), findsNothing);
      expect(catalog.requested, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    },
  );
  testWidgets(
    'remounted actual Plans prefers the current owned verified monthly product',
    (tester) async {
      final store = SelectionStore();
      final container = ProviderContainer(
        overrides: [
          verifiedEntitlementOwnerIdProvider.overrideWithValue(
            'selection-owner',
          ),
          verifiedSubscriptionStateProvider.overrideWith(
            (_) async => access(CommercePlan.premium),
          ),
        ],
      );
      final catalog = Catalog();
      Widget plans() => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: BilStorePlansPage(
            store: store,
            catalog: catalog,
            productIds: const {'bil_premium', 'bil_premium_annual'},
          ),
        ),
      );
      await tester.pumpWidget(plans());
      await tester.pumpAndSettle();
      await tester.ensureVisible(tile(monthly));
      await tester.tap(tile(monthly));
      await tester.pumpAndSettle();
      expect(checked(monthly), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(plans());
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('store-current-plan-status')),
        findsOneWidget,
      );
      expect(store.lastVerifiedProductId, monthly.productId);
      expect(store.entitlement!.grantsPaidAccess, isTrue);
      expect(checked(monthly), findsOneWidget);
      expect(checked(annual), findsNothing);
      expect(catalog.requested, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      store.dispose();
    },
  );
  for (final scenario in [
    'stale-owner',
    'inactive',
    'pending',
    'background-busy',
    'Free',
  ]) {
    testWidgets(
      'owned product hint refuses $scenario and keeps Annual default',
      (tester) async {
        final store = SelectionStore();
        if (scenario == 'stale-owner') {
          store.benefitOwnerId = 'other-owner';
        }
        if (scenario == 'inactive') {
          store.entitlement = VerifiedStoreEntitlement(
            plan: CommercePlan.premium,
            lifecycle: 'expired',
            verifiedAt: DateTime.now().toUtc(),
            renewsOrExpiresAt: DateTime.now().toUtc().subtract(
              const Duration(seconds: 1),
            ),
          );
        }
        if (scenario == 'pending') {
          store.state = VerifiedStoreState.purchasePending;
        }
        if (scenario == 'background-busy') {
          store.backgroundBusy = true;
        }
        final container = ProviderContainer(
          overrides: [
            verifiedEntitlementOwnerIdProvider.overrideWithValue(
              'selection-owner',
            ),
            verifiedSubscriptionStateProvider.overrideWith(
              (_) async => access(
                scenario == 'Free' ? CommercePlan.free : CommercePlan.premium,
              ),
            ),
          ],
        );
        final catalog = Catalog();
        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                home: BilStorePlansPage(
                  store: store,
                  catalog: catalog,
                  productIds: const {'bil_premium', 'bil_premium_annual'},
                ),
              ),
            ),
          );
          if (scenario == 'pending') {
            // An authentic pending checkout keeps animating; inspect it without
            // trying to settle the intentionally live activity indicator.
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
            expect(store.state, VerifiedStoreState.purchasePending);
            expect(
              tester
                  .widget<BilDynamicStoreOffers>(
                    find.byType(BilDynamicStoreOffers),
                  )
                  .purchaseInProgress,
              isTrue,
            );
          } else {
            await tester.pumpAndSettle();
          }
          expect(checked(annual), findsOneWidget);
          expect(checked(monthly), findsNothing);
          expect(catalog.requested, isEmpty);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
          store.dispose();
        }
      },
    );
  }

  testWidgets(
    'explicit Boost focus outranks owned current Monthly hint without purchase',
    (tester) async {
      final store = SelectionStore();
      final container = ProviderContainer(
        overrides: [
          verifiedEntitlementOwnerIdProvider.overrideWithValue(
            'selection-owner',
          ),
          verifiedSubscriptionStateProvider.overrideWith(
            (_) async => access(CommercePlan.premium),
          ),
        ],
      );
      final catalog = Catalog(offers: const [monthly, annual, boost]);
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: BilStorePlansPage(
                store: store,
                catalog: catalog,
                initialFocus: 'boost',
                productIds: const {
                  'bil_premium',
                  'bil_premium_annual',
                  'bil_ai_boost',
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(checked(boost), findsOneWidget);
        expect(checked(monthly), findsNothing);
        expect(catalog.requested, isEmpty);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        store.dispose();
      }
    },
  );

  for (final wrongKind in [false, true]) {
    testWidgets(
      'AI focus respects matching AI hint and refuses wrong-kind hint wrongKind=$wrongKind',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: BilDynamicStoreOffers(
              locale: 'en',
              offers: const [coachMonthly, coachAnnual, boost],
              initialFocus: 'ai-coach',
              initialSelectedProductId: wrongKind
                  ? monthly.productId
                  : coachAnnual.productId,
              currentPlan: CommercePlan.premiumAiCoach,
              onPurchaseRequested: (_) => fail('Hint must not buy'),
              onRestore: () {},
              onManage: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(checked(wrongKind ? coachMonthly : coachAnnual), findsOneWidget);
        expect(checked(wrongKind ? coachAnnual : coachMonthly), findsNothing);
        expect(checked(boost), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'new verified product hint never replaces an explicit user Monthly selection',
    (tester) async {
      Widget surface(String? hint) => MaterialApp(
        home: BilDynamicStoreOffers(
          locale: 'en',
          offers: const [monthly, annual],
          initialSelectedProductId: hint,
          currentPlan: CommercePlan.free,
          onPurchaseRequested: (_) => fail('Selection must not buy'),
          onRestore: () {},
          onManage: () {},
        ),
      );
      await tester.pumpWidget(surface(null));
      await tester.pumpAndSettle();
      await tester.ensureVisible(tile(monthly));
      await tester.tap(tile(monthly));
      await tester.pumpAndSettle();
      expect(checked(monthly), findsOneWidget);
      await tester.pumpWidget(surface(annual.productId));
      await tester.pumpAndSettle();
      expect(checked(monthly), findsOneWidget);
      expect(checked(annual), findsNothing);
    },
  );
}

class SelectionStore extends VerifiedStorePurchaseService {
  bool backgroundBusy = false;
  @override
  bool get busy => backgroundBusy || super.busy;
  SelectionStore() {
    state = VerifiedStoreState.verified;
    messageCode = 'subscription_verified';
    lastVerifiedProductId = monthly.productId;
    benefitOwnerId = 'selection-owner';
    benefitStoreSource = 'app_store';
    entitlement = VerifiedStoreEntitlement(
      plan: CommercePlan.premium,
      lifecycle: 'active',
      verifiedAt: DateTime.now().toUtc(),
      renewsOrExpiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      provider: 'apple',
    );
  }
  @override
  StoreAccountSnapshot captureCatalogVisit() =>
      const StoreAccountSnapshot('selection-owner', 0);
  @override
  bool isCurrentCatalogVisit(StoreAccountSnapshot visit) =>
      visit.ownerId == 'selection-owner' && visit.epoch == 0;
}

const boost = BilStoreOfferMetadata(
  productId: 'bil_ai_boost',
  kind: BilStoreProductKind.aiBoostConsumable,
  localizedTitle: 'Boost',
  localizedPrice: 'EGP 49.99',
  currencyCode: 'EGP',
  priceMicros: 49990000,
);
const coachMonthly = BilStoreOfferMetadata(
  productId: 'bil_premium_ai_coach',
  kind: BilStoreProductKind.premiumAiCoachSubscription,
  localizedTitle: 'AI Monthly',
  localizedPrice: 'USD 14.99',
  currencyCode: 'USD',
  priceMicros: 14990000,
  billingPeriodIso8601: 'P1M',
);
const coachAnnual = BilStoreOfferMetadata(
  productId: 'bil_premium_ai_coach_annual',
  kind: BilStoreProductKind.premiumAiCoachSubscription,
  localizedTitle: 'AI Annual',
  localizedPrice: 'USD 99.99',
  currencyCode: 'USD',
  priceMicros: 99990000,
  billingPeriodIso8601: 'P1Y',
);
