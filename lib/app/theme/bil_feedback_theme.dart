import 'package:flutter/material.dart';

/// App-wide transient feedback, matching the Coach report confirmation.
/// Message content, actions, duration and announcement behavior remain owned
/// by the caller. Persistent cards use BilPearlFinish separately.
abstract final class BilFeedbackTheme {
  static SnackBarThemeData resolve(ColorScheme scheme) => SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: scheme.surfaceContainerHighest,
    contentTextStyle: TextStyle(color: scheme.onSurface),
    actionTextColor: scheme.primary,
    disabledActionTextColor: scheme.onSurfaceVariant,
    closeIconColor: scheme.onSurface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
}
