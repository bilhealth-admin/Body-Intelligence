import 'package:flutter/material.dart';

import '../../commerce/presentation/premium_value_mask.dart';

/// A value-region guard. The actual card heading belongs outside this region.
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
    this.onRetry,
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
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => PremiumValueMask(
    locked: locked,
    checking: checking,
    onRetry: onRetry,
    onUpgrade: onTap,
    borderRadius: borderRadius,
    showLabel: showLabel,
    reserveSpace: false,
    actionKey: Key(
      checking ? 'dashboard-premium-access-checking' : 'dashboard-premium-lock',
    ),
    statusKey: Key(
      checking
          ? 'dashboard-premium-checking-spinner'
          : 'dashboard-premium-label',
    ),
    child: child,
  );
}
