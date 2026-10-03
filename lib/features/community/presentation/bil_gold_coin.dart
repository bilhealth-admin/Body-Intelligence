import 'package:flutter/material.dart';

class BilGoldCoin extends StatelessWidget {
  const BilGoldCoin({this.size = 24, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'BIL Gold',
    child: CustomPaint(
      size: Size.square(size),
      painter: const _BilGoldCoinPainter(),
    ),
  );
}

class _BilGoldCoinPainter extends CustomPainter {
  const _BilGoldCoinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final outer = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.35, -0.4),
        radius: 1.1,
        colors: [
          Color(0xFFFFF1A8),
          Color(0xFFF7C94B),
          Color(0xFFD99A16),
          Color(0xFF9B6510),
        ],
        stops: [0, .38, .72, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, outer);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * .075
      ..color = const Color(0xFFFFE58A).withValues(alpha: .9);
    canvas.drawCircle(center, radius * .78, ring);

    final mark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = size.shortestSide * .11
      ..color = const Color(0xFF70470B);

    final path = Path()
      ..moveTo(size.width * .36, size.height * .3)
      ..lineTo(size.width * .36, size.height * .7)
      ..lineTo(size.width * .56, size.height * .7)
      ..quadraticBezierTo(
        size.width * .7,
        size.height * .7,
        size.width * .7,
        size.height * .57,
      )
      ..quadraticBezierTo(
        size.width * .7,
        size.height * .48,
        size.width * .57,
        size.height * .47,
      )
      ..lineTo(size.width * .36, size.height * .47)
      ..lineTo(size.width * .55, size.height * .47)
      ..quadraticBezierTo(
        size.width * .67,
        size.height * .46,
        size.width * .67,
        size.height * .37,
      )
      ..quadraticBezierTo(
        size.width * .67,
        size.height * .3,
        size.width * .55,
        size.height * .3,
      )
      ..close();
    canvas.drawPath(path, mark);
  }

  @override
  bool shouldRepaint(covariant _BilGoldCoinPainter oldDelegate) => false;
}
