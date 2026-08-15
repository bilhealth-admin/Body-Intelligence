import '../../../app/analytics/bil_launch_event.dart';
import '../domain/store_offer_metadata.dart';

/// Coordinates user-triggered restore/status refresh without treating a store
/// callback as entitlement proof. [hasVerifiedEntitlement] must read trusted
/// server state after the gateway operation completes.
final class SubscriptionLifecycleCoordinator {
  const SubscriptionLifecycleCoordinator({
    required this.catalog,
    required this.analytics,
    required this.hasVerifiedEntitlement,
    required this.clock,
  });

  final BilStoreCatalogGateway catalog;
  final BilLaunchAnalyticsSink analytics;
  final Future<bool> Function() hasVerifiedEntitlement;
  final DateTime Function() clock;

  Future<bool> restoreAndRefresh() async {
    await catalog.restorePurchases();
    final verified = await hasVerifiedEntitlement();
    await analytics.record(
      BilLaunchEvent(
        name: BilLaunchEventName.subscriptionStatusRefreshed,
        occurredAt: clock().toUtc(),
        properties: {'verified': verified, 'source': 'restore'},
      ),
    );
    if (verified) {
      await analytics.record(
        BilLaunchEvent(
          name: BilLaunchEventName.purchasesRestored,
          occurredAt: clock().toUtc(),
        ),
      );
    }
    return verified;
  }
}
