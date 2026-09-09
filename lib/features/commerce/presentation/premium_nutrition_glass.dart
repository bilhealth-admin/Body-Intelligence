import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/app_localizations.dart';
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
    this.showLabel = true,
    super.key,
  });

  final Widget child;
  final double borderRadius;
  final bool compact;
  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(verifiedSubscriptionStateProvider);
    if (subscription.isLoading || subscription.hasError) {
      return _PremiumNutritionStatusGlass(
        borderRadius: borderRadius,
        loading: subscription.isLoading,
        onRetry: subscription.hasError
            ? () => ref.invalidate(verifiedSubscriptionStateProvider)
            : null,
        child: child,
      );
    }
    final state = subscription.value;
    if (state?.authority != EntitlementAuthority.verifiedServer) {
      return _PremiumNutritionStatusGlass(
        borderRadius: borderRadius,
        loading: false,
        onRetry: () => ref.invalidate(verifiedSubscriptionStateProvider),
        child: child,
      );
    }
    final unlocked = state!.grants(CommerceEntitlement.advancedIntelligence);
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
                  child: showLabel
                      ? Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: light
                                  ? const Color(0xD9FFFFFF)
                                  : const Color(0xB8141820),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: const Color(0x99D79A1E),
                              ),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
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
                        )
                      : Semantics(
                          label: 'Premium',
                          button: true,
                          child: const SizedBox.expand(),
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

class _PremiumNutritionStatusGlass extends StatelessWidget {
  const _PremiumNutritionStatusGlass({
    required this.child,
    required this.borderRadius,
    required this.loading,
    this.onRetry,
  });

  final Widget child;
  final double borderRadius;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final label = context.strings.text(
      loading ? 'Checking subscription' : 'Subscription check unavailable',
    );
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
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  label: label,
                  child: Center(
                    child: loading
                        ? const SizedBox.square(
                            key: Key('premium-nutrition-checking'),
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : FilledButton.tonalIcon(
                            key: const Key(
                              'premium-nutrition-entitlement-retry',
                            ),
                            onPressed: onRetry,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(context.strings.text('Retry')),
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
