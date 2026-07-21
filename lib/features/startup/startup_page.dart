import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class StartupPage extends StatefulWidget {
  const StartupPage({super.key});

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..forward();

    timer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        context.go('/onboarding');
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  double _unitInterval(double value) => value.clamp(0.0, 1.0).toDouble();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF01050D),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/v10_master/bil_hdr_starfield_master.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: .78,
                colors: [
                  Color(0x382A8CFF),
                  Color(0x1817CDE4),
                  Color(0x0001050D),
                ],
              ),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                final v = _unitInterval(controller.value);

                final fadeInProgress = _unitInterval(v / .18);
                final fadeOutProgress = _unitInterval((v - .82) / .18);
                final scaleProgress = _unitInterval(v / .28);

                final opacity = v < .18
                    ? Curves.easeOutCubic.transform(fadeInProgress)
                    : v > .82
                    ? 1.0 - Curves.easeInCubic.transform(fadeOutProgress)
                    : 1.0;

                final scale =
                    .90 + .10 * Curves.easeOutCubic.transform(scaleProgress);

                return Opacity(
                  opacity: _unitInterval(opacity),
                  child: Transform.scale(scale: scale, child: child),
                );
              },
              child: const _SplashBrand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashBrand extends StatelessWidget {
  const _SplashBrand();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFE4EAF0),
              Color(0xFF91A0AE),
              Color(0xFFFFFFFF),
            ],
          ).createShader(rect),
          child: const Text(
            'BIL®',
            style: TextStyle(
              color: Colors.white,
              fontSize: 132,
              height: .86,
              fontWeight: FontWeight.w900,
              letterSpacing: -6,
              shadows: [
                Shadow(color: Color(0x805BD8FF), blurRadius: 40),
                Shadow(color: Color(0x60795EFF), blurRadius: 62),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'BODY INTELLIGENCE LOG',
          style: TextStyle(
            color: Color(0xFFD9E3EC),
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 6,
            shadows: [Shadow(color: Color(0x505ACBFF), blurRadius: 14)],
          ),
        ),
      ],
    );
  }
}
