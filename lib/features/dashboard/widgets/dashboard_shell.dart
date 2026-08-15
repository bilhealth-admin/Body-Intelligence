import 'package:flutter/material.dart';

import 'dashboard_layout_metrics.dart';

/// Owns dashboard-level environment concerns only: background, safe area,
/// scrolling, refresh, viewport padding, and maximum content width.
///
/// This widget deliberately knows nothing about weight, nutrition, hydration,
/// providers, routes, or scientific calculations.
class DashboardShell extends StatelessWidget {
  const DashboardShell({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  final Widget child;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
          /*
          Opacity(
            opacity: dark ? .92 : .075,
            child: Image.asset(
              'assets/images/v10_master/bil_hdr_starfield_master.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: dark
                  ? const RadialGradient(
                      center: Alignment(.12, -.18),
                      radius: 1.2,
                      colors: [
                        Color(0x241E87FF),
                        Color(0x1114C8D8),
                        Color(0x00102235),
                      ],
                    )
                  : const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFF9FCFF),
                        Color(0xFFEAF5FF),
                        Color(0xFFF5FAFF),
                      ],
                      stops: [0, .46, 1],
                    ),
            ),
          ),
          if (!dark) ...[
            const Positioned(
              top: -180,
              left: -120,
              width: 760,
              height: 560,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0x8FCBE7FF), Color(0x00CBEDFF)],
                  ),
                ),
              ),
            ),
            const Positioned(
              top: 140,
              right: -180,
              width: 720,
              height: 620,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0x78D9F5EA), Color(0x00D9F5EA)],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: const _AtmosphericLandscapePainter(),
                  foregroundPainter: const _AtmosphericParticlePainter(),
                ),
              ),
            ),
          ],
          */
          SafeArea(
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final metrics = DashboardLayoutMetrics.resolve(
                    constraints.maxWidth,
                  );
                  final contentWidth =
                      (constraints.maxWidth - (metrics.horizontalPadding * 2))
                          .clamp(0.0, metrics.maxContentWidth)
                          .toDouble();

                  return SingleChildScrollView(
                    key: const Key('dashboard-scroll-view'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      metrics.horizontalPadding,
                      16,
                      metrics.horizontalPadding,
                      constraints.maxWidth < 600 ? 176 : 132,
                    ),
                    child: Center(
                      child: SizedBox(width: contentWidth, child: child),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _AtmosphericLandscapePainter extends CustomPainter {
  const _AtmosphericLandscapePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final horizon = size.height * .28;
    final distant = Path()
      ..moveTo(0, horizon + 85)
      ..cubicTo(
        size.width * .15,
        horizon - 35,
        size.width * .28,
        horizon + 45,
        size.width * .43,
        horizon - 20,
      )
      ..cubicTo(
        size.width * .58,
        horizon - 78,
        size.width * .73,
        horizon + 62,
        size.width,
        horizon - 18,
      )
      ..lineTo(size.width, horizon + 190)
      ..lineTo(0, horizon + 190)
      ..close();
    canvas.drawPath(
      distant,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x2B76B9E8), Color(0x0076B9E8)],
        ).createShader(Rect.fromLTWH(0, horizon - 90, size.width, 280)),
    );

    final near = Path()
      ..moveTo(0, horizon + 150)
      ..cubicTo(
        size.width * .18,
        horizon + 30,
        size.width * .35,
        horizon + 125,
        size.width * .53,
        horizon + 45,
      )
      ..cubicTo(
        size.width * .7,
        horizon - 6,
        size.width * .86,
        horizon + 125,
        size.width,
        horizon + 65,
      )
      ..lineTo(size.width, horizon + 260)
      ..lineTo(0, horizon + 260)
      ..close();
    canvas.drawPath(
      near,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x24B6DAF0), Color(0x00FFFFFF)],
        ).createShader(Rect.fromLTWH(0, horizon, size.width, 280)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ignore: unused_element
class _AtmosphericParticlePainter extends CustomPainter {
  const _AtmosphericParticlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF398BD1).withValues(alpha: .12);
    for (var index = 0; index < 34; index++) {
      final x = (index * 97.0) % size.width;
      final y = (index * 163.0 + 42) % size.height;
      canvas.drawCircle(Offset(x, y), index.isEven ? 1.5 : 1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
