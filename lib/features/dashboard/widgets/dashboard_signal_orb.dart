part of 'dashboard_header.dart';

// Retained as the compact measured-signal variant for the next dashboard
// composition; the current header selects the guide orb.
// ignore: unused_element
class _SignalOrb extends StatelessWidget {
  const _SignalOrb({
    required this.arabic,
    required this.hasWeight,
    required this.value,
    required this.unit,
  });

  final bool arabic;
  final bool hasWeight;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final ring = SizedBox.square(
      dimension: 184,
      child: CustomPaint(
        painter: const _PremiumSignalRingPainter(),
        child: Center(
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: .11),
                      const Color(0xFF0B1725).withValues(alpha: .84),
                      const Color(0xFF050B15).withValues(alpha: .92),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4AD9FF).withValues(alpha: .18),
                      blurRadius: 28,
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const BilWordmark(height: 15),
                    const SizedBox(height: 7),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: hasWeight ? value : '—',
                                style: const TextStyle(
                                  color: Color(0xFFF8FBFD),
                                  fontSize: 32,
                                  height: 1,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -1.4,
                                ),
                              ),
                              if (hasWeight)
                                TextSpan(
                                  text: ' $unit',
                                  style: const TextStyle(
                                    color: Color(0xFFC2D0DA),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      hasWeight
                          ? (arabic
                                ? 'آخر قياس موثوق'
                                : 'Latest trusted reading')
                          : dashboardFiveLocaleText(
                              'Ready to begin',
                              'جاهز للبدء',
                            ),
                      style: const TextStyle(
                        color: Color(0xFF9FB1BF),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Align(
      child: reducedMotion
          ? ring
          : TweenAnimationBuilder<double>(
              tween: Tween(begin: .94, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Transform.scale(
                scale: value,
                child: Opacity(opacity: value, child: child),
              ),
              child: ring,
            ),
    );
  }
}

class _PremiumSignalRingPainter extends CustomPainter {
  const _PremiumSignalRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = Rect.fromCircle(center: center, radius: size.width * .44);
    final middle = outer.deflate(9);
    final inner = middle.deflate(8);

    canvas.drawOval(
      outer.shift(const Offset(0, 10)),
      Paint()
        ..color = Colors.black.withValues(alpha: .30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    canvas.drawArc(
      outer,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..shader = const SweepGradient(
          colors: [
            Color(0xFF5E6870),
            Color(0xFFEFF3F5),
            Color(0xFF8E9BA3),
            Color(0xFFFFFFFF),
            Color(0xFF747F86),
            Color(0xFFD7DEE2),
            Color(0xFF566168),
          ],
          stops: [0, .14, .31, .48, .66, .83, 1],
        ).createShader(outer),
    );

    canvas.drawArc(
      middle,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..shader = const SweepGradient(
          colors: [
            Color(0xFF25313A),
            Color(0xFFAAB6BE),
            Color(0xFF3A4650),
            Color(0xFFEAF0F3),
            Color(0xFF26323B),
          ],
        ).createShader(middle),
    );

    canvas.drawArc(
      inner,
      math.pi * 1.02,
      math.pi * .76,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.4
        ..color = Colors.white.withValues(alpha: .80),
    );

    canvas.drawArc(
      outer.inflate(1.5),
      -.72,
      1.30,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: .28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    canvas.drawArc(
      outer,
      2.1,
      1.15,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF8FA1AC).withValues(alpha: .38),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InsightGlass extends StatelessWidget {
  const _InsightGlass({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bodyColor = isDark
        ? const Color(0xFFB4C1CD)
        : const Color(0xFF294858);
    final iconColor = isDark
        ? const Color(0xFFDDE6ED)
        : const Color(0xFF123D52);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: .075),
                  const Color(0xFF58D9FF).withValues(alpha: .032),
                  Colors.white.withValues(alpha: .018),
                ]
              : const [Color(0xFFCEE2E8), Color(0xFFD8E9ED), Color(0xFFC7DDE5)],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: .05)
              : const Color(0xFF7E8C95).withValues(alpha: .42),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF53616A).withValues(alpha: .16),
            blurRadius: 18,
            spreadRadius: -7,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        Colors.white.withValues(alpha: .12),
                        const Color(0xFF58D9FF).withValues(alpha: .06),
                      ]
                    : const [Color(0xFFBBD9E2), Color(0xFFC8E1E8)],
              ),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetalText(title, size: 15, weight: FontWeight.w700),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: TextStyle(
                    color: bodyColor,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetalText extends StatelessWidget {
  const _MetalText(this.text, {required this.size, required this.weight});

  final String text;
  final double size;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.light) {
      return Text(
        text,
        style: TextStyle(
          color: const Color(0xFF071D2D),
          fontSize: size,
          height: 1.14,
          fontWeight: weight,
        ),
      );
    }

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFDCE5EC),
          Color(0xFF91A0AE),
          Color(0xFFF5F8FA),
        ],
      ).createShader(rect),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: size,
          height: 1.14,
          fontWeight: weight,
        ),
      ),
    );
  }
}

// ignore: unused_element
class _Loading extends StatelessWidget {
  const _Loading({required this.arabic});

  final bool arabic;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MetalText(
          dashboardFiveLocaleText(
            'Preparing your daily brief',
            'نجهّز ملخصك اليومي',
          ),
          size: 25,
          weight: FontWeight.w700,
        ),
        const SizedBox(height: 18),
        const LinearProgressIndicator(
          minHeight: 7,
          color: Color(0xFFE5ECF2),
          backgroundColor: Color(0x35495E72),
        ),
      ],
    );
  }
}

// ignore: unused_element
class _Error extends StatelessWidget {
  const _Error({required this.arabic, required this.onRetry});

  final bool arabic;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MetalText(
          arabic
              ? 'تعذر تحميل أحدث بيانات الجسم'
              : 'Could not load the latest body signal',
          size: 24,
          weight: FontWeight.w700,
        ),
        const SizedBox(height: 12),
        Text(
          arabic
              ? 'بقيت بياناتك المحلية آمنة. حاول إعادة القراءة.'
              : 'Your local data remains safe. Try reading it again.',
          style: const TextStyle(color: Color(0xFFB7C4D0)),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(dashboardFiveLocaleText('Retry', 'إعادة المحاولة')),
          ),
        ),
      ],
    );
  }
}
