import '../domain/free_plan.dart';
import '../domain/subscription_state.dart';
import 'entitlement_repository.dart';

/// Safe default used until a server-verified commerce adapter is activated.
final class LocalEntitlementRepository implements EntitlementRepository {
  const LocalEntitlementRepository();

  @override
  SubscriptionState current() => FreePlan.createState();
}
