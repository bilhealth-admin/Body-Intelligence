import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/premium_design_tokens.dart';
import '../../app/theme/premium_motion_tokens.dart';

enum PremiumSurfaceLevel { primary, supporting, detail }

class PremiumSurface extends StatefulWidget {
  const PremiumSurface({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.semanticContainer = true,
    this.emphasized = false,
    this.dashboardGlass = false,
    this.level = PremiumSurfaceLevel.supporting,
    this.focusNode,
    this.autofocus = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool semanticContainer;
  final bool emphasized;
  final bool dashboardGlass;
  final PremiumSurfaceLevel level;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<PremiumSurface> createState() => _PremiumSurfaceState();
}

class _PremiumSurfaceState extends State<PremiumSurface> {
  bool hovered = false;
  bool pressed = false;
  bool focused = false;

  bool get _primary =>
      widget.emphasized || widget.level == PremiumSurfaceLevel.primary;

  bool get _detail => widget.level == PremiumSurfaceLevel.detail;

  double _hierarchyValue(double value) {
    if (_detail) return value * .72;
    if (_primary) return value * 1.12;
    return value;
  }

  Color _hierarchyColor(Color color) =>
      _detail ? Color.lerp(Colors.transparent, color, .62)! : color;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    final radius = widget.dashboardGlass
        ? PremiumDesignTokens.dashboardCardRadius
        : PremiumDesignTokens.cardRadius;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final content = Padding(
      padding: widget.padding ?? PremiumDesignTokens.cardPadding,
      child: widget.child,
    );

    return Semantics(
      container: widget.semanticContainer,
      button: interactive,
      focusable: interactive,
      focused: interactive ? focused : null,
      child: FocusableActionDetector(
        enabled: interactive,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onShowFocusHighlight: interactive
            ? (value) => setState(() => focused = value)
            : null,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
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
            onTapDown: interactive
                ? (_) => setState(() => pressed = true)
                : null,
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
              scale: pressed
                  ? PremiumDesignTokens.dashboardCardPressedScale
                  : (hovered ? PremiumDesignTokens.dashboardCardHoverScale : 1),
              child: ClipRRect(
                borderRadius: radius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: widget.dashboardGlass
                        ? (dark
                              ? (_primary ? 18 : (_detail ? 10 : 14))
                              : (_primary ? 12 : (_detail ? 6 : 8)))
                        : (_primary ? 26 : (_detail ? 14 : 20)),
                    sigmaY: widget.dashboardGlass
                        ? (dark
                              ? (_primary ? 18 : (_detail ? 10 : 14))
                              : (_primary ? 12 : (_detail ? 6 : 8)))
                        : (_primary ? 26 : (_detail ? 14 : 20)),
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
                                      ? (_primary
                                            ? .052
                                            : (_detail ? .014 : .024))
                                      : (_primary
                                            ? .065
                                            : (_detail ? .018 : .032)),
                                ),
                                const Color(0xFF7B60FF).withValues(
                                  alpha: widget.dashboardGlass
                                      ? (_primary
                                            ? .046
                                            : (_detail ? .012 : .020))
                                      : (_primary
                                            ? .060
                                            : (_detail ? .016 : .028)),
                                ),
                                Colors.white.withValues(
                                  alpha: widget.dashboardGlass ? .010 : .016,
                                ),
                              ],
                      ),
                      border: widget.dashboardGlass
                          ? Border.all(
                              color:
                                  PremiumDesignTokens.dashboardCardBorderColor(
                                    Theme.of(context).brightness,
                                    hovered: hovered || focused,
                                  ),
                              width:
                                  PremiumDesignTokens.dashboardCardBorderWidth,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: _hierarchyColor(
                            PremiumDesignTokens.dashboardCardAccentShadowColor(
                              Theme.of(context).brightness,
                              hovered: hovered || focused,
                              emphasized: _primary,
                            ),
                          ),
                          blurRadius: widget.dashboardGlass
                              ? _hierarchyValue(
                                  PremiumDesignTokens.dashboardCardAccentBlur,
                                )
                              : _hierarchyValue(_primary ? 38 : 28),
                          spreadRadius: -12,
                        ),
                        BoxShadow(
                          color: widget.dashboardGlass
                              ? PremiumDesignTokens.dashboardCardShadowColor(
                                  Theme.of(context).brightness,
                                )
                              : dark
                              ? Colors.black.withValues(alpha: .24)
                              : const Color(0xFF315D88).withValues(alpha: .14),
                          blurRadius: _hierarchyValue(
                            widget.dashboardGlass
                                ? PremiumDesignTokens.dashboardCardShadowBlur
                                : 22,
                          ),
                          offset: Offset(
                            0,
                            widget.dashboardGlass
                                ? PremiumDesignTokens.dashboardCardShadowOffsetY
                                : 12,
                          ),
                        ),
                        if (widget.dashboardGlass)
                          BoxShadow(
                            color: Colors.white.withValues(
                              alpha: dark
                                  ? .055
                                  : PremiumDesignTokens
                                        .dashboardCardInnerHighlightAlpha,
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
      ),
    );
  }
}
