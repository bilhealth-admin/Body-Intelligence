import 'package:body_intelligence_log/features/dashboard/widgets/first_use_context_coachmark.dart';
import 'package:body_intelligence_log/shared/widgets/first_use_spotlight.dart';
import 'package:body_intelligence_log/shared/widgets/first_use_target_guide.dart';
import 'package:body_intelligence_log/shared/widgets/first_use_tap_celebration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const guideKey = Key('regression-pearl-guide');
const skipKey = Key('regression-guide-skip');
const targetKey = Key('regression-target');

Widget host({
  required bool rtl,
  double scale = 1,
  bool reduced = false,
  required StateSetter Function(StateSetter) retain,
  required bool Function() visible,
  required VoidCallback act,
  required VoidCallback skip,
  ScrollController? scroll,
}) => MaterialApp(
  locale: Locale(rtl ? 'ar' : 'en'),
  supportedLocales: const [Locale('ar'), Locale('en')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      disableAnimations: reduced,
    ),
    child: child!,
  ),
  home: Navigator(
    onGenerateRoute: (_) => MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        body: StatefulBuilder(
          builder: (context, refresh) {
            retain(refresh);
            return SingleChildScrollView(
              controller: scroll,
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  Align(
                    alignment: rtl
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: FirstUseTargetGuide(
                      guide: visible()
                          ? FirstUseContextCoachmark(
                              key: guideKey,
                              title: rtl ? 'اختر طعامك' : 'Choose your food',
                              message: rtl
                                  ? 'اضغط زر الإضافة ثم راجع الكمية قبل حفظ الوجبة.'
                                  : 'Tap the real add control, then review the portion before saving.',
                              onSkip: skip,
                              skipKey: skipKey,
                              onAction: () {},
                              actionLabel: 'Got it',
                            )
                          : null,
                      child: IconButton(
                        key: targetKey,
                        onPressed: act,
                        icon: const Icon(Icons.add),
                      ),
                    ),
                  ),
                  const SizedBox(height: 1100),
                ],
              ),
            );
          },
        ),
      ),
    ),
  ),
);

void main() {
  for (final rtl in [false, true]) {
    for (final width in [320.0, 430.0]) {
      for (final scale in [1.0, 2.0, 3.0]) {
        for (final keyboard in [0.0, 260.0]) {
          testWidgets(
            'root overlay edge rtl=$rtl width=$width text=$scale keyboard=$keyboard',
            (tester) async {
              tester.view.physicalSize = Size(width, 844);
              tester.view.devicePixelRatio = 1;
              tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
              addTearDown(tester.view.reset);
              var shown = true;
              late StateSetter refresh;
              await tester.pumpWidget(
                host(
                  rtl: rtl,
                  scale: scale,
                  reduced: true,
                  retain: (r) => refresh = r,
                  visible: () => shown,
                  act: () {},
                  skip: () => refresh(() => shown = false),
                ),
              );
              await tester.pumpAndSettle();
              final card = tester.getRect(find.byKey(guideKey));
              final skip = tester.getRect(find.byKey(skipKey));
              expect(card.left, greaterThanOrEqualTo(0));
              expect(card.right, lessThanOrEqualTo(width));
              expect(card.top, greaterThanOrEqualTo(0));
              expect(card.bottom, lessThanOrEqualTo(844 - keyboard));
              expect(card.contains(skip.center), isTrue);
              expect(find.text('Got it'), findsNothing);
              expect(find.text('فهمت'), findsNothing);
              await tester.tap(find.byKey(skipKey));
              await tester.pumpAndSettle();
              expect(
                find.byKey(const Key('first-use-spotlight-paint')),
                findsNothing,
              );
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }
  for (final reduced in [false, true]) {
    testWidgets(
      'real action once; bounded finite emoji burst reduced=$reduced',
      (tester) async {
        var shown = true;
        var calls = 0;
        late StateSetter refresh;
        await tester.pumpWidget(
          host(
            rtl: false,
            reduced: reduced,
            retain: (r) => refresh = r,
            visible: () => shown,
            skip: () => refresh(() => shown = false),
            act: () {
              calls++;
              refresh(() => shown = false);
            },
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(targetKey));
        await tester.pump(const Duration(milliseconds: 80));
        expect(calls, 1);
        final burst = find.byKey(const Key('first-use-tiny-emoji-burst'));
        expect(burst, reduced ? findsNothing : findsOneWidget);
        if (!reduced) {
          final rect = tester.getRect(burst);
          expect(rect.width, lessThanOrEqualTo(96));
          expect(rect.height, lessThanOrEqualTo(96));
        }
        await tester.pump(const Duration(milliseconds: 600));
        expect(burst, findsNothing);
        expect(
          find.byKey(const Key('first-use-spotlight-paint')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('scroll and cancel do not celebrate; position follows target', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      host(
        rtl: false,
        scroll: scroll,
        retain: (r) => r,
        visible: () => true,
        act: () {},
        skip: () {},
      ),
    );
    await tester.pumpAndSettle();
    scroll.jumpTo(30);
    await tester.pumpAndSettle();
    final effect = tester.widget<FirstUseGuideTapEffect>(
      find.byType(FirstUseGuideTapEffect),
    );
    expect(
      effect.target.top,
      closeTo(tester.getRect(find.byKey(targetKey)).top, .1),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(targetKey)),
    );
    await gesture.moveBy(const Offset(0, 20));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('first-use-tiny-emoji-burst')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(FirstUseSpotlight), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('leaving the route during a burst leaves no overlay or timer', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        rtl: false,
        retain: (r) => r,
        visible: () => true,
        act: () {},
        skip: () {},
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(targetKey));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('first-use-tiny-emoji-burst')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
