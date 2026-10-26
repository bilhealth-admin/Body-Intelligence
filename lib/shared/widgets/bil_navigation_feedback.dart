import 'package:flutter/material.dart';

import 'bil_crystal_arrow.dart';
import 'bil_glass_press_feedback.dart';

export 'bil_glass_press_feedback.dart' show BilArrowGlyph;

/// Persistent decoration for existing navigation controls. The original parent
/// still owns taps, focus, disabled state, semantics and layout. Non-directional
/// controls retain their existing press feedback. Checkout never uses this class.
class BilNavigationFeedback extends StatelessWidget {
  const BilNavigationFeedback({
    required this.child,
    this.always = false,
    super.key,
  });

  final Widget child;
  final bool always;

  @override
  Widget build(BuildContext context) {
    final original = child;
    if (original is Icon && BilArrowGlyph.isArrow(original.icon)) {
      final standalone =
          context.findAncestorWidgetOfExactType<IconButton>() != null;
      final size = original.size ?? IconTheme.of(context).size ?? 24;
      // Inline labels normally have an eight-pixel icon gap. Keep the crystal
      // within that gap while the existing button/row retains its full target.
      // Even logical-pixel diameters keep the resting edge aligned at 1x/2x.
      final inlineExtent = (((size + 12) / 2).ceil() * 2).toDouble();
      final extent = standalone ? 48.0 : inlineExtent.clamp(28.0, 48.0);
      return BilCrystalArrow(
        extent: extent,
        child: BilArrowGlyph.modern(original),
      );
    }
    return BilGlassPressFeedback(always: always, child: original);
  }
}
