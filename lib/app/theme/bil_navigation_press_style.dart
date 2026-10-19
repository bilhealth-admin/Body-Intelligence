import 'package:flutter/material.dart';
import '../../shared/widgets/bil_glass_press_feedback.dart';
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

  static Widget backIcon(BuildContext context) =>
      const BilGlassPressFeedback(child: Icon(Icons.chevron_left_rounded));
}
