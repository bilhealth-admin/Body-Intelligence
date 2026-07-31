import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/units/measurement_units.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../weight/providers/weight_provider.dart';

class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final arabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final latestWeight = ref.watch(latestWeightProvider);
    final measurementSystem =
        ref.watch(measurementSystemProvider).value ?? MeasurementSystem.metric;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;

        return ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 18 : 24,
                vertical: compact ? 18 : 22,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          Colors.white.withValues(alpha: .11),
                          const Color(0xFF54DAFF).withValues(alpha: .055),
                          const Color(0xFF765DFF).withValues(alpha: .050),
                          Colors.white.withValues(alpha: .018),
                        ]
                      : [
                          Colors.white.withValues(alpha: .88),
                          const Color(0xFFF1F8FF).withValues(alpha: .76),
                          const Color(0xFFE8F5FF).withValues(alpha: .68),
                          Colors.white.withValues(alpha: .80),
                        ],
                ),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: .08)
                      : const Color(0xFFB9D6F1).withValues(alpha: .82),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? const Color(0xFF46D4FF).withValues(alpha: .16)
                        : const Color(0xFF3187D7).withValues(alpha: .18),
                    blurRadius: isDark ? 46 : 42,
                    spreadRadius: isDark ? -14 : -10,
                  ),
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: .28)
                        : const Color(0xFF315D88).withValues(alpha: .14),
                    blurRadius: isDark ? 28 : 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: latestWeight.when(
                loading: () => _Loading(arabic: arabic),
                error: (_, _) => _Error(
                  arabic: arabic,
                  onRetry: () => ref.invalidate(latestWeightProvider),
                ),
                data: (weight) {
                  final hasWeight = weight != null;
                  final value = hasWeight
                      ? UnitConverter.weightFromKg(
                          weight.weight,
                          measurementSystem,
                        ).toStringAsFixed(1)
                      : '—';
                  final unit = UnitConverter.weightUnit(measurementSystem);

                  return compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _BodyCopy(arabic: arabic),
                            const SizedBox(height: 22),
                            _SignalOrb(
                              arabic: arabic,
                              hasWeight: hasWeight,
                              value: value,
                              unit: unit,
                            ),
                            const SizedBox(height: 12),
                            _SignalMeaning(
                              arabic: arabic,
                              hasWeight: hasWeight,
                            ),
                          ],
                        )
                      : Directionality(
                          textDirection: arabic
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          child: Row(
                            children: [
                              Expanded(
                                flex: 7,
                                child: _BodyCopy(arabic: arabic),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 4,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _SignalOrb(
                                      arabic: arabic,
                                      hasWeight: hasWeight,
                                      value: value,
                                      unit: unit,
                                    ),
                                    const SizedBox(height: 12),
                                    _SignalMeaning(
                                      arabic: arabic,
                                      hasWeight: hasWeight,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BodyCopy extends StatelessWidget {
  const _BodyCopy({required this.arabic});

  final bool arabic;

  String tr(String en, String ar) => arabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MetalText(
            tr("Today's Signal", 'إشارة اليوم'),
            size: 30,
            weight: FontWeight.w900,
          ),
        ],
      ),
    );
  }
}

class _SignalMeaning extends StatelessWidget {
  const _SignalMeaning({required this.arabic, required this.hasWeight});

  final bool arabic;
  final bool hasWeight;

  String tr(String en, String ar) => arabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return _InsightGlass(
      icon: hasWeight
          ? Icons.psychology_alt_outlined
          : Icons.monitor_weight_outlined,
      title: hasWeight
          ? tr('What this signal means', 'ماذا تعني هذه الإشارة؟')
          : tr('The best next step', 'أفضل خطوة تالية'),
      body: hasWeight
          ? tr(
              'BIL will not claim a trend until comparable measurements provide enough evidence.',
              'لن يدّعي BIL وجود اتجاه قبل توفر قياسات قابلة للمقارنة وأدلة كافية.',
            )
          : tr(
              'Record one trusted daily measurement to begin your private baseline.',
              'سجّل قياسًا يوميًا موثوقًا لبدء خط أساسك الخاص.',
            ),
    );
  }
}

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
      dimension: 220,
      child: CustomPaint(
        painter: const _PremiumSignalRingPainter(),
        child: Center(
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: 154,
                height: 154,
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
                    const Text(
                      'BIL®',
                      style: TextStyle(
                        color: Color(0xFFDCE7EE),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .4,
                      ),
                    ),
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
                                  fontSize: 36,
                                  height: 1,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.4,
                                ),
                              ),
                              if (hasWeight)
                                TextSpan(
                                  text: ' $unit',
                                  style: const TextStyle(
                                    color: Color(0xFFC2D0DA),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                            ],
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasWeight
                          ? (arabic ? 'إشارة اليوم' : 'Today signal')
                          : (arabic ? 'جاهز للبدء' : 'Ready to begin'),
                      style: const TextStyle(
                        color: Color(0xFF9FB1BF),
                        fontSize: 11,
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
                _MetalText(title, size: 15, weight: FontWeight.w900),
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

class _Loading extends StatelessWidget {
  const _Loading({required this.arabic});

  final bool arabic;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MetalText(
          arabic ? 'نجهّز ملخصك اليومي' : 'Preparing your daily brief',
          size: 25,
          weight: FontWeight.w900,
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
          weight: FontWeight.w900,
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
            label: Text(arabic ? 'إعادة المحاولة' : 'Retry'),
          ),
        ),
      ],
    );
  }
}
