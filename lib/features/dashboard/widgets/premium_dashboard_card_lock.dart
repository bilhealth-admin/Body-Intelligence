import 'package:flutter/material.dart';

import '../../commerce/presentation/premium_label_badge.dart';

/// A compact, truthful Premium marker for protected dashboard cards.
///
/// The real card stays visible behind a light scrim. The overlay only marks
/// the card as Premium; it never authorizes access, and the destination route
/// repeats the server-verified entitlement check.
class PremiumDashboardCardLock extends StatelessWidget {
  const PremiumDashboardCardLock({
    required this.locked,
    required this.title,
    required this.detail,
    required this.child,
    required this.onTap,
    this.borderRadius = 24,
    this.revealPreview = false,
    this.showLabel = true,
    super.key,
  });

  final bool locked;
  final String title;
  final String detail;
  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;
  final bool revealPreview;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: AbsorbPointer(child: child),
          ),
        ),
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Material(
              color: Theme.of(context).brightness == Brightness.light
                  ? const Color(0x1F0B0D10)
                  : const Color(0x42000000),
              child: InkWell(
                key: const Key('dashboard-premium-lock'),
                onTap: onTap,
                child: Center(
                  child: Semantics(
                    button: true,
                    label: title,
                    child: ExcludeSemantics(
                      child: showLabel
                          ? const PremiumLabelBadge(
                              key: Key('dashboard-premium-label'),
                            )
                          : const SizedBox.expand(),
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
