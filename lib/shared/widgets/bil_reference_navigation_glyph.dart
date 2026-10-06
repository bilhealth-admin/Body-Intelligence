import 'package:flutter/material.dart';

/// Native vector strokes measured against the approved Coach dock. A glyph's
/// small optical bounds do not reduce the enclosing navigation tap target.
class BilReferenceNavigationGlyph extends StatelessWidget {
  const BilReferenceNavigationGlyph({
    required this.destination,
    required this.color,
    this.selected = false,
    super.key,
  });

  final int destination;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _ReferenceNavigationPainter(destination, color, selected),
  );
}

class _ReferenceNavigationPainter extends CustomPainter {
  const _ReferenceNavigationPainter(
    this.destination,
    this.color,
    this.selected,
  );

  final int destination;
  final Color color;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    switch (destination) {
      case 0:
        final roof = Path()
          ..moveTo(1.8, 10.2)
          ..lineTo(12, 1.5)
          ..lineTo(22.2, 10.2);
        final house = Path()
          ..moveTo(4.7, 9.7)
          ..lineTo(4.7, 22)
          ..lineTo(9.5, 22)
          ..lineTo(9.5, 15)
          ..lineTo(14.5, 15)
          ..lineTo(14.5, 22)
          ..lineTo(19.3, 22)
          ..lineTo(19.3, 9.7);
        canvas.drawPath(roof, stroke);
        canvas.drawPath(house, stroke);
      case 1:
        final bubble = Path()
          ..moveTo(6, 19)
          ..cubicTo(2.9, 17.4, 1, 14.7, 1, 11)
          ..cubicTo(1, 5.1, 5.9, 1.3, 12, 1.3)
          ..cubicTo(18.1, 1.3, 23, 5.1, 23, 11)
          ..cubicTo(23, 16.9, 18.1, 20.7, 12, 20.7)
          ..cubicTo(10.8, 20.7, 9.6, 20.6, 8.5, 20.2)
          ..lineTo(4.7, 23)
          ..close();
        canvas.drawPath(bubble, selected ? fill : stroke);
        final dots = Paint()
          ..color = selected ? const Color(0xFFE2F0FF) : color;
        for (final x in [7.0, 12.0, 17.0]) {
          canvas.drawCircle(Offset(x, 11), .9, dots);
        }
      case 2:
        stroke.strokeWidth = 2.4;
        canvas.drawLine(const Offset(12, 1.2), const Offset(12, 22.8), stroke);
        canvas.drawLine(const Offset(1.2, 12), const Offset(22.8, 12), stroke);
      case 3:
        canvas.drawCircle(const Offset(12, 5.1), 2.7, stroke);
        canvas.drawCircle(const Offset(4.3, 8.1), 2, stroke);
        canvas.drawCircle(const Offset(19.7, 8.1), 2, stroke);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(6.6, 12, 10.8, 8.1),
            const Radius.circular(3.2),
          ),
          stroke,
        );
        for (final right in [false, true]) {
          final outer = Path()
            ..moveTo(right ? 19.3 : 4.7, 13.4)
            ..cubicTo(
              right ? 22.8 : 1.2,
              13.4,
              right ? 23.2 : .8,
              15.6,
              right ? 23.2 : .8,
              18.7,
            )
            ..lineTo(right ? 19.8 : 4.2, 18.7);
          canvas.drawPath(outer, stroke);
        }
      case 4:
        for (final x in [4.0, 12.0, 20.0]) {
          canvas.drawCircle(Offset(x, 12), 1.6, fill);
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ReferenceNavigationPainter oldDelegate) =>
      destination != oldDelegate.destination ||
      color != oldDelegate.color ||
      selected != oldDelegate.selected;
}
