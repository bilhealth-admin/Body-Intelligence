import 'subscription_state.dart';

/// Follow-up work requested by deterministic local recovery.
enum SubscriptionRecoveryAction {
  none,
  refreshFromProvider,
  restoreFromProvider,
  discardInvalidCache,
}

/// Local recovery result consumed by orchestration and UI boundaries.
final class SubscriptionRecoveryDecision {
  const SubscriptionRecoveryDecision({
    required this.state,
    required this.action,
    required this.usedCachedRecord,
  });

  final SubscriptionState state;
  final SubscriptionRecoveryAction action;
  final bool usedCachedRecord;
}
