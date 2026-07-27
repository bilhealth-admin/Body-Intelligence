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
    this.dashboardGlass = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool semanticContainer;
  final bool emphasized;
  final bool dashboardGlass;

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
    final dark = Theme.of(context).brightness == Brightness.dark;

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
                  sigmaX: widget.dashboardGlass
                      ? (dark
                            ? (widget.emphasized ? 18 : 14)
                            : (widget.emphasized ? 12 : 8))
                      : (widget.emphasized ? 26 : 20),
                  sigmaY: widget.dashboardGlass
                      ? (dark
                            ? (widget.emphasized ? 18 : 14)
                            : (widget.emphasized ? 12 : 8))
                      : (widget.emphasized ? 26 : 20),
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
                      colors: widget.dashboardGlass && !dark
                          ? [
                              Colors.white.withValues(
                                alpha: hovered ? .88 : .78,
                              ),
                              const Color(0xFFF5FBFF).withValues(alpha: .68),
                              const Color(0xFFEAF5FF).withValues(alpha: .56),
                              Colors.white.withValues(alpha: .72),
                            ]
                          : [
                              Colors.white.withValues(
                                alpha: widget.dashboardGlass
                                    ? (hovered ? .16 : .115)
                                    : (hovered ? .115 : .085),
                              ),
                              const Color(0xFF58D7FF).withValues(
                                alpha: widget.dashboardGlass
                                    ? (widget.emphasized ? .052 : .024)
                                    : (widget.emphasized ? .065 : .032),
                              ),
                              const Color(0xFF7B60FF).withValues(
                                alpha: widget.dashboardGlass
                                    ? (widget.emphasized ? .046 : .020)
                                    : (widget.emphasized ? .060 : .028),
                              ),
                              Colors.white.withValues(
                                alpha: widget.dashboardGlass ? .010 : .016,
                              ),
                            ],
                    ),
                    border: widget.dashboardGlass
                        ? Border.all(
                            color: dark
                                ? Colors.white.withValues(
                                    alpha: hovered ? .22 : .14,
                                  )
                                : const Color(
                                    0xFFBFD8F4,
                                  ).withValues(alpha: hovered ? .92 : .68),
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3287D8).withValues(
                          alpha: !dark && widget.dashboardGlass
                              ? (hovered ? .18 : .10)
                              : widget.emphasized
                              ? (hovered ? .22 : .15)
                              : (hovered ? .12 : .07),
                        ),
                        blurRadius: widget.dashboardGlass
                            ? (widget.emphasized ? 32 : 24)
                            : (widget.emphasized ? 38 : 28),
                        spreadRadius: -12,
                      ),
                      BoxShadow(
                        color: dark
                            ? Colors.black.withValues(
                                alpha: widget.dashboardGlass ? .20 : .24,
                              )
                            : const Color(0xFF315D88).withValues(alpha: .14),
                        blurRadius: widget.dashboardGlass ? 20 : 22,
                        offset: Offset(0, widget.dashboardGlass ? 10 : 12),
                      ),
                      if (widget.dashboardGlass)
                        BoxShadow(
                          color: Colors.white.withValues(
                            alpha: dark ? .055 : .78,
                          ),
                          blurRadius: 1,
                          offset: const Offset(0, 1),
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
