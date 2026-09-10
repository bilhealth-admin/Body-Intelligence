part of 'live_health_watch.dart';

class _WatchPainter extends CustomPainter {
  const _WatchPainter({
    required this.hour,
    required this.minute,
    required this.second,
  });

  final int hour;
  final int minute;
  final int second;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final unit = size.shortestSide;

    final shell = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        unit * .032,
        unit * .032,
        size.width - unit * .086,
        size.height - unit * .064,
      ),
      Radius.circular(unit * .22),
    );

    canvas.drawRRect(
      shell.shift(Offset(0, unit * .018)),
      Paint()
        ..color = Colors.black.withValues(alpha: .34)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * .035),
    );

    canvas.drawRRect(
      shell,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF07131B),
            Color(0xFF163442),
            Color(0xFF0B202C),
            Color(0xFF050D13),
          ],
          stops: [0, .33, .68, 1],
        ).createShader(rect),
    );

    final bezel = shell.deflate(unit * .018);
    canvas.drawRRect(
      bezel,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF071017), Color(0xFF142A35), Color(0xFF050A0F)],
          stops: [0, .48, 1],
        ).createShader(rect),
    );

    final screen = bezel.deflate(unit * .021);
    canvas.drawRRect(
      screen,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF102D42), Color(0xFF081A29), Color(0xFF030B12)],
          stops: [0, .52, 1],
        ).createShader(screen.outerRect),
    );

    canvas.drawRRect(
      screen,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * .008
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC2A586A), Color(0x332E6678), Color(0xFF05090C)],
        ).createShader(rect),
    );

    final crownCenter = Offset(size.width - unit * .035, size.height * .37);
    final crownShadow = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: crownCenter + Offset(-unit * .004, unit * .008),
        width: unit * .060,
        height: unit * .145,
      ),
      Radius.circular(unit * .025),
    );
    canvas.drawRRect(
      crownShadow,
      Paint()
        ..color = Colors.black.withValues(alpha: .34)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * .014),
    );

    final crown = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: crownCenter,
        width: unit * .056,
        height: unit * .138,
      ),
      Radius.circular(unit * .024),
    );
    canvas.drawRRect(
      crown,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF0B161D),
            Color(0xFF294653),
            Color(0xFF4F7481),
            Color(0xFF1B323D),
            Color(0xFF355764),
            Color(0xFF091219),
          ],
          stops: [0, .18, .36, .58, .78, 1],
        ).createShader(crown.outerRect),
    );
    canvas.drawRRect(
      crown,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFF1A2024),
    );

    for (var i = -5; i <= 5; i++) {
      final y = crownCenter.dy + i * unit * .0105;
      canvas.drawLine(
        Offset(crown.left + unit * .008, y),
        Offset(crown.right - unit * .007, y),
        Paint()
          ..color = i.isEven
              ? const Color(0xFF527786).withValues(alpha: .72)
              : Colors.black.withValues(alpha: .48)
          ..strokeWidth = .85,
      );
    }

    final glass = Path()
      ..moveTo(screen.left + unit * .032, screen.top + unit * .018)
      ..quadraticBezierTo(
        screen.center.dx,
        screen.top - unit * .012,
        screen.right - unit * .038,
        screen.top + unit * .072,
      )
      ..lineTo(screen.right - unit * .145, screen.center.dy - unit * .020)
      ..quadraticBezierTo(
        screen.center.dx,
        screen.top + unit * .065,
        screen.left + unit * .040,
        screen.top + unit * .145,
      )
      ..close();
    canvas.drawPath(
      glass,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF65CDE2).withValues(alpha: .18),
            const Color(0xFF65CDE2).withValues(alpha: .045),
            const Color(0xFF65CDE2).withValues(alpha: 0),
          ],
          stops: const [0, .42, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _WatchPainter oldDelegate) =>
      oldDelegate.hour != hour ||
      oldDelegate.minute != minute ||
      oldDelegate.second != second;
}
