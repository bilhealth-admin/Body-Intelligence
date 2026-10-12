import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/commerce_entitlement.dart';
import '../domain/subscription_state.dart';
import '../providers/commerce_providers.dart';
import 'premium_value_mask.dart';
import 'premium_label_badge.dart';

/// One optional upgrade action per public group, only after verified denial.
class PremiumNutritionGroupLabel extends ConsumerWidget {
  const PremiumNutritionGroupLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(verifiedSubscriptionAccessProvider);
    final state = access.asData?.value;
    if (access.isLoading ||
        access.hasError ||
        state?.authority != EntitlementAuthority.verifiedServer ||
        state!.grants(CommerceEntitlement.advancedIntelligence)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PremiumLabelBadge(onTap: () => context.push('/plans')),
    );
  }
}

/// A public group of named fields. Each field protects its own value, so the
/// badge is not repeated over every number and free field actions stay usable.
class PremiumNutritionFieldsGroup extends StatelessWidget {
  const PremiumNutritionFieldsGroup({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [const PremiumNutritionGroupLabel(), child],
  );
}

/// Protects a paid value/action region, never its public field/card heading.
/// Callers keep names, units, sources, warnings and free actions outside it.
class PremiumNutritionGlass extends ConsumerWidget {
  const PremiumNutritionGlass({
    required this.child,
    this.borderRadius = 16,
    this.compact = false,
    this.showLabel = true,
    super.key,
  });

  final Widget child;
  final double borderRadius;
  final bool compact;
  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(verifiedSubscriptionAccessProvider);
    final state = access.asData?.value;
    final verified = state?.authority == EntitlementAuthority.verifiedServer;
    final checking = access.isLoading;
    final unavailable = !checking && (access.hasError || !verified);
    final granted =
        verified && state!.grants(CommerceEntitlement.advancedIntelligence);
    return PremiumValueMask(
      locked: !checking && !unavailable && !granted,
      checking: checking,
      onRetry: unavailable
          ? () => ref.invalidate(verifiedSubscriptionStateProvider)
          : null,
      onUpgrade: () => context.push('/plans'),
      borderRadius: borderRadius,
      compact: compact,
      showLabel: showLabel,
      actionKey: Key(
        unavailable
            ? 'premium-nutrition-entitlement-retry'
            : 'premium-nutrition-glass',
      ),
      statusKey: Key(
        checking
            ? 'premium-nutrition-checking'
            : unavailable
            ? 'premium-nutrition-status-label'
            : 'premium-nutrition-value-mask',
      ),
      child: child,
    );
  }
}
