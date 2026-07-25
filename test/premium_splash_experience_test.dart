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

  testWidgets('completed splash adapts to RTL and large text', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const _SplashHarness(
        locale: Locale('ar'),
        textScaler: TextScaler.linear(2),
      ),
    );
    await tester.pump(const Duration(milliseconds: 2600));
    expect(find.text('BIL®'), findsOneWidget);
    expect(find.text('BODY INTELLIGENCE LOG'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion presents stable identity immediately', (
    tester,
  ) async {
    await tester.pumpWidget(const _SplashHarness(reducedMotion: true));
    await tester.pump();
    expect(find.text('BIL®'), findsOneWidget);
    expect(find.text('BODY INTELLIGENCE LOG'), findsOneWidget);
    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, .5);
  });

  testWidgets('phone splash golden', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const _SplashHarness());
    await tester.pump(const Duration(milliseconds: 2600));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/premium_splash_phone.png'),
    );
  });

  testWidgets('tablet splash golden', (tester) async {
    tester.view.physicalSize = const Size(1024, 1366);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const _SplashHarness(highContrast: true));
    await tester.pump(const Duration(milliseconds: 2600));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/premium_splash_tablet.png'),
    );
  });

  testWidgets('animation keyframes stay visually coherent', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const _SplashHarness());
    for (var frame = 0; frame < 9; frame++) {
      if (frame > 0) await tester.pump(const Duration(milliseconds: 325));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/premium_splash_frames/frame_${frame.toString().padLeft(2, '0')}.png',
        ),
      );
    }
  });
}

class _SplashHarness extends StatefulWidget {
  const _SplashHarness({
    this.locale = const Locale('en'),
    this.reducedMotion = false,
    this.highContrast = false,
    this.textScaler = TextScaler.noScaling,
  });

  final Locale locale;
  final bool reducedMotion;
  final bool highContrast;
  final TextScaler textScaler;

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
      duration: const Duration(milliseconds: 2600),
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
            backgroundColor: const Color(0xFF01050D),
            body: Stack(
              fit: StackFit.expand,
              children: [
                const PremiumSplashBackdrop(),
                Center(
                  child: PremiumSplashExperience(
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
