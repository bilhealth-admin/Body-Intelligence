part of 'food_barcode_scanner_page.dart';

class _ScanFramePainter extends CustomPainter {
  _ScanFramePainter({required this.color, required this.progress})
    : super(repaint: progress);

  final Color color;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = size.shortestSide;
    final frameWidth = (shortest * .78).clamp(220.0, 420.0);
    final frameHeight = frameWidth * .55;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 24),
      width: frameWidth,
      height: frameHeight,
    );

    final overlay = Paint()..color = const Color(0x88000000);
    final cutout = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(cutout, overlay);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(20)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    final beamY = rect.top + 14 + (rect.height - 28) * progress.value;
    final beamRect = Rect.fromLTRB(
      rect.left + 16,
      beamY - 1.5,
      rect.right - 16,
      beamY + 1.5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(beamRect, const Radius.circular(999)),
      Paint()
        ..shader = LinearGradient(
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: .95),
            Colors.white,
            color.withValues(alpha: .95),
            color.withValues(alpha: 0),
          ],
          stops: const [0, .22, .5, .78, 1],
        ).createShader(beamRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.progress != progress;
}
