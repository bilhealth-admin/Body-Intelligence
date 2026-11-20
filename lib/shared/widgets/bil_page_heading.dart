import 'package:flutter/material.dart';

/// Canonical page/sheet typography, matching the Conversations heading.
/// Family, size and locale-specific metrics come from the active theme.
/// Text continues to honor the platform's accessibility scaling.
TextStyle? bilPageHeadingStyle(BuildContext context, {Color? color}) =>
    Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: color);
