import '../domain/subscription_provider.dart';
import '../domain/subscription_record.dart';

/// Provider-neutral contract for future Apple, Google, and Web adapters.
///
/// Implementations belong to later packages and must verify provider evidence
/// before returning an authoritative record.
abstract interface class SubscriptionProviderContract {
  SubscriptionProvider get provider;

  Future<SubscriptionRecord?> loadCurrentSubscription();

  Future<void> restorePurchases();
}
