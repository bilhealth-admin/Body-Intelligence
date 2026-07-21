import 'package:flutter/material.dart';

import '../../app/theme/bil_elevation.dart';
import '../../app/theme/bil_flagship_tokens.dart';
import '../../app/theme/bil_spacing.dart';

enum BilCardVariant { solid, glass, outlined, elevated }

enum BilCardPadding { compact, standard, comfortable }

class BilCard extends StatefulWidget {
  const BilCard({
    super.key,
    required this.child,
    this.variant = BilCardVariant.solid,
    this.padding = BilCardPadding.standard,
    this.margin,
    this.onTap,
    this.enabled = true,
    this.semanticLabel,
    this.borderRadius,
  });

  final Widget child;
  final BilCardVariant variant;
  final BilCardPadding padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool enabled;
  final String? semanticLabel;
  final BorderRadius? borderRadius;

  bool get interactive => onTap != null;

  @override
  State<BilCard> createState() => _BilCardState();
}

class _BilCardState extends State<BilCard> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  EdgeInsetsGeometry get _resolvedPadding {
    switch (widget.padding) {
      case BilCardPadding.compact:
        return BilSpacing.cardCompact;
      case BilCardPadding.standard:
        return BilSpacing.card;
      case BilCardPadding.comfortable:
        return BilSpacing.cardComfortable;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final interactive = widget.interactive && widget.enabled;
    final radius =
        widget.borderRadius ??
        BorderRadius.circular(BilFlagshipTokens.radiusLg);

    final appearance = _resolveAppearance(
      scheme: scheme,
      dark: dark,
      interactive: interactive,
    );

    final scale = _pressed ? .985 : 1.0;

    Widget card = AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        margin: widget.margin,
        padding: _resolvedPadding,
        decoration: BoxDecoration(
          color: appearance.background,
          borderRadius: radius,
          border: Border.all(
            color: appearance.border,
            width: appearance.borderWidth,
          ),
          boxShadow: appearance.shadows,
        ),
        child: widget.child,
      ),
    );

    if (widget.interactive) {
      card = FocusableActionDetector(
        enabled: widget.enabled,
        mouseCursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowHoverHighlight: (value) {
          if (_hovered == value) return;
          setState(() => _hovered = value);
        },
        onShowFocusHighlight: (value) {
          if (_focused == value) return;
          setState(() => _focused = value);
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              if (widget.enabled) widget.onTap?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? widget.onTap : null,
          onTapDown: widget.enabled
              ? (_) => setState(() => _pressed = true)
              : null,
          onTapUp: widget.enabled
              ? (_) => setState(() => _pressed = false)
              : null,
          onTapCancel: widget.enabled
              ? () => setState(() => _pressed = false)
              : null,
          child: card,
        ),
      );
    }

    return Semantics(
      container: true,
      button: widget.interactive,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      child: ExcludeSemantics(
        excluding: widget.semanticLabel != null,
        child: Opacity(opacity: widget.enabled ? 1 : .52, child: card),
      ),
    );
  }

  _BilCardAppearance _resolveAppearance({
    required ColorScheme scheme,
    required bool dark,
    required bool interactive,
  }) {
    final active = interactive && (_hovered || _focused);

    switch (widget.variant) {
      case BilCardVariant.solid:
        return _BilCardAppearance(
          background: dark
              ? BilFlagshipTokens.surfaceDark
              : BilFlagshipTokens.surfaceLight,
          border: active
              ? BilFlagshipTokens.cyan500.withValues(alpha: .72)
              : scheme.outlineVariant.withValues(alpha: .42),
          borderWidth: active ? 1.4 : 1,
          shadows: active ? BilElevation.floating : BilElevation.card,
        );

      case BilCardVariant.glass:
        return _BilCardAppearance(
          background: Colors.white.withValues(alpha: dark ? .07 : .76),
          border: active
              ? BilFlagshipTokens.cyan400.withValues(alpha: .58)
              : Colors.white.withValues(alpha: dark ? .12 : .64),
          borderWidth: active ? 1.4 : 1,
          shadows: active ? BilElevation.hero : BilElevation.floating,
        );

      case BilCardVariant.outlined:
        return _BilCardAppearance(
          background: Colors.transparent,
          border: active ? BilFlagshipTokens.cyan500 : scheme.outline,
          borderWidth: active ? 1.6 : 1,
          shadows: BilElevation.none,
        );

      case BilCardVariant.elevated:
        return _BilCardAppearance(
          background: dark
              ? BilFlagshipTokens.surfaceMutedDark
              : BilFlagshipTokens.surfaceLight,
          border: active
              ? BilFlagshipTokens.cyan500.withValues(alpha: .65)
              : scheme.outlineVariant.withValues(alpha: .30),
          borderWidth: active ? 1.4 : 1,
          shadows: active ? BilElevation.hero : BilElevation.floating,
        );
    }
  }
}

class _BilCardAppearance {
  const _BilCardAppearance({
    required this.background,
    required this.border,
    required this.borderWidth,
    required this.shadows,
  });

  final Color background;
  final Color border;
  final double borderWidth;
  final List<BoxShadow> shadows;
}
