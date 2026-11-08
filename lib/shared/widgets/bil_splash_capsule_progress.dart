import 'package:flutter/material.dart';

/// The BIL startup capsule paint, shared with real pending-operation surfaces.
/// [progress] is a visual phase only; it does not represent task completion.
class BilSplashCapsuleProgress extends StatelessWidget {
  const BilSplashCapsuleProgress({
    super.key,
    required this.width,
    required this.progress,
    this.reducedMotion = false,
    this.color = Colors.white,
  }) : assert(width > 0);

  final double width;
  final double progress;
  final bool reducedMotion;
  final Color color;

  Color _alpha(int alpha) => color.withValues(alpha: color.a * alpha / 255);

  @override
  Widget build(BuildContext context) {
    final timelineValue = reducedMotion ? 0.72 : progress.clamp(0.0, 1.0);
    final eased = Curves.easeInOutCubicEmphasized.transform(timelineValue);
    final fill = 0.12 + (0.88 * eased);
    final highlightX = ((width + 38) * eased) - 38;
    return SizedBox(
      width: width,
      height: 7,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: _alpha(0x38)),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fill,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_alpha(0xA8), _alpha(0xD6)],
                    ),
                  ),
                ),
              ),
            ),
            if (!reducedMotion)
              Transform.translate(
                offset: Offset(highlightX, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 38,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_alpha(0), _alpha(0xB8), _alpha(0)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
