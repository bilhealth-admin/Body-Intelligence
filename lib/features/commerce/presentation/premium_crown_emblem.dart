import 'package:flutter/material.dart';

/// A compact premium mark that remains crisp on light and dark surfaces.
class PremiumCrownEmblem extends StatelessWidget {
  const PremiumCrownEmblem({this.size = 64, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'BIL Premium',
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .31),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2C42), Color(0xFF07111D), Color(0xFF030912)],
          stops: [0, .52, 1],
        ),
        border: Border.all(color: const Color(0x99F6D477), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0x66E8B94A),
            blurRadius: size * .3,
            spreadRadius: -size * .12,
          ),
          BoxShadow(
            color: const Color(0x66000612),
            blurRadius: size * .36,
            offset: Offset(0, size * .18),
          ),
        ],
      ),
      padding: EdgeInsets.all(size * .18),
      child: CustomPaint(painter: const _CrownPainter()),
    ),
  );
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final crown = Path()
      ..moveTo(size.width * .08, size.height * .34)
      ..quadraticBezierTo(
        size.width * .17,
        size.height * .38,
        size.width * .27,
        size.height * .54,
      )
      ..lineTo(size.width * .39, size.height * .27)
      ..quadraticBezierTo(
        size.width * .45,
        size.height * .14,
        size.width * .50,
        size.height * .14,
      )
      ..quadraticBezierTo(
        size.width * .55,
        size.height * .14,
        size.width * .61,
        size.height * .27,
      )
      ..lineTo(size.width * .73, size.height * .54)
      ..quadraticBezierTo(
        size.width * .83,
        size.height * .38,
        size.width * .92,
        size.height * .34,
      )
      ..lineTo(size.width * .82, size.height * .75)
      ..quadraticBezierTo(
        size.width * .50,
        size.height * .86,
        size.width * .18,
        size.height * .75,
      )
      ..close();

    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFF3B0),
          Color(0xFFFFD469),
          Color(0xFFD49A26),
          Color(0xFFFFE596),
        ],
        stops: [0, .32, .7, 1],
      ).createShader(bounds);
    canvas.drawShadow(crown, const Color(0xCC000000), size.width * .07, false);
    canvas.drawPath(crown, fill);
    canvas.drawPath(
      crown,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .018
        ..color = const Color(0xFFFFF6C8),
    );

    final base = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * .19,
        size.height * .71,
        size.width * .62,
        size.height * .12,
      ),
      Radius.circular(size.width * .05),
    );
    canvas.drawRRect(
      base,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFC88818), Color(0xFFFFE384), Color(0xFFC88818)],
        ).createShader(bounds),
    );

    for (final jewel in <Offset>[
      Offset(size.width * .34, size.height * .69),
      Offset(size.width * .50, size.height * .67),
      Offset(size.width * .66, size.height * .69),
    ]) {
      canvas.drawCircle(
        jewel,
        size.width * .026,
        Paint()..color = const Color(0xFFBDF6FF),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
