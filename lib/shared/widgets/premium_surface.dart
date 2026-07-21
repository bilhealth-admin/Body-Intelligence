import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/premium_design_tokens.dart';
import '../../app/theme/premium_motion_tokens.dart';

class PremiumSurface extends StatefulWidget {
  const PremiumSurface({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.semanticContainer = true,
    this.emphasized = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool semanticContainer;
  final bool emphasized;

  @override
  State<PremiumSurface> createState() => _PremiumSurfaceState();
}

class _PremiumSurfaceState extends State<PremiumSurface> {
  bool hovered = false;
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    final radius = PremiumDesignTokens.cardRadius;

    final content = Padding(
      padding: widget.padding ?? PremiumDesignTokens.cardPadding,
      child: widget.child,
    );

    return Semantics(
      container: widget.semanticContainer,
      button: interactive,
      child: MouseRegion(
        cursor: interactive
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: interactive ? (_) => setState(() => hovered = true) : null,
        onExit: interactive
            ? (_) => setState(() {
                hovered = false;
                pressed = false;
              })
            : null,
        child: GestureDetector(
          onTapDown: interactive ? (_) => setState(() => pressed = true) : null,
          onTapCancel: interactive
              ? () => setState(() => pressed = false)
              : null,
          onTapUp: interactive
              ? (_) {
                  setState(() => pressed = false);
                  widget.onTap?.call();
                }
              : null,
          child: AnimatedScale(
            duration: PremiumMotionTokens.durationFor(
              context,
              PremiumMotionTokens.feedbackDuration,
            ),
            curve: PremiumMotionTokens.feedbackCurve,
            scale: pressed ? .988 : (hovered ? 1.006 : 1),
            child: ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: widget.emphasized ? 26 : 20,
                  sigmaY: widget.emphasized ? 26 : 20,
                ),
                child: AnimatedContainer(
                  duration: PremiumMotionTokens.durationFor(
                    context,
                    PremiumMotionTokens.stateChangeDuration,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: hovered ? .115 : .085),
                        const Color(
                          0xFF58D7FF,
                        ).withValues(alpha: widget.emphasized ? .065 : .032),
                        const Color(
                          0xFF7B60FF,
                        ).withValues(alpha: widget.emphasized ? .060 : .028),
                        Colors.white.withValues(alpha: .016),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF42CFFF).withValues(
                          alpha: widget.emphasized
                              ? (hovered ? .22 : .15)
                              : (hovered ? .12 : .07),
                        ),
                        blurRadius: widget.emphasized ? 38 : 28,
                        spreadRadius: -12,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .24),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
