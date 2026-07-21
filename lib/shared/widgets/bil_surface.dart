import 'package:flutter/material.dart';

import '../../app/theme/bil_elevation.dart';
import '../../app/theme/bil_flagship_tokens.dart';
import '../../app/theme/bil_spacing.dart';

/// Reusable premium surface used across BIL.
///
/// Prefer this widget over manually creating decorated containers for cards,
/// panels, and glass surfaces.
class BilSurface extends StatelessWidget {
  const BilSurface({
    super.key,
    required this.child,
    this.padding = BilSpacing.card,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.shadows = BilElevation.card,
    this.glass = false,
  });

  const BilSurface.glass({
    super.key,
    required this.child,
    this.padding = BilSpacing.cardComfortable,
    this.margin,
  }) : backgroundColor = null,
       borderColor = null,
       borderRadius = null,
       shadows = BilElevation.floating,
       glass = true;

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final List<BoxShadow> shadows;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final resolvedBackground =
        backgroundColor ??
        (glass
            ? Colors.white.withValues(alpha: dark ? .07 : .74)
            : scheme.surface);

    final resolvedBorder =
        borderColor ??
        (glass
            ? Colors.white.withValues(alpha: dark ? .12 : .58)
            : scheme.outlineVariant.withValues(alpha: .35));

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: resolvedBackground,
        borderRadius:
            borderRadius ?? BorderRadius.circular(BilFlagshipTokens.radiusLg),
        border: Border.all(color: resolvedBorder),
        boxShadow: shadows,
      ),
      child: child,
    );
  }
}
