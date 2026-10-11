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
    final radius = BorderRadius.circular(24);
    final tint = HSVColor.fromColor(
      accent,
    ).withSaturation(.72).withValue(.36).toColor();
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: Colors.white.withValues(alpha: .48)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .18),
            blurRadius: 26,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(tint, accent, .22)!.withValues(alpha: .92),
                        Color.lerp(
                          const Color(0xFF102B49),
                          accent,
                          .16,
                        )!.withValues(alpha: .88),
                        const Color(0xE609243B),
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
                        accent.withValues(alpha: .55),
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
                      colors: [Color(0x60246CCA), Color(0x00246CCA)],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _GlassReflection(accent)),
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

class _GlassReflection extends CustomPainter {
  const _GlassReflection(this.accent);
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    // A broad reflected light, rather than a decorative star texture.
    final sheen = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..quadraticBezierTo(
        size.width * .55,
        size.height * .28,
        0,
        size.height * .44,
      )
      ..close();
    canvas.drawPath(
      sheen,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x30FFFFFF), Color(0x00FFFFFF)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawLine(
      const Offset(24, 1),
      Offset(size.width - 24, 1),
      Paint()
        ..color = Colors.white.withValues(alpha: .55)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _GlassReflection oldDelegate) =>
      oldDelegate.accent != accent;
}
