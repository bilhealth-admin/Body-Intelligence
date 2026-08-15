import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../domain/commerce_plan.dart';
import '../domain/entitlement_resolver.dart';
import '../domain/free_plan.dart';
import '../domain/subscription_lifecycle.dart';
import '../domain/subscription_provider.dart';
import '../domain/subscription_record.dart';
import '../domain/subscription_state.dart';

/// Reads only the server-owned subscription snapshot.
///
/// Network failure deliberately returns Free. It never deletes user data and
/// never treats local preferences, debug flags, or a paywall selection as an
/// entitlement.
final class ServerEntitlementRepository {
  const ServerEntitlementRepository({EntitlementResolver? resolver})
    : _resolver = resolver ?? const EntitlementResolver();

  final EntitlementResolver _resolver;

  Future<SubscriptionState> current() async {
    if (!AppEnvironment.cloudConfigured || !Supabase.instance.isInitialized) {
      return FreePlan.createState();
    }
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return FreePlan.createState();
      final rows = await client
          .from('bil_subscriptions')
          .select()
          .eq('owner_id', user.id)
          .limit(1);
      if (rows.isEmpty) return FreePlan.createState();
      final row = rows.first;
      final verifiedAt = DateTime.tryParse('${row['verified_at']}')?.toUtc();
      if (verifiedAt == null ||
          DateTime.now().toUtc().difference(verifiedAt) >
              const Duration(hours: 72)) {
        return FreePlan.createState();
      }
      final plan = CommercePlan.values.firstWhere(
        (candidate) => candidate.id == row['plan_id'],
        orElse: () => CommercePlan.free,
      );
      if (plan != CommercePlan.plus && plan != CommercePlan.pro) {
        return FreePlan.createState();
      }
      final lifecycle = _lifecycle('${row['lifecycle']}');
      final provider = row['provider'] == 'apple'
          ? SubscriptionProvider.apple
          : row['provider'] == 'google'
          ? SubscriptionProvider.google
          : null;
      if (provider == null) return FreePlan.createState();
      return _resolver.resolve(
        record: SubscriptionRecord(
          plan: plan,
          lifecycle: lifecycle,
          authorityVerified: true,
          provider: provider,
          startedAt: DateTime.tryParse('${row['started_at']}')?.toUtc(),
          currentPeriodEndsAt: DateTime.tryParse(
            '${row['expires_at']}',
          )?.toUtc(),
          gracePeriodEndsAt: DateTime.tryParse(
            '${row['grace_period_ends_at']}',
          )?.toUtc(),
        ),
        now: DateTime.now().toUtc(),
      );
    } on Object {
      return FreePlan.createState();
    }
  }

  SubscriptionLifecycle _lifecycle(String value) => switch (value) {
    'pending' => SubscriptionLifecycle.pending,
    'trial' => SubscriptionLifecycle.trial,
    'active' => SubscriptionLifecycle.active,
    'grace_period' => SubscriptionLifecycle.gracePeriod,
    'billing_retry' => SubscriptionLifecycle.billingRetry,
    'account_hold' => SubscriptionLifecycle.accountHold,
    'paused' => SubscriptionLifecycle.paused,
    'suspended' => SubscriptionLifecycle.suspended,
    'deferred' => SubscriptionLifecycle.deferred,
    'cancelled' => SubscriptionLifecycle.cancelled,
    'expired' => SubscriptionLifecycle.expired,
    'refunded' => SubscriptionLifecycle.refunded,
    'revoked' => SubscriptionLifecycle.revoked,
    _ => SubscriptionLifecycle.inactive,
  };
}
