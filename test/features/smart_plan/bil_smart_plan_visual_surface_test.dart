import 'dart:math' as math;

import 'package:body_intelligence_log/app/theme/bil_pearl_finish.dart';
import 'package:body_intelligence_log/features/smart_plan/presentation/bil_smart_plan_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _linear(double component) => component <= .04045
    ? component / 12.92
    : math.pow((component + .055) / 1.055, 2.4).toDouble();

double _luminance(Color color) =>
    .2126 * _linear(color.r) +
    .7152 * _linear(color.g) +
    .0722 * _linear(color.b);

double _contrast(Color foreground, Color background) {
  final a = _luminance(foreground);
  final b = _luminance(background);
  return (math.max(a, b) + .05) / (math.min(a, b) + .05);
}

void main() {
  test(
    'local category illustrations never imply an individual verified video',
    () {
      expect(BilSmartPlanArt.overview, startsWith('assets/images/'));
      expect(BilSmartPlanArt.meals, contains('lifestyle'));
      expect(BilSmartPlanArt.recovery, contains('stretching'));
      expect(
        BilSmartPlanArt.forWorkout('home-strength-v1-a'),
        contains('full_body_strength.jpg'),
      );
      expect(
        BilSmartPlanArt.forWorkout('home-strength-v1-kettlebell'),
        contains('kettlebell'),
      );
      expect(BilSmartPlanArt.forWorkout('push-a'), contains('strength'));
    },
  );

  test('the trailing image scrim meets AA in light and dark worst cases', () {
    // Darkest possible underlying light photo and lightest dark photo.
    final worstLight = Color.lerp(
      Colors.black,
      BilPearlFinish.lightSurface,
      .70,
    )!;
    final worstDark = Color.lerp(
      Colors.white,
      BilPearlFinish.darkSurface,
      .82,
    )!;
    expect(
      _contrast(BilPearlFinish.lightInk, worstLight),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(BilPearlFinish.darkInk, worstDark),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('illustrated panel retains buttons and layout', (tester) async {
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: BilSmartPlanPanel(
              key: const ValueKey('illustrated-plan-card'),
              artwork: BilSmartPlanArt.session,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: () => presses++,
                  child: const Text('Review session'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.text('Review session'));
    await tester.pump();
    expect(presses, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('high contrast hides decorative image, not content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(highContrast: true),
            child: Scaffold(
              body: BilSmartPlanPanel(
                artwork: BilSmartPlanArt.recovery,
                child: const Text('Accessible recovery'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(Image), findsNothing);
    expect(find.text('Accessible recovery'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTL, text enlargement and narrow cards remain readable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 720),
              textScaler: TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  BilSmartPlanSectionTitle(
                    title: 'التمارين المجدولة للأسبوع الحالي',
                    subtitle: 'هذه صور فئوية توضيحية وليست تسجيلًا للنشاط',
                    icon: Icons.calendar_today_rounded,
                  ),
                  SizedBox(height: 12),
                  BilSmartPlanMetric(
                    label: 'الجلسات المؤكدة',
                    value: '3 / 5',
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('التمارين المجدولة للأسبوع الحالي'), findsOneWidget);
    expect(find.text('3 / 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
