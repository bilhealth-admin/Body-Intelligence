import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../auth/auth_five_locale_copy.dart';

/// Presentation-only flagship splash. Startup state and routing remain owned by
/// [StartupPage].
class PremiumSplashBackdrop extends StatelessWidget {
  const PremiumSplashBackdrop({this.animate = true, super.key});

  /// Keeps the ambient background alive only while startup is actively
  /// loading. Error states are deliberately static so they remain calm,
  /// accessible, and do not schedule frames forever.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          _LivingSplashImage(animate: animate),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x26000512),
                  Color(0x38000512),
                  Color(0xB8000612),
                ],
                stops: [0, .55, 1],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -.12),
                radius: .82,
                colors: [
                  Color(highContrast ? 0x52087CA4 : 0x2E196E9C),
                  const Color(0x1409213C),
                  const Color(0xBA01050D),
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

class _LivingSplashImage extends StatefulWidget {
  const _LivingSplashImage({required this.animate});

  final bool animate;

  @override
  State<_LivingSplashImage> createState() => _LivingSplashImageState();
}

class _LivingSplashImageState extends State<_LivingSplashImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _LivingSplashImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _syncAnimation();
  }

  void _syncAnimation() {
    final shouldAnimate =
        widget.animate &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (shouldAnimate) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop(canceled: false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final image = Image.asset(
      'assets/images/brand/generated/bil_body_twin_splash_v1.png',
      fit: BoxFit.cover,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => Image.asset(
        'assets/images/v10_master/bil_hdr_starfield_master.png',
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF01050D)),
      ),
    );
    if (reducedMotion || !widget.animate) return image;
    return AnimatedBuilder(
      animation: _controller,
      child: image,
      builder: (context, child) {
        final pulse = Curves.easeInOut.transform(_controller.value);
        return Transform.translate(
          offset: Offset(0, -3 + pulse * 6),
          child: Transform.scale(scale: 1.018 + pulse * .012, child: child),
        );
      },
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
      label: authFiveLocaleTextFor(
        arabicLocaleCode(context, arabic),
        'BIL is preparing your local data safely',
        'يُجهّز BIL بياناتك المحلية بأمان',
      ),
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
          const Spacer(flex: 3),
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
          const Spacer(flex: 6),
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
      child: SizedBox.square(dimension: size),
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
          'BODY INTELLIGENCE LOG™',
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
