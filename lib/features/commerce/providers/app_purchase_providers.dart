import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../intelligence_center/services/ai_boost_purchase_service.dart';
import '../services/verified_store_purchase_service.dart';
import 'commerce_providers.dart';
import 'verified_purchase_handoff.dart';
import '../domain/entitlement_resolver.dart';
import '../domain/subscription_record.dart';
import '../domain/subscription_lifecycle.dart';
import '../domain/subscription_provider.dart';
import '../domain/free_plan.dart';
import '../domain/subscription_state.dart';
import '../domain/commerce_plan.dart';

final appSubscriptionPurchaseFactoryProvider =
    Provider<VerifiedStorePurchaseService Function()>(
      (_) =>
          () => VerifiedStorePurchaseService(handlesBoost: false),
    );
final appBoostPurchaseFactoryProvider =
    Provider<AiBoostPurchaseService Function()>(
      (_) =>
          () => AiBoostPurchaseService(),
    );

/// Services belong to the authenticated app session, not a purchase route.
/// Exclusive SKU lanes prevent Plans and Coach settings verifying one Boost
/// in parallel. Store callbacks survive either page being closed.
final appSubscriptionPurchaseProvider = Provider<VerifiedStorePurchaseService>((
  ref,
) {
  final owner = ref.watch(verifiedEntitlementOwnerIdProvider);
  final service = ref.watch(appSubscriptionPurchaseFactoryProvider)();
  var revision = service.verifiedBenefitRevision;
  void changed() {
    if (revision == service.verifiedBenefitRevision) return;
    revision = service.verifiedBenefitRevision;
    if (owner == null ||
        service.benefitOwnerId != owner ||
        ref.read(verifiedEntitlementOwnerIdProvider) != owner) {
      return;
    }
    final row = service.entitlement;
    final lifecycle = switch (row?.lifecycle) {
      'active' => SubscriptionLifecycle.active,
      'trial' => SubscriptionLifecycle.trial,
      'grace_period' => SubscriptionLifecycle.gracePeriod,
      'cancelled' => SubscriptionLifecycle.cancelled,
      _ => SubscriptionLifecycle.inactive,
    };
    final handoff = row?.grantsPaidAccess == true
        ? const EntitlementResolver().resolve(
            record: SubscriptionRecord(
              plan: row!.plan,
              lifecycle: lifecycle,
              authorityVerified: true,
              verifiedAt: row.verifiedAt,
              provider: row.provider == 'apple'
                  ? SubscriptionProvider.apple
                  : SubscriptionProvider.google,
              currentPeriodEndsAt: row.renewsOrExpiresAt,
              trialEndsAt: lifecycle == SubscriptionLifecycle.trial
                  ? row.renewsOrExpiresAt
                  : null,
              gracePeriodEndsAt: row.gracePeriodEndsAt,
            ),
            now: DateTime.now().toUtc(),
          )
        : service.verifiedInactiveAt != null
        ? SubscriptionState(
            plan: CommercePlan.free,
            entitlements: FreePlan.entitlements,
            authority: EntitlementAuthority.verifiedServer,
            lifecycle: SubscriptionLifecycle.inactive,
            provider: service.benefitStoreSource == 'google_play'
                ? SubscriptionProvider.google
                : SubscriptionProvider.apple,
            verifiedAt: service.verifiedInactiveAt,
            isPurchasable: false,
            canRestorePurchases: true,
          )
        : null;
    ref.read(verifiedPurchaseHandoffProvider.notifier).publish(handoff);
    _refreshBenefitReaders(ref, subscription: true);
  }

  service.addListener(changed);
  ref.onDispose(() {
    service.removeListener(changed);
    service.dispose();
  });
  return service;
});

final appBoostPurchaseProvider = Provider<AiBoostPurchaseService>((ref) {
  final owner = ref.watch(verifiedEntitlementOwnerIdProvider);
  final service = ref.watch(appBoostPurchaseFactoryProvider)();
  var revision = service.verifiedCreditsRevision;
  void changed() {
    if (revision == service.verifiedCreditsRevision) return;
    revision = service.verifiedCreditsRevision;
    if (owner == null ||
        ref.read(verifiedEntitlementOwnerIdProvider) != owner) {
      return;
    }
    _refreshBenefitReaders(ref);
  }

  service.addListener(changed);
  ref.onDispose(() {
    service.removeListener(changed);
    service.dispose();
  });
  return service;
});

void _refreshBenefitReaders(Ref ref, {bool subscription = false}) {
  if (subscription) ref.invalidate(verifiedSubscriptionStateProvider);
  ref.invalidate(aiCoachCreditAccessProvider);
  ref.invalidate(aiVisionCreditStateProvider);
  ref.read(aiCoachUsageRefreshProvider.notifier).requestAuthoritativeReload();
}
