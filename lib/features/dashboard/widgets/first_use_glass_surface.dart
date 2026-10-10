import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Reusable first-use glass surface. It never captures taps outside its bounds.
class FirstUseGlassSurface extends StatelessWidget {
  const FirstUseGlassSurface({
    super.key,
    required this.child,
    this.accent = const Color(0xFF78E7D4),
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(27);
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: Colors.white.withValues(alpha: .24)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF06192C).withValues(alpha: .22),
            blurRadius: 26,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: reduceMotion ? 0 : 11,
            sigmaY: reduceMotion ? 0 : 11,
          ),
          child: Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xF70A213B),
                        Color(0xF4193E54),
                        Color(0xF5132745),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -100,
                right: -70,
                width: 245,
                height: 245,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accent.withValues(alpha: .34),
                        accent.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned(
                bottom: -95,
                left: -90,
                width: 210,
                height: 210,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color(0x60246CCA),
                        Color(0x00246CCA),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _GlassPinpoints(accent)),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPinpoints extends CustomPainter {
  const _GlassPinpoints(this.accent);

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    const points = <Offset>[
      Offset(.08, .14),
      Offset(.26, .075),
      Offset(.71, .06),
      Offset(.91, .18),
      Offset(.86, .42),
      Offset(.14, .49),
      Offset(.67, .68),
      Offset(.94, .83),
      Offset(.34, .92),
    ];
    final dot = Paint()..color = Colors.white.withValues(alpha: .35);
    for (var i = 0; i < points.length; i++) {
      final p = Offset(points[i].dx * size.width, points[i].dy * size.height);
      canvas.drawCircle(p, i.isEven ? 1.6 : 1.0, dot);
    }
    final edge = Paint()
      ..color = accent.withValues(alpha: .22)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromLTWH(size.width - 112, -63, 170, 170),
      1.25,
      1.6,
      false,
      edge,
    );
  }

  @override
  bool shouldRepaint(covariant _GlassPinpoints oldDelegate) =>
      oldDelegate.accent != accent;
}
