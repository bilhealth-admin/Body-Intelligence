import 'package:body_intelligence_log/features/commerce/domain/store_benefit_delivery.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_catalog_configuration.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/providers/verified_purchase_handoff.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final at = DateTime.now().toUtc();
  Map<String, Object?> receipt() => {
    'version': 2,
    'owner_id': 'A',
    'store': 'app_store',
    'environment': 'sandbox',
    'event_key': List.filled(64, 'a').join(),
    'product_id': StoreCatalogConfiguration.aiBoost,
    'verified_at': at.toIso8601String(),
    'kind': 'boost',
    'active': true,
    'quantity': 730,
    'credited_now': true,
    'finish_pending': false,
  };
  StoreBenefitDelivery? parse(Object? value) => StoreBenefitDelivery.parse(
    value,
    ownerId: 'A',
    productId: StoreCatalogConfiguration.aiBoost,
    source: 'app_store',
  );
  test(
    'trusted transport quantity survives and missing or mismatched proof is rejected',
    () {
      expect(parse(receipt())!.quantity, 730);
      for (final changes in [
        {'owner_id': 'B'},
        {'environment': 'unknown'},
        {'product_id': 'bad'},
        {'event_key': 'bad'},
        {'quantity': 0},
        {'quantity': 730.5},
        {'kind': 'subscription'},
        {'verified_at': 'bad'},
      ]) {
        expect(parse({...receipt(), ...changes}), isNull);
      }
      expect(parse({'verified': true}), isNull);
      final refund = parse({...receipt(), 'active': false, 'quantity': 0});
      expect(refund!.active, isFalse);
    },
  );
  SubscriptionState state(CommercePlan plan, DateTime timestamp) =>
      SubscriptionState(
        plan: plan,
        entitlements: const <CommerceEntitlement>{},
        authority: EntitlementAuthority.verifiedServer,
        isPurchasable: false,
        canRestorePurchases: true,
        lifecycle: SubscriptionLifecycle.active,
        currentPeriodEndsAt: at.add(const Duration(days: 30)),
        verifiedAt: timestamp,
      );
  test(
    'canonical handoff wins an older Free read, but a newer revocation wins',
    () {
      final paid = state(CommercePlan.premium, at);
      final oldFree = state(
        CommercePlan.free,
        at.subtract(const Duration(seconds: 1)),
      );
      expect(
        purchaseHandoffView(AsyncData(oldFree), paid, at).value,
        same(paid),
      );
      expect(
        purchaseHandoffView(const AsyncLoading(), paid, at).value,
        same(paid),
      );
      final revoked = state(
        CommercePlan.free,
        at.add(const Duration(seconds: 1)),
      );
      expect(
        purchaseHandoffView(AsyncData(revoked), paid, at).value,
        same(revoked),
      );
      expect(
        purchaseHandoffView(
          AsyncData(oldFree),
          paid,
          at.add(const Duration(days: 31)),
        ).value,
        same(oldFree),
      );
    },
  );
  test(
    'inactive handoff excludes older store access and preserves independent grants',
    () {
      final prior = SubscriptionState(
        plan: CommercePlan.premium,
        entitlements: const <CommerceEntitlement>{},
        authority: EntitlementAuthority.verifiedServer,
        isPurchasable: false,
        canRestorePurchases: true,
        provider: SubscriptionProvider.apple,
        lifecycle: SubscriptionLifecycle.active,
        currentPeriodEndsAt: at.add(const Duration(days: 30)),
        verifiedAt: at.subtract(const Duration(seconds: 1)),
      );
      final revoked = state(CommercePlan.free, at);
      expect(
        purchaseHandoffView(AsyncData(prior), revoked, at).value,
        same(revoked),
      );
      final later = state(
        CommercePlan.premium,
        at.add(const Duration(seconds: 1)),
      );
      expect(
        purchaseHandoffView(AsyncData(later), revoked, at).value,
        same(later),
      );
      expect(
        purchaseHandoffView(const AsyncLoading(), revoked, at).isLoading,
        isTrue,
      );
      expect(
        purchaseHandoffView(
          AsyncError(StateError('offline'), StackTrace.current),
          revoked,
          at,
        ).hasError,
        isTrue,
      );
      final grant = SubscriptionState(
        plan: CommercePlan.premium,
        entitlements: const <CommerceEntitlement>{},
        authority: EntitlementAuthority.verifiedServer,
        isPurchasable: false,
        canRestorePurchases: false,
        currentPeriodEndsAt: at.add(const Duration(days: 1)),
      );
      expect(
        purchaseHandoffView(AsyncData(grant), revoked, at).value,
        same(grant),
      );
    },
  );
  test(
    'handoff is retired during A to B to A, without changing balances or roles',
    () {
      final owner = NotifierProvider<_OwnerVisit, String?>(_OwnerVisit.new);
      final container = ProviderContainer(
        overrides: [
          verifiedEntitlementOwnerIdProvider.overrideWith(
            (ref) => ref.watch(owner),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        verifiedPurchaseHandoffProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      container
          .read(verifiedPurchaseHandoffProvider.notifier)
          .publish(state(CommercePlan.premium, at));
      expect(container.read(verifiedPurchaseHandoffProvider), isNotNull);
      container.read(owner.notifier).change('B');
      expect(container.read(verifiedPurchaseHandoffProvider), isNull);
      container.read(owner.notifier).change('A');
      expect(container.read(verifiedPurchaseHandoffProvider), isNull);
    },
  );
}

class _OwnerVisit extends Notifier<String?> {
  @override
  String? build() => 'A';
  void change(String? owner) => state = owner;
}
