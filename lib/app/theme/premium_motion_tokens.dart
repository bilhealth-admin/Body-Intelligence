import 'package:flutter/material.dart';

/// Canonical motion tokens for Premium Motion (Epic 7).
///
/// All animation timings/curves should be sourced from this file to avoid
/// scattered one-off motion values.
class PremiumMotionTokens {
  const PremiumMotionTokens._();

  // Duration scale
  static const Duration instant = Duration.zero;
  static const Duration micro = Duration(milliseconds: 80);
  static const Duration short = Duration(milliseconds: 140);
  static const Duration medium = Duration(milliseconds: 220);
  static const Duration long = Duration(milliseconds: 320);
  static const Duration dashboardEntranceDuration = Duration(milliseconds: 360);

  // Curves chosen for calm, premium, non-bouncy transitions.
  static const Curve emphasized = Cubic(0.20, 0.0, 0.0, 1.0);
  static const Curve standard = Cubic(0.24, 0.0, 0.0, 1.0);
  static const Curve decelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve dashboardEntranceCurve = Cubic(0.16, 1.0, 0.3, 1.0);
  static const Offset dashboardEntranceOffset = Offset(0, 0.018);

  // Semantic assignments
  static const Duration navigationDuration = medium;
  static const Duration stateChangeDuration = short;
  static const Duration feedbackDuration = micro;

  static const Curve navigationCurve = emphasized;
  static const Curve stateChangeCurve = standard;
  static const Curve feedbackCurve = decelerate;

  static bool prefersReducedMotion(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    return mediaQuery?.disableAnimations ?? false;
  }

  static Duration durationFor(BuildContext context, Duration duration) =>
      prefersReducedMotion(context) ? instant : duration;
}
