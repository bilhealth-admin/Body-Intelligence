import '../domain/subscription_state.dart';

/// Replaceable boundary for obtaining the current verified access snapshot.
abstract interface class EntitlementRepository {
  SubscriptionState current();
}
