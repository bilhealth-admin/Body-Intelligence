import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/shared/widgets/bil_glass_press_feedback.dart';
import 'package:body_intelligence_log/shared/widgets/bil_reference_bottom_bar.dart';
import 'visual_closure/visual_evidence_font.dart';
import 'visual_closure/closure_surface_capture.dart';

Future<void> mount(
  WidgetTester tester,
  Widget child, {
  bool dark = false,
  bool rtl = false,
  bool highContrast = false,
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: visualEvidenceTheme(
        dark
            ? BilFlagshipTheme.dark(highContrast: highContrast)
            : BilFlagshipTheme.light(highContrast: highContrast),
      ),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 844),
          highContrast: highContrast,
          disableAnimations: true,
        ),
        child: Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: RepaintBoundary(
            key: const Key('nav-capture'),
            child: Scaffold(body: child),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final bubble = find.byKey(const Key('bil-glass-press-bubble'));
Widget arrow(VoidCallback? callback, {FocusNode? focus}) => IconButton(
  key: const Key('arrow'),
  focusNode: focus,
  onPressed: callback,
  icon: const BilGlassPressFeedback(child: Icon(Icons.arrow_forward_rounded)),
);
void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final dark in [false, true]) {
    for (final rtl in [false, true]) {
      testWidgets(
        'arrow glass keeps geometry and original tap dark=$dark rtl=$rtl',
        (tester) async {
          var taps = 0;
          await mount(
            tester,
            Center(child: arrow(() => taps++)),
            dark: dark,
            rtl: rtl,
          );
          final button = find.byKey(const Key('arrow'));
          final before = tester.getRect(button);
          expect(bubble, findsNothing);
          final gesture = await tester.startGesture(tester.getCenter(button));
          await tester.pump();
          expect(bubble, findsOneWidget);
          expect(taps, 0);
          expect(tester.getRect(button), before);
          expect(tester.getSize(bubble), const Size(48, 48));
          await captureClosureSurface(
            tester,
            find.byKey(const Key('nav-capture')),
            'arrow-glass-$dark-$rtl',
          );
          await gesture.up();
          await tester.pumpAndSettle();
          expect(bubble, findsNothing);
          expect(taps, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'disabled/blocked arrow cannot claim an interactive glass state',
    (tester) async {
      await mount(tester, Center(child: arrow(null)));
      await tester.tap(find.byKey(const Key('arrow')), warnIfMissed: false);
      await tester.pump();
      expect(bubble, findsNothing);
      var taps = 0;
      await mount(
        tester,
        Center(child: IgnorePointer(child: arrow(() => taps++))),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('arrow'))),
      );
      await tester.pump();
      expect(bubble, findsNothing);
      await gesture.up();
      expect(taps, 0);
    },
  );
  testWidgets('move/cancel/dispose retire the bubble without a tap', (
    tester,
  ) async {
    var taps = 0;
    await mount(tester, Center(child: arrow(() => taps++)));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('arrow'))),
    );
    await tester.pump();
    expect(bubble, findsOneWidget);
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();
    expect(bubble, findsNothing);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(taps, 0);
    final next = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('arrow'))),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await next.cancel();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('keyboard Enter activates original action once', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    var taps = 0;
    await mount(tester, Center(child: arrow(() => taps++, focus: focus)));
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(bubble, findsOneWidget);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
    expect(bubble, findsNothing);
  });
  testWidgets(
    'glass works inside intrinsic dialogs and high contrast disables blur',
    (tester) async {
      await mount(
        tester,
        AlertDialog(
          title: const Text('Review'),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [arrow(() {}), const Text('Continue')],
          ),
        ),
        highContrast: true,
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('arrow'))),
      );
      await tester.pump();
      expect(bubble, findsOneWidget);
      expect(tester.takeException(), isNull);
      await gesture.cancel();
      await tester.pumpAndSettle();
    },
  );
  for (final width in [320.0, 390.0, 430.0]) {
    for (final rtl in [false, true]) {
      testWidgets('all five dock controls glass and callbacks $width rtl=$rtl', (
        tester,
      ) async {
        final selected = <int>[];
        await mount(
          tester,
          Align(
            alignment: Alignment.bottomCenter,
            child: RepaintBoundary(
              key: const Key('dock-capture'),
              child: BilReferenceBottomBar(
                selected: 0,
                onSelected: selected.add,
              ),
            ),
          ),
          width: width,
          rtl: rtl,
        );
        for (var i = 0; i < 5; i++) {
          final item = find.byKey(Key('bil-reference-nav-$i'));
          final before = tester.getRect(item);
          if (i == 0 && width == 390 && !rtl) {
            await captureClosureSurface(
              tester,
              find.byKey(const Key('dock-capture')),
              'dock-before-press',
            );
          }
          expect(item.hitTestable(), findsOneWidget);
          expect(before.width, greaterThanOrEqualTo(48));
          // The label/whole action region must trigger feedback, not just a tiny icon.
          final gesture = await tester.startGesture(tester.getCenter(item));
          await tester.pump();
          expect(bubble, findsOneWidget);
          expect(selected.length, i);
          expect(tester.getRect(item), before);
          if (width == 390 && !rtl) {
            await captureClosureSurface(
              tester,
              find.byKey(const Key('dock-capture')),
              'dock-glass-$i',
            );
          }
          await gesture.up();
          await tester.pumpAndSettle();
          expect(bubble, findsNothing);
          expect(selected, List.generate(i + 1, (index) => index));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('Flutter SDK Calendar arrows get the same temporary feedback', (
    tester,
  ) async {
    var changes = 0;
    await mount(
      tester,
      Column(
        children: [
          arrow(
            () {},
          ), // Registers the app-level decoration seam, as the dock does.
          CalendarDatePicker(
            initialDate: DateTime(2026, 10, 12),
            firstDate: DateTime(2025),
            lastDate: DateTime(2027),
            onDateChanged: (_) => changes++,
          ),
        ],
      ),
    );
    final next = find.byTooltip('Next month');
    expect(next, findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(next));
    await tester.pump();
    expect(find.byKey(const Key('bil-sdk-arrow-glass-bubble')), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bil-sdk-arrow-glass-bubble')), findsNothing);
    expect(find.text('November 2026'), findsOneWidget);
    expect(changes, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Flutter SDK default dropdown arrow stays functional with glass',
    (tester) async {
      var value = 1;
      await mount(
        tester,
        Column(
          children: [
            arrow(() {}),
            DropdownButton<int>(
              value: value,
              items: const [
                DropdownMenuItem(value: 1, child: Text('One')),
                DropdownMenuItem(value: 2, child: Text('Two')),
              ],
              onChanged: (next) => value = next!,
            ),
          ],
        ),
      );
      final dropdown = find.byType(DropdownButton<int>);
      final gesture = await tester.startGesture(tester.getCenter(dropdown));
      await tester.pump();
      expect(
        find.byKey(const Key('bil-sdk-arrow-glass-bubble')),
        findsOneWidget,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bil-sdk-arrow-glass-bubble')), findsNothing);
      await tester.tap(find.text('Two').last);
      await tester.pumpAndSettle();
      expect(value, 2);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('disabled SDK dropdown never gives active arrow feedback', (
    tester,
  ) async {
    await mount(
      tester,
      Column(
        children: [
          arrow(() {}),
          DropdownButton<int>(
            value: 1,
            items: const [DropdownMenuItem(value: 1, child: Text('One'))],
            onChanged: null,
          ),
        ],
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(DropdownButton<int>)),
    );
    await tester.pump();
    expect(find.byKey(const Key('bil-sdk-arrow-glass-bubble')), findsNothing);
    expect(bubble, findsNothing);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(DropdownMenuItem<int>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
