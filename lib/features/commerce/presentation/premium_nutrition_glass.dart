import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/commerce_entitlement.dart';
import '../domain/subscription_state.dart';
import '../providers/commerce_providers.dart';

/// Fail-closed glass for macro and detailed-nutrient values.
///
/// The protected widget remains rendered as a truthful preview, but it cannot
/// be read semantically or interacted with until the server verifies Premium.
class PremiumNutritionGlass extends ConsumerWidget {
  const PremiumNutritionGlass({
    required this.child,
    this.borderRadius = 16,
    this.compact = false,
    super.key,
  });

  final Widget child;
  final double borderRadius;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(verifiedSubscriptionStateProvider);
    final state = subscription.value;
    final unlocked =
        state?.authority == EntitlementAuthority.verifiedServer &&
        (state?.grants(CommerceEntitlement.advancedIntelligence) ?? false);
    if (unlocked) return child;

    final light = Theme.of(context).brightness == Brightness.light;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: IgnorePointer(child: child),
          ),
        ),
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: Material(
                color: light
                    ? const Color(0x24FFFFFF)
                    : const Color(0x29000000),
                child: InkWell(
                  key: const Key('premium-nutrition-glass'),
                  onTap: () => context.push('/plans'),
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: light
                            ? const Color(0xD9FFFFFF)
                            : const Color(0xB8141820),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: const Color(0x99D79A1E)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 9 : 14,
                          vertical: compact ? 4 : 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.workspace_premium_rounded,
                              color: const Color(0xFFD79A1E),
                              size: compact ? 16 : 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Premium',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: light
                                        ? const Color(0xFF231B0B)
                                        : Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: compact ? 12 : null,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
