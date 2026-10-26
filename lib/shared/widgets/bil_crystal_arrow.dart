import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../app/theme/bil_pearl_finish.dart';

/// A persistent, non-interactive glass surface for directional/navigation glyphs.
///
/// This widget decorates only. The parent button or gesture detector remains
/// responsible for hit testing, activation, navigation, and semantics. The
/// crystal is visible at rest as well as during and after activation.
class BilCrystalArrow extends StatelessWidget {
  const BilCrystalArrow({
    required this.child,
    this.extent = diameter,
    this.reserveSpace = false,
    super.key,
  }) : assert(extent > 0);

  static const double diameter = 48;

  final Widget child;
  final double extent;

  /// Inline glyphs reserve their decoration width so glass cannot cover text.
  /// Existing 48-pixel buttons retain their original layout by default.
  final bool reserveSpace;

  @override
  Widget build(BuildContext context) {
    // An automatic Material back icon can inherit the same design as an
    // explicit parent. Draw one surface, never two nested crystals.
    if (context.dependOnInheritedWidgetOfExactType<_BilCrystalPresence>() !=
        null) {
      return child;
    }
    final theme = Theme.of(context);
    final media = MediaQuery.maybeOf(context);
    // Pearl composer controls deliberately use the same navy ink in both
    // themes. Keep that existing ink and its light crystal surface, instead
    // of recoloring a protected composer glyph when the surrounding page is dark.
    final explicitInk = child is Icon ? (child as Icon).color : null;
    final pearlInk = const <Color>[
      BilPearlFinish.lightInk,
      Color(0xFF14243A), // Existing Coach/Community Pearl composer ink.
    ].contains(explicitInk?.withValues(alpha: 1));
    final dark = theme.brightness == Brightness.dark && !pearlInk;
    final solid =
        media?.highContrast == true ||
        media?.accessibleNavigation == true ||
        media?.disableAnimations == true;
    final background = dark ? const Color(0xFF15283C) : const Color(0xFFE4F2FC);
    Color legible(Color color) {
      // Disabled opacity stays disabled. Preserve branded colors that already
      // contrast; a white button glyph must not remain white on light glass.
      final a = color.computeLuminance();
      final b = background.computeLuminance();
      final ratio = (a > b ? a + .05 : b + .05) / (a > b ? b + .05 : a + .05);
      if (ratio >= 3) return color;
      return (dark ? BilPearlFinish.darkInk : BilPearlFinish.lightInk)
          .withValues(alpha: color.a);
    }

    final inherited = IconTheme.of(context);
    final original = child;
    final resolvedColor = original is Icon
        ? original.color ?? inherited.color ?? theme.colorScheme.onSurface
        : inherited.color ?? theme.colorScheme.onSurface;
    final glyphColor = legible(resolvedColor);
    final glyph =
        original is Icon &&
            original.color != null &&
            glyphColor != original.color
        ? _copyIcon(original, glyphColor)
        : original;

    final fill = DecoratedBox(
      key: const Key('bil-crystal-arrow-bubble'),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [
                  const Color(0xFF243A50).withValues(alpha: solid ? 1 : .86),
                  const Color(0xFF15283C).withValues(alpha: solid ? 1 : .74),
                ]
              : [
                  Colors.white.withValues(alpha: solid ? 1 : .88),
                  const Color(0xFFE4F2FC).withValues(alpha: solid ? 1 : .74),
                ],
        ),
        border: Border.all(
          color: solid
              ? theme.colorScheme.onSurface
              : dark
              ? Colors.white.withValues(alpha: .24)
              : Colors.white.withValues(alpha: .94),
          width: solid ? 1.5 : .9,
        ),
      ),
      child: const SizedBox.expand(),
    );

    final bubble = SizedBox.square(
      dimension: extent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: solid
              ? const []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? .18 : .09),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: ClipOval(
          child: solid
              ? fill
              : BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: fill,
                ),
        ),
      ),
    );

    final surface = Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: Center(
                child: OverflowBox(
                  minWidth: extent,
                  maxWidth: extent,
                  minHeight: extent,
                  maxHeight: extent,
                  child: bubble,
                ),
              ),
            ),
          ),
        ),
        _BilCrystalPresence(
          child: IconTheme.merge(
            data: IconThemeData(color: glyphColor),
            child: glyph,
          ),
        ),
      ],
    );
    return reserveSpace
        ? SizedBox.square(
            dimension: extent,
            child: Center(child: surface),
          )
        : surface;
  }
}

Icon _copyIcon(Icon original, Color? color, {bool preserveKey = true}) => Icon(
  original.icon,
  key: preserveKey ? original.key : null,
  size: original.size,
  fill: original.fill,
  weight: original.weight,
  grade: original.grade,
  opticalSize: original.opticalSize,
  color: color,
  shadows: original.shadows,
  semanticLabel: original.semanticLabel,
  textDirection: original.textDirection,
  applyTextScaling: original.applyTextScaling,
  blendMode: original.blendMode,
  fontWeight: original.fontWeight,
);

class _BilCrystalPresence extends InheritedWidget {
  const _BilCrystalPresence({required super.child});

  @override
  bool updateShouldNotify(_BilCrystalPresence oldWidget) => false;
}

/// For plugin APIs that accept Icon rather than Widget. Inherits the complete
/// Icon semantics, sizing, direction and disabled theme before decorating it.
class BilCrystalActionIcon extends Icon {
  const BilCrystalActionIcon(
    super.icon, {
    super.key,
    super.size,
    super.color,
    super.semanticLabel,
    super.textDirection,
  });

  @override
  Widget build(BuildContext context) =>
      BilCrystalArrow(child: _copyIcon(this, color, preserveKey: false));
}
