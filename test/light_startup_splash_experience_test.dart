import 'package:body_intelligence_log/features/startup/light_startup_splash_experience.dart';
import 'package:body_intelligence_log/shared/widgets/bil_wordmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('light startup identity reveals the complete product name', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const _LightSplashHarness());
    await tester.pump(const Duration(milliseconds: 2200));

    expect(find.byKey(const ValueKey('startup-full-wordmark')), findsOneWidget);
    expect(find.byType(BilWordmark), findsOneWidget);
    expect(
      find.byKey(const ValueKey('light-startup-background-image')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion renders the final light frame immediately', (
    tester,
  ) async {
    await tester.pumpWidget(const _LightSplashHarness(reducedMotion: true));
    await tester.pump();

    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, .5);
    expect(find.byKey(const ValueKey('startup-full-wordmark')), findsOneWidget);
    expect(find.byType(BilWordmark), findsOneWidget);
  });

  testWidgets('light identity remains usable in RTL with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const _LightSplashHarness(
        locale: Locale('ar'),
        textScaler: TextScaler.linear(2),
      ),
    );
    await tester.pump(const Duration(milliseconds: 2200));

    expect(find.byKey(const ValueKey('startup-full-wordmark')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _LightSplashHarness extends StatefulWidget {
  const _LightSplashHarness({
    this.locale = const Locale('en'),
    this.reducedMotion = false,
    this.textScaler = TextScaler.noScaling,
  });

  final Locale locale;
  final bool reducedMotion;
  final TextScaler textScaler;

  @override
  State<_LightSplashHarness> createState() => _LightSplashHarnessState();
}

class _LightSplashHarnessState extends State<_LightSplashHarness>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: widget.locale,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: widget.reducedMotion,
            textScaler: widget.textScaler,
          ),
          child: Scaffold(
            backgroundColor: const Color(0xFFF8FBFE),
            body: Stack(
              fit: StackFit.expand,
              children: [
                LightStartupSplashBackdrop(controller: controller),
                Center(
                  child: LightStartupSplashExperience(
                    controller: controller,
                    arabic: widget.locale.languageCode == 'ar',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
