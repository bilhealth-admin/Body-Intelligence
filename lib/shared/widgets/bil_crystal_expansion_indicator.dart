import 'package:flutter/material.dart';

import 'bil_crystal_arrow.dart';

/// Uses the enclosing Material tile's real controller: no duplicate expanded
/// state, tap handler, semantics or persistence. Only the glyph rotates.
class BilCrystalExpansionIndicator extends StatelessWidget {
  const BilCrystalExpansionIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ExpansibleController.of(context);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Theme.of(
                context,
              ).expansionTileTheme.expansionAnimationStyle?.duration ??
              const Duration(milliseconds: 200);
    return BilCrystalArrow(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, child) => AnimatedRotation(
          turns: controller.isExpanded ? .5 : 0,
          duration: duration,
          curve: Curves.easeInOut,
          child: child,
        ),
        child: const Icon(Icons.expand_more),
      ),
    );
  }
}
