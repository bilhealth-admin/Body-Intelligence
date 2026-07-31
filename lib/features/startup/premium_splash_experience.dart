import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Presentation-only flagship splash. Startup state and routing remain owned by
/// [StartupPage].
class PremiumSplashBackdrop extends StatelessWidget {
  const PremiumSplashBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/v10_master/bil_hdr_starfield_master.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Color(0xFF01050D)),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -.12),
                radius: .82,
                colors: [
                  Color(highContrast ? 0x4D087CA4 : 0x33196E9C),
                  const Color(0x1A09213C),
                  const Color(0xF201050D),
                ],
                stops: const [0, .48, 1],
              ),
            ),
          ),
          const CustomPaint(painter: _DepthStarsPainter()),
        ],
      ),
    );
  }
}

class PremiumSplashExperience extends StatelessWidget {
  const PremiumSplashExperience({
    required this.controller,
    required this.arabic,
    super.key,
  });

  final AnimationController controller;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      liveRegion: true,
      label: arabic
          ? 'يُجهّز BIL بياناتك المحلية بأمان'
          : 'BIL is preparing your local data safely',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => _Composition(
            progress: reducedMotion ? 1 : controller.value,
            indicatorValue: reducedMotion ? .5 : controller.value,
          ),
        ),
      ),
    );
  }
}

class _Composition extends StatelessWidget {
  const _Composition({required this.progress, required this.indicatorValue});

  final double progress;
  final double indicatorValue;

  double stage(double begin, double end) => Curves.easeInOutCubic.transform(
    ((progress - begin) / (end - begin)).clamp(0, 1),
  );

  @override
  Widget build(BuildContext context) {
    final approach = stage(.08, .56);
    final reveal = stage(.44, .76);
    final nameReveal = stage(.68, .94);
    final starOpacity = 1 - stage(.42, .66);
    final media = MediaQuery.of(context);
    final highContrast = media.highContrast;
    final markSize = math.min(media.size.shortestSide * .36, 152.0);

    return SafeArea(
      minimum: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        children: [
          const Spacer(flex: 4),
          SizedBox(
            width: markSize * 1.9,
            height: markSize * 1.5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: starOpacity,
                  child: Transform.scale(
                    scale: .42 + approach * .8,
                    child: CustomPaint(
                      size: Size.square(markSize),
                      painter: _HeroStarPainter(
                        pulse: .5 + math.sin(progress * math.pi * 5).abs() * .5,
                        highContrast: highContrast,
                      ),
                    ),
                  ),
                ),
                Opacity(
                  opacity: reveal,
                  child: Transform.scale(
                    scale: .88 + reveal * .12,
                    child: _BilMark(size: markSize),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Opacity(
            opacity: nameReveal,
            child: Transform.translate(
              offset: Offset(0, 8 * (1 - nameReveal)),
              child: const _BilName(),
            ),
          ),
          const Spacer(flex: 5),
          SizedBox(
            width: math.min(media.size.width * .38, 164),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 2,
                value: indicatorValue,
                backgroundColor: const Color(0x1FFFFFFF),
                color: highContrast ? Colors.white : const Color(0xFF62DDF4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BilMark extends StatelessWidget {
  const _BilMark({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(highContrast ? 0x665FE6FF : 0x405BD8FF),
            blurRadius: 42,
            spreadRadius: 8,
          ),
          const BoxShadow(color: Color(0x246F61FF), blurRadius: 70),
        ],
      ),
      child: SizedBox.square(
        dimension: size,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'BIL®',
            maxLines: 1,
            style: TextStyle(
              color: highContrast ? Colors.white : const Color(0xFFF4F7FA),
              fontSize: 92,
              height: .9,
              fontWeight: FontWeight.w900,
              letterSpacing: -5,
              shadows: const [
                Shadow(color: Color(0x805BD8FF), blurRadius: 28),
                Shadow(color: Color(0x40795EFF), blurRadius: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BilName extends StatelessWidget {
  const _BilName();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'BODY INTELLIGENCE LOG',
          maxLines: 1,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MediaQuery.highContrastOf(context)
                ? Colors.white
                : const Color(0xFFDCE7EF),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 4,
          ),
        ),
      ),
    );
  }
}

class _DepthStarsPainter extends CustomPainter {
  const _DepthStarsPainter();
  static const stars = <Offset>[
    Offset(.08, .16),
    Offset(.17, .71),
    Offset(.25, .29),
    Offset(.34, .82),
    Offset(.43, .12),
    Offset(.54, .73),
    Offset(.62, .24),
    Offset(.71, .88),
    Offset(.79, .18),
    Offset(.87, .62),
    Offset(.94, .34),
    Offset(.13, .46),
    Offset(.38, .56),
    Offset(.66, .52),
    Offset(.91, .79),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var index = 0; index < stars.length; index++) {
      final star = stars[index];
      canvas.drawCircle(
        Offset(star.dx * size.width, star.dy * size.height),
        index % 3 == 0 ? 1.15 : .65,
        Paint()
          ..color = Colors.white.withValues(alpha: index % 4 == 0 ? .68 : .34),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DepthStarsPainter oldDelegate) => false;
}

class _HeroStarPainter extends CustomPainter {
  const _HeroStarPainter({required this.pulse, required this.highContrast});
  final double pulse;
  final bool highContrast;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * (.055 + pulse * .012);
    canvas.drawCircle(
      center,
      radius * 6,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: highContrast ? 1 : .94),
            const Color(0xFF69E6FF).withValues(alpha: .58),
            const Color(0x0069E6FF),
          ],
          stops: const [0, .2, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 6)),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = highContrast ? Colors.white : const Color(0xFFE8FBFF),
    );
    final ray = Paint()
      ..color = const Color(0xFFB9F5FF).withValues(alpha: .45)
      ..strokeWidth = .8;
    canvas.drawLine(
      center.translate(-radius * 4.6, 0),
      center.translate(radius * 4.6, 0),
      ray,
    );
    canvas.drawLine(
      center.translate(0, -radius * 4.6),
      center.translate(0, radius * 4.6),
      ray,
    );
  }

  @override
  bool shouldRepaint(covariant _HeroStarPainter oldDelegate) =>
      pulse != oldDelegate.pulse || highContrast != oldDelegate.highContrast;
}
