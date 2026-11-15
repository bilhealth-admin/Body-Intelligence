import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The compact circular wait used by health synchronization and checkout.
/// Its fixed footprint and reduced-motion state never imply real completion.
class BilCompactActivityIndicator extends StatelessWidget {
  const BilCompactActivityIndicator({super.key, this.color, this.label});

  final Color? color;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    role: ui.SemanticsRole.loadingSpinner,
    child: ExcludeSemantics(
      child: SizedBox.square(
        dimension: 24,
        child: MediaQuery.disableAnimationsOf(context)
            ? CustomPaint(
                painter: _ReducedMotionWaitPainter(
                  color ??
                      ProgressIndicatorTheme.of(context).color ??
                      Theme.of(context).colorScheme.primary,
                ),
              )
            : CircularProgressIndicator(strokeWidth: 2, color: color),
      ),
    ),
  );
}

/// A stationary waiting arc, without a determinate value or completion ratio.
class _ReducedMotionWaitPainter extends CustomPainter {
  const _ReducedMotionWaitPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: math.max(0, size.shortestSide / 2 - 1),
    );
    canvas.drawArc(
      bounds,
      -math.pi / 2,
      math.pi * 1.5,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ReducedMotionWaitPainter oldDelegate) =>
      color != oldDelegate.color;
}
