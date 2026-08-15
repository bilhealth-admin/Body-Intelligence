import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../shared/widgets/bil_wordmark.dart';
import '../auth/auth_five_locale_copy.dart';

/// The light, presentation-only startup identity.
///
/// Startup state, the minimum display window, and routing remain owned by the
/// startup page. Every visual frame is derived from the supplied controller,
/// so seeking, tests, and reduced-motion rendering are deterministic.
class LightStartupSplashBackdrop extends StatelessWidget {
  const LightStartupSplashBackdrop({
    required this.controller,
    this.animate = true,
    super.key,
  });

  final AnimationController controller;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (!animate || reducedMotion) return _frame(context, 1);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _frame(context, controller.value),
    );
  }

  Widget _frame(BuildContext context, double progress) {
    final reveal = Curves.easeOutCubic.transform((progress / .24).clamp(0, 1));
    return RepaintBoundary(
      child: ColoredBox(
        color: const Color(0xFF050505),
        child: Opacity(
          key: const ValueKey('light-startup-background-reveal'),
          opacity: reveal,
          child: const DecoratedBox(
            key: ValueKey('light-startup-background-image'),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -.12),
                radius: 1.08,
                stops: [0, .38, .72, 1],
                colors: [
                  Color(0xFF0B1722),
                  Color(0xFF05090D),
                  Color(0xFF020304),
                  Color(0xFF000000),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LightStartupSplashExperience extends StatelessWidget {
  const LightStartupSplashExperience({
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
      container: true,
      liveRegion: true,
      label: authFiveLocaleTextFor(
        arabicLocaleCode(context, arabic),
        'Body Intelligence Log is preparing your local data safely',
        'بودي إنتليجنس لوج يجهّز بياناتك المحلية بأمان',
      ),
      child: ExcludeSemantics(
        child: reducedMotion
            ? const _LightSplashComposition(progress: 1, indicatorValue: .5)
            : AnimatedBuilder(
                animation: controller,
                builder: (context, _) => _LightSplashComposition(
                  progress: controller.value,
                  indicatorValue: controller.value,
                ),
              ),
      ),
    );
  }
}

class _LightSplashComposition extends StatelessWidget {
  const _LightSplashComposition({
    required this.progress,
    required this.indicatorValue,
  });

  final double progress;
  final double indicatorValue;

  double _stage(double begin, double end) => Curves.easeOutCubic.transform(
    ((progress - begin) / (end - begin)).clamp(0, 1),
  );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final availableWidth = math.max(0.0, size.width - 48);
    final availableHeight = math.max(0.0, size.height - 64);
    final titleWidth = math.min(availableWidth, 760.0);
    final titleSize = math
        .min(titleWidth * .060, availableHeight * .060)
        .clamp(18.0, 42.0);
    final highContrast = media.highContrast;

    return SafeArea(
      minimum: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: titleWidth),
              child: _SplashName(
                titleSize: titleSize,
                reveal: _stage(.10, .34),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: math.min(size.width * .32, 148),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: highContrast ? 3 : 2,
                  value: indicatorValue,
                  backgroundColor: const Color(0x33FFFFFF),
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashName extends StatelessWidget {
  const _SplashName({
    required this.titleSize,
    required this.reveal,
  });

  final double titleSize;
  final double reveal;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Opacity(
        key: const ValueKey('startup-full-wordmark'),
        opacity: reveal,
        child: BilWordmark(
          height: math.min(titleSize * 1.72, 66),
          color: Colors.white,
        ),
      ),
    );
  }
}
