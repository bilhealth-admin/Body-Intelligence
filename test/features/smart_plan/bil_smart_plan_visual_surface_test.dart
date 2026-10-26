import 'dart:math' as math;

import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_smart_plan_visual.dart';
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
  test('My Plan visual metrics cover all 25 locales', () {
    expect(SmartPlanVisualRuntimeCopy.balanced, isTrue);
    for (final source in SmartPlanVisualRuntimeCopy.sources) {
      for (final locale in BilLocalePolicy.productionTags) {
        final translated = RuntimeCopy.resolve(source, locale);
        expect(translated, isNotNull, reason: '$locale: $source');
        expect(translated!.trim(), isNotEmpty, reason: '$locale: $source');
        if (locale != 'en') {
          expect(translated, isNot(source), reason: '$locale: $source');
        }
      }
    }
  });

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

  test('My Plan tab ink meets AA on dark and light palettes', () {
    expect(
      _contrast(Colors.white, const Color(0xFF07518F)),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(Colors.white, const Color(0xFF0B6CB2)),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(BilPearlFinish.lightInk, BilPearlFinish.lightCanvas),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(BilPearlFinish.darkInk, BilPearlFinish.darkCanvas),
      greaterThanOrEqualTo(4.5),
    );
  });

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

  testWidgets('metric pair reflows at phone, tablet and large text sizes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final variant in [
      (320.0, 1.0, false, TextDirection.ltr),
      (390.0, 1.0, true, TextDirection.ltr),
      (430.0, 1.0, true, TextDirection.rtl),
      (768.0, 1.0, true, TextDirection.rtl),
      (390.0, 2.0, false, TextDirection.rtl),
    ]) {
      tester.view.physicalSize = Size(variant.$1, 900);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(variant.$2)),
              child: Directionality(
                textDirection: variant.$4,
                child: const Scaffold(
                  body: Padding(
                    padding: EdgeInsets.all(32),
                    child: BilSmartPlanMetricPair(
                      first: BilSmartPlanMetric(
                        label: 'Days in plan',
                        value: '31',
                      ),
                      second: BilSmartPlanMetric(
                        label: 'Scheduled workouts',
                        value: '14',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final first = tester.getTopLeft(find.byType(BilSmartPlanMetric).first);
      final second = tester.getTopLeft(find.byType(BilSmartPlanMetric).last);
      expect(
        (first.dy - second.dy).abs() < 1,
        variant.$3,
        reason: 'Unexpected metric layout at ${variant.$1}px / ${variant.$2}x',
      );
      expect(tester.takeException(), isNull);
    }
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
              textScaler: TextScaler.linear(2),
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
    expect(tester.widget<Text>(find.text('الجلسات المؤكدة')).maxLines, isNull);
    expect(tester.takeException(), isNull);
  });
}
