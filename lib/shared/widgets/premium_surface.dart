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

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    final radius = widget.dashboardGlass
        ? PremiumDesignTokens.dashboardCardRadius
        : PremiumDesignTokens.cardRadius;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final colorScheme = Theme.of(context).colorScheme;

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
              child: AnimatedContainer(
                duration: PremiumMotionTokens.durationFor(
                  context,
                  PremiumMotionTokens.stateChangeDuration,
                ),
                decoration: BoxDecoration(
                  color: widget.dashboardGlass ? null : colorScheme.surface,
                  gradient: widget.dashboardGlass
                      ? LinearGradient(
                          begin: AlignmentDirectional.topStart,
                          end: AlignmentDirectional.bottomEnd,
                          colors: dark
                              ? <Color>[
                                  colorScheme.surfaceContainerHigh,
                                  colorScheme.surfaceContainer,
                                ]
                              : <Color>[
                                  Colors.white,
                                  colorScheme.surfaceContainerLowest,
                                ],
                        )
                      : null,
                  borderRadius: radius,
                  border: Border.all(
                    color: highContrast
                        ? colorScheme.outline
                        : PremiumDesignTokens.dashboardCardBorderColor(
                            Theme.of(context).brightness,
                            hovered: hovered,
                          ),
                    width: highContrast
                        ? PremiumDesignTokens
                              .dashboardCardHighContrastBorderWidth
                        : PremiumDesignTokens.dashboardCardBorderWidth,
                  ),
                  boxShadow: dark || highContrast
                      ? const []
                      : const [
                          BoxShadow(
                            color: Color(0x0D000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                ),
                child: Material(
                  type: MaterialType.transparency,
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
