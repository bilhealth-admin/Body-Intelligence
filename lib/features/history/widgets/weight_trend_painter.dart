part of '../history_page.dart';

class _WeightTrendPainter extends CustomPainter {
  const _WeightTrendPainter({
    required this.weights,
    required this.variability,
    required this.showRaw,
    required this.color,
    required this.gridColor,
  });

  final List<double> weights;
  final double? variability;
  final bool showRaw;
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (var index = 0; index <= 3; index++) {
      final y = size.height * index / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (weights.isEmpty) return;
    var minimum = weights.reduce((a, b) => a < b ? a : b);
    var maximum = weights.reduce((a, b) => a > b ? a : b);
    if ((maximum - minimum).abs() < 0.1) {
      minimum -= 0.1;
      maximum += 0.1;
    }
    final smoothed = <double>[
      for (var index = 0; index < weights.length; index++)
        weights
                .sublist(
                  math.max(0, index - 1),
                  math.min(weights.length, index + 2),
                )
                .reduce((a, b) => a + b) /
            (math.min(weights.length, index + 2) - math.max(0, index - 1)),
    ];

    Offset pointFor(int index, double value) {
      final x = weights.length == 1
          ? size.width / 2
          : size.width * index / (weights.length - 1);
      final y =
          size.height - ((value - minimum) / (maximum - minimum)) * size.height;
      return Offset(x, y.clamp(0, size.height));
    }

    if (variability != null && variability! > 0) {
      final band = Path();
      for (var index = 0; index < smoothed.length; index++) {
        final point = pointFor(index, smoothed[index] + variability!);
        index == 0
            ? band.moveTo(point.dx, point.dy)
            : band.lineTo(point.dx, point.dy);
      }
      for (var index = smoothed.length - 1; index >= 0; index--) {
        final point = pointFor(index, smoothed[index] - variability!);
        band.lineTo(point.dx, point.dy);
      }
      band.close();
      canvas.drawPath(band, Paint()..color = color.withValues(alpha: 0.14));
    }
    if (showRaw) {
      final raw = Path();
      for (var index = 0; index < weights.length; index++) {
        final point = pointFor(index, weights[index]);
        index == 0
            ? raw.moveTo(point.dx, point.dy)
            : raw.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        raw,
        Paint()
          ..color = gridColor
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }
    final path = Path();
    for (var index = 0; index < smoothed.length; index++) {
      final point = pointFor(index, smoothed[index]);
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    final line = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, line);
    final point = Paint()..color = color;
    if (showRaw) {
      for (var index = 0; index < weights.length; index++) {
        canvas.drawCircle(pointFor(index, weights[index]), 3, point);
      }
    }
    canvas.drawCircle(pointFor(smoothed.length - 1, smoothed.last), 5, point);
  }

  @override
  bool shouldRepaint(covariant _WeightTrendPainter oldDelegate) =>
      oldDelegate.weights != weights ||
      oldDelegate.variability != variability ||
      oldDelegate.showRaw != showRaw ||
      oldDelegate.color != color ||
      oldDelegate.gridColor != gridColor;
}
