import 'package:flutter/material.dart';

import '../../app/theme/premium_design_tokens.dart';
import '../../app/theme/premium_motion_tokens.dart';

class PremiumSurface extends StatelessWidget {
  const PremiumSurface({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.semanticContainer = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool semanticContainer;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding ?? PremiumDesignTokens.cardPadding,
      child: child,
    );

    final interactiveContent = onTap == null
        ? content
        : InkWell(
            borderRadius: PremiumDesignTokens.cardRadius,
            onTap: onTap,
            child: AnimatedScale(
              duration: PremiumMotionTokens.durationFor(
                context,
                PremiumMotionTokens.feedbackDuration,
              ),
              curve: PremiumMotionTokens.feedbackCurve,
              scale: 1,
              child: content,
            ),
          );

    return Semantics(
      container: semanticContainer,
      child: Card(clipBehavior: Clip.antiAlias, child: interactiveContent),
    );
  }
}
