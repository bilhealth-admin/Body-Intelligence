import 'package:body_intelligence_log/app/services/external_capabilities.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/repositories/entitlement_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _VerifiedRepository implements EntitlementRepository {
  @override
  SubscriptionState current() => SubscriptionState(
    plan: CommercePlan.plus,
    entitlements: const <CommerceEntitlement>{
      CommerceEntitlement.localTracking,
      CommerceEntitlement.advancedIntelligence,
    },
    authority: EntitlementAuthority.verifiedServer,
    isPurchasable: true,
    canRestorePurchases: true,
  );
}

void main() {
  test('default provider resolves to the safe local Free plan', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(subscriptionStateProvider);

    expect(state.plan, CommercePlan.free);
    expect(state.authority, EntitlementAuthority.localDefault);
    expect(state.isPurchasable, isFalse);
  });

  test('repository boundary is replaceable without changing consumers', () {
    final container = ProviderContainer(
      overrides: [
        entitlementRepositoryProvider.overrideWithValue(_VerifiedRepository()),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(subscriptionStateProvider);

    expect(state.plan, CommercePlan.plus);
    expect(state.authority, EntitlementAuthority.verifiedServer);
    expect(state.grants(CommerceEntitlement.advancedIntelligence), isTrue);
  });

  test('commerce activation remains unavailable without verified adapter', () {
    final status = ExternalCapabilities.status(ExternalCapability.commerce);

    expect(status.available, isFalse);
    expect(status.reason, isNotEmpty);
  });

  test('local authority cannot advertise purchase or restore', () {
    expect(
      () => SubscriptionState(
        plan: CommercePlan.free,
        entitlements: const <CommerceEntitlement>{},
        authority: EntitlementAuthority.localDefault,
        isPurchasable: true,
        canRestorePurchases: false,
      ),
      throwsArgumentError,
    );
  });
}
