import 'package:flutter/material.dart';

/// Centralized elevation and shadow definitions for BIL.
///
/// Widgets should consume these presets instead of creating ad-hoc BoxShadow
/// lists throughout the application.
abstract final class BilElevation {
  static const List<BoxShadow> none = [];

  static const List<BoxShadow> card = [
    BoxShadow(
      blurRadius: 12,
      spreadRadius: 0,
      offset: Offset(0, 4),
      color: Color(0x14000000),
    ),
  ];

  static const List<BoxShadow> floating = [
    BoxShadow(
      blurRadius: 24,
      spreadRadius: -2,
      offset: Offset(0, 10),
      color: Color(0x22000000),
    ),
  ];

  static const List<BoxShadow> button = [
    BoxShadow(
      blurRadius: 18,
      spreadRadius: -2,
      offset: Offset(0, 8),
      color: Color(0x33009DFF),
    ),
  ];

  static const List<BoxShadow> hero = [
    BoxShadow(
      blurRadius: 48,
      spreadRadius: -6,
      offset: Offset(0, 18),
      color: Color(0x2200C2FF),
    ),
    BoxShadow(
      blurRadius: 96,
      spreadRadius: -12,
      offset: Offset(0, 32),
      color: Color(0x1100E5FF),
    ),
  ];

  static List<BoxShadow> glow(Color color, {double opacity = .22}) => [
    BoxShadow(
      color: color.withValues(alpha: opacity),
      blurRadius: 28,
      spreadRadius: -2,
      offset: const Offset(0, 0),
    ),
  ];
}
