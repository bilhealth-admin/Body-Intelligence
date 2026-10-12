import 'package:flutter/material.dart';
import '../../shared/widgets/bil_glass_press_feedback.dart';

abstract final class BilNavigationPressStyle {
  static Widget backIcon(BuildContext context) =>
      const BilGlassPressFeedback(child: Icon(Icons.chevron_left_rounded));
}
