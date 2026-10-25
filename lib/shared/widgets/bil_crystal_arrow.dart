import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A persistent, non-interactive glass surface for directional/navigation glyphs.
///
/// This widget decorates only. The parent button or gesture detector remains
/// responsible for hit testing, activation, navigation, and semantics. The
/// crystal is visible at rest as well as during and after activation.
class BilCrystalArrow extends StatelessWidget {
  const BilCrystalArrow({
    required this.child,
    super.key,
  });

  static const double diameter = 48;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.maybeOf(context);
    final dark = theme.brightness == Brightness.dark;
    final solid =
        media?.highContrast == true || media?.accessibleNavigation == true;

    final bubble = SizedBox.square(
      dimension: diameter,
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
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: solid ? 0 : 8,
              sigmaY: solid ? 0 : 8,
            ),
            child: DecoratedBox(
              key: const Key('bil-crystal-arrow-bubble'),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: dark
                      ? [
                          const Color(0xFF243A50)
                              .withValues(alpha: solid ? 1 : .86),
                          const Color(0xFF15283C)
                              .withValues(alpha: solid ? 1 : .74),
                        ]
                      : [
                          Colors.white.withValues(alpha: solid ? 1 : .88),
                          const Color(0xFFE4F2FC)
                              .withValues(alpha: solid ? 1 : .74),
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
            ),
          ),
        ),
      ),
    );

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: Center(
                child: OverflowBox(
                  minWidth: diameter,
                  maxWidth: diameter,
                  minHeight: diameter,
                  maxHeight: diameter,
                  child: bubble,
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
