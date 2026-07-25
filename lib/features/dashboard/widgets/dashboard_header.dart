import 'dart:ui';

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
                      : const [
                          Color(0xFFE1EEF2),
                          Color(0xFFD2E5EB),
                          Color(0xFFDCE8EE),
                          Color(0xFFE8F1F3),
                        ],
                ),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: .08)
                      : const Color(0xFF55798A).withValues(alpha: .30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? const Color(0xFF46D4FF).withValues(alpha: .16)
                        : const Color(0xFF315E73).withValues(alpha: .16),
                    blurRadius: isDark ? 46 : 32,
                    spreadRadius: isDark ? -14 : -10,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? .28 : .12),
                    blurRadius: isDark ? 28 : 24,
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
                            _BodyCopy(arabic: arabic, hasWeight: hasWeight),
                            const SizedBox(height: 22),
                            _SignalOrb(
                              arabic: arabic,
                              hasWeight: hasWeight,
                              value: value,
                              unit: unit,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              flex: 7,
                              child: _BodyCopy(
                                arabic: arabic,
                                hasWeight: hasWeight,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 4,
                              child: _SignalOrb(
                                arabic: arabic,
                                hasWeight: hasWeight,
                                value: value,
                                unit: unit,
                              ),
                            ),
                          ],
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
  const _BodyCopy({required this.arabic, required this.hasWeight});

  final bool arabic;
  final bool hasWeight;

  String tr(String en, String ar) => arabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bodyColor = isDark
        ? const Color(0xFFB8C5D1)
        : const Color(0xFF294858);
    return Directionality(
      textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              const _GlassBadge(
                icon: Icons.lock_outline_rounded,
                labelEn: 'Local only',
                labelAr: 'محفوظ محليًا',
              ),
              _GlassBadge(
                icon: hasWeight
                    ? Icons.verified_outlined
                    : Icons.add_circle_outline_rounded,
                labelEn: hasWeight ? 'Latest trusted signal' : 'Starting point',
                labelAr: hasWeight ? 'أحدث إشارة موثوقة' : 'نقطة البداية',
              ),
            ],
          ),
          const SizedBox(height: 22),
          _MetalText(
            tr(
              'Your body intelligence, distilled for today',
              'ذكاء جسمك، مُلخّص لليوم',
            ),
            size: 30,
            weight: FontWeight.w900,
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              'A calm view of what matters now, why it matters, and the next useful action.',
              'نظرة هادئة لما يهم الآن، ولماذا يهم، والخطوة التالية الأكثر فائدة.',
            ),
            style: TextStyle(
              color: bodyColor,
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          _InsightGlass(
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
          ),
        ],
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
    return Align(
      child: SizedBox.square(
        dimension: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF51DCFF).withValues(alpha: .20),
                    const Color(0xFF765DFF).withValues(alpha: .09),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Container(
              width: 176,
              height: 176,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    Color(0xFF90A2B3),
                    Color(0xFFF5F8FA),
                    Color(0xFF59D9FF),
                    Color(0xFF846CFF),
                    Color(0xFF90A2B3),
                  ],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x704AD9FF),
                    blurRadius: 36,
                    spreadRadius: -8,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(2),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xDB07111D),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'BIL®',
                      style: TextStyle(
                        color: Color(0xFFE9EFF4),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasWeight ? value : '—',
                      style: const TextStyle(
                        color: Color(0xFFF5F8FA),
                        fontSize: 38,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (hasWeight)
                      Text(
                        unit,
                        style: const TextStyle(
                          color: Color(0xFFB7C5D1),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    const SizedBox(height: 5),
                    Text(
                      hasWeight
                          ? (arabic ? 'إشارة اليوم' : 'Today signal')
                          : (arabic ? 'جاهز للبدء' : 'Ready to begin'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFB7C5D1),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassBadge extends StatelessWidget {
  const _GlassBadge({
    required this.icon,
    required this.labelEn,
    required this.labelAr,
  });

  final IconData icon;
  final String labelEn;
  final String labelAr;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark
        ? const Color(0xFFD0DAE3)
        : const Color(0xFF173B4D);

    final arabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        gradient: LinearGradient(
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: .095),
                  const Color(0xFF51D8FF).withValues(alpha: .034),
                ]
              : const [Color(0xFFD3E5EA), Color(0xFFC9DFE7)],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: .06)
              : const Color(0xFF55798A).withValues(alpha: .28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 7),
          Text(
            arabic ? labelAr : labelEn,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
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
              : const Color(0xFF55798A).withValues(alpha: .24),
        ),
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
