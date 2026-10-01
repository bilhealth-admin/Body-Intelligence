import 'dart:ui';

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
    this.checking = false,
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
  final bool checking;

  @override
  Widget build(BuildContext context) {
    if (!locked && !checking) return child;
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
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
              child: Material(
                color: Theme.of(context).brightness == Brightness.light
                    ? const Color(0x2AFFFFFF)
                    : const Color(0x42000000),
                child: InkWell(
                  key: Key(
                    checking
                        ? 'dashboard-premium-access-checking'
                        : 'dashboard-premium-lock',
                  ),
                  onTap: checking ? null : onTap,
                  child: Center(
                    child: Semantics(
                      button: !checking,
                      label: title,
                      child: ExcludeSemantics(
                        child: checking
                            ? const SizedBox.square(
                                key: Key('dashboard-premium-checking-spinner'),
                                dimension: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : showLabel
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
        ),
      ],
    );
  }
}
