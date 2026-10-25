import 'package:flutter/material.dart';
import '../../shared/widgets/bil_crystal_arrow.dart';
import 'bil_pearl_finish.dart';

abstract final class BilNavigationPressStyle {
  /// Shared resting surface for navigation bubbles. Never inherit the tonal
  /// button's green/blue fill from a page-specific ColorScheme.
  static ButtonStyle neutralBubble(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return IconButton.styleFrom(
      backgroundColor: dark
          ? BilPearlFinish.darkInset
          : BilPearlFinish.lightInset,
      foregroundColor: theme.colorScheme.onSurface,
      disabledBackgroundColor: dark
          ? BilPearlFinish.darkSurface
          : BilPearlFinish.lightSurface,
      disabledForegroundColor: theme.colorScheme.onSurface.withValues(
        alpha: .38,
      ),
      shape: CircleBorder(
        side: BorderSide(
          color: dark ? BilPearlFinish.darkEdge : BilPearlFinish.lightEdge,
          width: .8,
        ),
      ),
    );
  }

  /// Transparent button chrome for a child that draws its own resting crystal.
  /// This method is intentionally not used by commerce purchase controls.
  static ButtonStyle crystalButton(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    return IconButton.styleFrom(
      backgroundColor: Colors.transparent,
      foregroundColor: foreground,
      disabledBackgroundColor: Colors.transparent,
      disabledForegroundColor: foreground.withValues(alpha: .38),
      overlayColor: foreground.withValues(alpha: .08),
      minimumSize: const Size(48, 48),
      padding: EdgeInsets.zero,
      shape: const CircleBorder(side: BorderSide(color: Colors.transparent)),
    );
  }

  /// Flutter mirrors this glyph once in RTL (matchTextDirection: true).
  /// Do not swap to chevron_right in RTL: that would mirror it twice.
  /// The protected purchase CTA does not use this back icon helper.
  static Widget backIcon(BuildContext context) =>
      const BilCrystalArrow(child: Icon(Icons.chevron_left_rounded));
}
