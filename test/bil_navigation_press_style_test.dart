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
Widget arrow(
  VoidCallback? callback, {
  FocusNode? focus,
  bool feedback = false,
}) => IconButton(
  key: const Key('arrow'),
  focusNode: focus,
  onPressed: callback,
  icon: BilGlassPressFeedback(
    always: feedback,
    child: const Icon(Icons.arrow_forward_rounded),
  ),
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
            Center(child: arrow(() => taps++, feedback: true)),
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
      await mount(tester, Center(child: arrow(null, feedback: true)));
      await tester.tap(find.byKey(const Key('arrow')), warnIfMissed: false);
      await tester.pump();
      expect(bubble, findsNothing);
      var taps = 0;
      await mount(
        tester,
        Center(
          child: IgnorePointer(child: arrow(() => taps++, feedback: true)),
        ),
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
    await mount(tester, Center(child: arrow(() => taps++, feedback: true)));
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
    await mount(
      tester,
      Center(child: arrow(() => taps++, focus: focus, feedback: true)),
    );
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
            children: [arrow(() {}, feedback: true), const Text('Continue')],
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
  testWidgets(
    'Flutter SDK Calendar keeps native feedback without cloning its arrow',
    (tester) async {
      var changes = 0;
      await mount(
        tester,
        Column(
          children: [
            arrow(() {}),
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
      final sdkBubble = find.byKey(const Key('bil-sdk-arrow-glass-bubble'));
      expect(sdkBubble, findsNothing);
      expect(bubble, findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(sdkBubble, findsNothing);
      expect(find.text('November 2026'), findsOneWidget);
      expect(changes, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Flutter SDK dropdown keeps native feedback without a root overlay',
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
      final dropdownArrow = find.byIcon(Icons.arrow_drop_down);
      final gesture = await tester.startGesture(
        tester.getCenter(dropdownArrow),
      );
      await tester.pump();
      final sdkBubble = find.byKey(const Key('bil-sdk-arrow-glass-bubble'));
      expect(sdkBubble, findsNothing);
      expect(bubble, findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(sdkBubble, findsNothing);
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
          arrow(() {}, feedback: true),
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
  testWidgets('native row arrows never create detached overlay copies', (
    tester,
  ) async {
    await mount(
      tester,
      Column(
        children: [
          arrow(() {}),
          GestureDetector(
            onTap: () {},
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left_rounded, key: Key('left-sdk-icon')),
                SizedBox(width: 24),
                Icon(Icons.sync_rounded, key: Key('sync-sdk-icon')),
                SizedBox(width: 24),
                Icon(Icons.chevron_right_rounded, key: Key('right-sdk-icon')),
              ],
            ),
          ),
        ],
      ),
    );
    final rightArrow = find.byKey(const Key('right-sdk-icon'));
    final gesture = await tester.startGesture(tester.getCenter(rightArrow));
    await tester.pump();
    final sdkBubble = find.byKey(const Key('bil-sdk-arrow-glass-bubble'));
    expect(sdkBubble, findsNothing);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(sdkBubble, findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'native glyph and nearby presses retain actions without overlay copies',
    (tester) async {
      var parentTaps = 0;
      await mount(
        tester,
        Column(
          children: [
            // Local app feedback remains mounted beside the native control.
            arrow(() {}),
            Center(
              child: SizedBox(
                key: const Key('arrow-action-region'),
                width: 120,
                height: 64,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => parentTaps++,
                  child: Stack(
                    alignment: Alignment.centerRight,
                    children: const [
                      Icon(
                        Icons.chevron_right_rounded,
                        key: Key('sdk-action-arrow'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );

      final arrowRect = tester.getRect(
        find.byKey(const Key('sdk-action-arrow')),
      );
      final outsideGlyph = Offset(arrowRect.left - 8, arrowRect.center.dy);
      expect(
        tester
            .getRect(find.byKey(const Key('arrow-action-region')))
            .contains(outsideGlyph),
        isTrue,
      );

      final nearbyPress = await tester.startGesture(outsideGlyph);
      await tester.pump();
      expect(
        find.byKey(const Key('bil-sdk-arrow-glass-bubble')),
        findsNothing,
        reason: 'a nearby tap outside the visible arrow must not borrow it',
      );
      await nearbyPress.up();
      await tester.pumpAndSettle();
      expect(parentTaps, 1);

      final arrowPress = await tester.startGesture(arrowRect.center);
      await tester.pump();
      final sdkBubble = find.byKey(const Key('bil-sdk-arrow-glass-bubble'));
      expect(sdkBubble, findsNothing);
      await arrowPress.up();
      await tester.pumpAndSettle();
      expect(parentTaps, 2);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'SDK arrow feedback stays hidden when pressing elsewhere in row',
    (tester) async {
      var taps = 0;
      await mount(
        tester,
        Center(
          child: SizedBox(
            width: 350,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: Row(
                children: [
                  const Text('A wide settings row'),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    key: Key('wide-row-arrow'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final title = find.text('A wide settings row');
      final titleGesture = await tester.startGesture(tester.getCenter(title));
      await tester.pump();
      expect(find.byKey(const Key('bil-sdk-arrow-glass-bubble')), findsNothing);
      await titleGesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('a decorative trend arrow is not a press-feedback target', (
    tester,
  ) async {
    var cardTaps = 0;
    await mount(
      tester,
      Column(
        children: [
          arrow(() {}),
          GestureDetector(
            onTap: () => cardTaps++,
            child: const BilGlassPressFeedback(
              child: Icon(
                Icons.trending_down_rounded,
                key: Key('decorative-trend-arrow'),
              ),
            ),
          ),
        ],
      ),
    );

    await tester.tap(find.byKey(const Key('decorative-trend-arrow')));
    await tester.pumpAndSettle();
    expect(cardTaps, 1);
    expect(find.byKey(const Key('bil-sdk-arrow-glass-bubble')), findsNothing);
    expect(bubble, findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('an unrelated page tap never borrows a distant arrow bubble', (
    tester,
  ) async {
    var pageTaps = 0;
    await mount(
      tester,
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => pageTaps++,
        child: SizedBox.expand(
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  key: const Key('page-top-arrow'),
                  onPressed: () {},
                  icon: const BilGlassPressFeedback(
                    child: Icon(Icons.arrow_back_rounded),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: IconButton(
                  key: const Key('page-bottom-sync'),
                  onPressed: () {},
                  icon: const BilGlassPressFeedback(
                    child: Icon(Icons.sync_rounded),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final unrelatedArea = tester.getCenter(
      find.byKey(const Key('nav-capture')),
    );
    final gesture = await tester.startGesture(unrelatedArea);
    await tester.pump();
    expect(bubble, findsNothing);
    expect(find.byKey(const Key('bil-sdk-arrow-glass-bubble')), findsNothing);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(pageTaps, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('arrow and sync press bubbles stay anchored to their own icon', (
    tester,
  ) async {
    var taps = 0;
    await mount(
      tester,
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            key: const Key('ordinary-arrow'),
            onPressed: () => taps++,
            icon: const BilGlassPressFeedback(
              child: Icon(Icons.chevron_right_rounded),
            ),
          ),
          IconButton(
            key: const Key('sync-arrow'),
            onPressed: () => taps++,
            icon: const BilGlassPressFeedback(child: Icon(Icons.sync_rounded)),
          ),
        ],
      ),
    );
    for (final key in const ['ordinary-arrow', 'sync-arrow']) {
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(Key(key))),
      );
      await tester.pump();
      expect(bubble, findsOneWidget, reason: key);
      expect(
        tester.getCenter(bubble),
        tester.getCenter(find.byKey(Key(key))),
        reason: '$key bubble must stay over the pressed control',
      );
      await gesture.up();
      await tester.pumpAndSettle();
    }
    expect(taps, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets('top and middle controls never borrow another arrow position', (
    tester,
  ) async {
    await mount(
      tester,
      Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: IconButton(
              key: const Key('top-arrow'),
              onPressed: () {},
              icon: const BilGlassPressFeedback(
                child: Icon(Icons.arrow_back_rounded),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, .15),
            child: IconButton(
              key: const Key('middle-sync'),
              onPressed: () {},
              icon: const BilGlassPressFeedback(
                child: Icon(Icons.sync_rounded),
              ),
            ),
          ),
        ],
      ),
    );
    for (final key in const ['top-arrow', 'middle-sync']) {
      final control = find.byKey(Key(key));
      final gesture = await tester.startGesture(tester.getCenter(control));
      await tester.pump();
      expect(bubble, findsOneWidget, reason: key);
      expect(
        tester.getCenter(bubble),
        tester.getCenter(control),
        reason: '$key feedback must align with the pressed icon',
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(bubble, findsNothing);
    }
    expect(tester.takeException(), isNull);
  });
}
