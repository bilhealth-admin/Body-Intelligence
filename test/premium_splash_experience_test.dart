import 'package:body_intelligence_log/features/startup/premium_splash_experience.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('NotoNaskhArabic')
      ..addFont(rootBundle.load('assets/fonts/NotoNaskhArabic-Bold.ttf'));
    await font.load();
  });

  testWidgets('2026 splash exposes the full identity without loading chrome', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const _SplashHarness());
    await tester.pump();

    expect(find.text('BIL'), findsNothing);
    expect(
      find.byKey(const ValueKey('premium-splash-wordmark')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('premium-splash-loading-label')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('premium-splash-progress')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('premium-splash-spinner')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('®'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('premium splash stays stable with RTL and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const _SplashHarness(
        locale: Locale('ar'),
        textScaler: TextScaler.linear(2),
      ),
    );
    await tester.pump();

    expect(find.text('BIL'), findsNothing);
    expect(
      find.byKey(const ValueKey('premium-splash-wordmark')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('premium-splash-loading-label')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('premium-splash-progress')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion presents stable identity immediately', (
    tester,
  ) async {
    await tester.pumpWidget(const _SplashHarness(reducedMotion: true));
    await tester.pump();

    expect(find.text('BIL'), findsNothing);
    expect(
      find.byKey(const ValueKey('premium-splash-wordmark')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('premium-splash-video')), findsNothing);
    expect(
      find.byKey(const ValueKey('premium-splash-progress')),
      findsOneWidget,
    );
    final fallback = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('premium-splash-first-frame-fallback')),
    );
    expect(fallback.opacity, 1);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('premium splash scales safely on tablet', (tester) async {
    tester.view.physicalSize = const Size(1024, 1366);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const _SplashHarness(highContrast: true));
    await tester.pump();

    expect(find.text('BIL'), findsNothing);
    expect(
      find.byKey(const ValueKey('premium-splash-wordmark')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('premium-splash-progress')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('native launch continuity matches the single Flutter splash', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const _SplashHarness(reducedMotion: true, showSpinner: false),
    );
    await tester.pump();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/premium_splash_native.png'),
    );
  });
}

class _SplashHarness extends StatefulWidget {
  const _SplashHarness({
    this.locale = const Locale('en'),
    this.reducedMotion = false,
    this.highContrast = false,
    this.textScaler = TextScaler.noScaling,
    this.showSpinner = true,
  });

  final Locale locale;
  final bool reducedMotion;
  final bool highContrast;
  final TextScaler textScaler;
  final bool showSpinner;

  @override
  State<_SplashHarness> createState() => _SplashHarnessState();
}

class _SplashHarnessState extends State<_SplashHarness>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: bilSplashMinimumDisplayDuration,
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
      theme: ThemeData(fontFamily: 'NotoNaskhArabic'),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: widget.reducedMotion,
            highContrast: widget.highContrast,
            textScaler: widget.textScaler,
          ),
          child: Scaffold(
            backgroundColor: const Color(0xFF061A69),
            body: Stack(
              fit: StackFit.expand,
              children: [
                const PremiumSplashBackdrop(),
                Center(
                  child: PremiumSplashExperience(
                    controller: controller,
                    showSpinner: widget.showSpinner,
                    showLoadingLabel: widget.showSpinner,
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
