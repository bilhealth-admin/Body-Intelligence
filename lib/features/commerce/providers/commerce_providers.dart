import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/subscription_state.dart';
import '../repositories/entitlement_repository.dart';
import '../repositories/local_entitlement_repository.dart';
import '../repositories/server_entitlement_repository.dart';

final entitlementRepositoryProvider = Provider<EntitlementRepository>(
  (ref) => const LocalEntitlementRepository(),
);

final subscriptionStateProvider = Provider<SubscriptionState>(
  (ref) => ref.watch(entitlementRepositoryProvider).current(),
);

final verifiedSubscriptionStateProvider = FutureProvider<SubscriptionState>(
  (ref) async => const ServerEntitlementRepository().current(),
);
