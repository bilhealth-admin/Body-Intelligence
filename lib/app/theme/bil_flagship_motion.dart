import 'package:flutter/animation.dart';
import 'package:flutter/widgets.dart';

abstract final class BilFlagshipMotion {
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration quick = Duration(milliseconds: 160);
  static const Duration standard = Duration(milliseconds: 260);
  static const Duration expressive = Duration(milliseconds: 420);

  static const Curve enterCurve = Cubic(0.20, 0.80, 0.20, 1.00);
  static const Curve exitCurve = Cubic(0.40, 0.00, 1.00, 1.00);
  static const Curve emphasizedCurve = Cubic(0.20, 0.90, 0.20, 1.00);

  static bool reduceMotion(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  static Duration duration(
    BuildContext context, {
    Duration normal = standard,
  }) => reduceMotion(context) ? Duration.zero : normal;
}
