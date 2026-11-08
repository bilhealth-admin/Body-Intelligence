import 'package:body_intelligence_log/shared/widgets/bil_crystal_arrow.dart';
import 'package:body_intelligence_log/shared/widgets/bil_crystal_expansion_indicator.dart';
import 'package:body_intelligence_log/app/theme/bil_navigation_press_style.dart';
import 'package:body_intelligence_log/shared/widgets/bil_navigation_feedback.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _bubble = Key('bil-crystal-arrow-bubble');

void main() {
  for (final direction in TextDirection.values) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'inline action crystals reserve the full surface before labels $direction dark=$dark scale=$scale',
          (tester) async {
            tester.view.physicalSize = const Size(320, 720);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final rtl = direction == TextDirection.rtl;
            var taps = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(
                  brightness: dark ? Brightness.dark : Brightness.light,
                ),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(320, 720),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Directionality(
                    textDirection: direction,
                    child: Scaffold(
                      body: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final (key, icon, label) in [
                              (
                                'play',
                                Icons.play_arrow_rounded,
                                rtl ? 'تشغيل الفيديو' : 'Play video',
                              ),
                              (
                                'download',
                                Icons.download_rounded,
                                rtl ? 'تنزيل' : 'Download',
                              ),
                              (
                                'export',
                                Icons.file_download_outlined,
                                rtl ? 'إنشاء تصدير CSV' : 'Create CSV export',
                              ),
                            ])
                              FilledButton.icon(
                                key: ValueKey('spacing-$key'),
                                onPressed: () => taps++,
                                icon: BilNavigationFeedback(child: Icon(icon)),
                                label: Text(label, key: ValueKey('label-$key')),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            for (final key in ['play', 'download', 'export']) {
              final button = find.byKey(ValueKey('spacing-$key'));
              final crystal = find.descendant(
                of: button,
                matching: find.byKey(_bubble),
              );
              final crystalRect = tester.getRect(crystal);
              final labelRect = tester.getRect(
                find.byKey(ValueKey('label-$key')),
              );
              final gap = rtl
                  ? crystalRect.left - labelRect.right
                  : labelRect.left - crystalRect.right;
              // Material retains an8px gap at normal text and4px at200%.
              // The crystal must occupy its own width before that native gap.
              expect(
                gap,
                greaterThanOrEqualTo(scale == 1 ? 8 : 4),
                reason: '$key decoration must not consume label spacing',
              );
              expect(
                tester.getRect(button).contains(crystalRect.center),
                isTrue,
              );
              await tester.tap(button);
              await tester.pumpAndSettle();
            }
            expect(taps, 3);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
  for (final direction in TextDirection.values) {
    for (final dark in [false, true]) {
      testWidgets(
        'navigation keeps one resting crystal, action and geometry $direction dark=$dark',
        (tester) async {
          var taps = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
              home: Directionality(
                textDirection: direction,
                child: Scaffold(
                  body: Center(
                    child: IconButton(
                      key: const Key('next'),
                      tooltip: 'Next',
                      onPressed: () => taps++,
                      icon: const BilNavigationFeedback(
                        child: Icon(CupertinoIcons.chevron_forward, size: 20),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final before = tester.getRect(find.byKey(const Key('next')));
          expect(find.byKey(_bubble), findsOneWidget);
          final gesture = await tester.startGesture(
            tester.getCenter(find.byKey(const Key('next'))),
          );
          await tester.pump();
          expect(taps, 0);
          expect(find.byKey(_bubble), findsOneWidget);
          await gesture.up();
          await tester.pumpAndSettle();
          expect(taps, 1);
          expect(tester.getRect(find.byKey(const Key('next'))), before);
          expect(find.byKey(_bubble), findsOneWidget);
          expect(find.byKey(const Key('bil-glass-press-bubble')), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'disabled directional control stays decorated without activation',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: IconButton(
                onPressed: null,
                tooltip: 'Previous',
                icon: BilNavigationFeedback(
                  child: Icon(Icons.arrow_back_rounded),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(_bubble), findsOneWidget);
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(find.byKey(_bubble), findsOneWidget);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'keyboard activates the parent exactly once and keeps the resting crystal',
    (tester) async {
      var taps = 0;
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: IconButton(
                focusNode: focus,
                onPressed: () => taps++,
                tooltip: 'Expand',
                icon: const BilNavigationFeedback(
                  child: Icon(Icons.expand_more_rounded),
                ),
              ),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(find.byKey(_bubble), findsOneWidget);
    },
  );

  testWidgets(
    'non-directional icons keep existing feedback without a resting crystal',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: IconButton(
                onPressed: null,
                icon: BilNavigationFeedback(
                  always: true,
                  child: Icon(Icons.search_rounded),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(_bubble), findsNothing);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    },
  );
  testWidgets(
    'automatic back glyph and explicit decoration draw exactly one crystal',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            actionIconTheme: const ActionIconThemeData(
              backButtonIconBuilder: BilNavigationPressStyle.backIcon,
            ),
          ),
          home: const Scaffold(
            body: Center(child: BilCrystalArrow(child: BackButton())),
          ),
        ),
      );
      expect(find.byKey(_bubble), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final direction in TextDirection.values) {
    testWidgets(
      'real expansion controller retains state, callback and one crystal $direction',
      (tester) async {
        final controller = ExpansibleController();
        addTearDown(controller.dispose);
        final changes = <bool>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: direction,
              child: Scaffold(
                body: ListView(
                  children: [
                    ExpansionTile(
                      controller: controller,
                      title: const Text('Details'),
                      trailing: const BilCrystalExpansionIndicator(),
                      onExpansionChanged: changes.add,
                      children: const [Text('Actual details')],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(find.byKey(_bubble), findsOneWidget);
        expect(find.text('Actual details'), findsNothing);
        await tester.tap(find.text('Details'));
        await tester.pumpAndSettle();
        expect(controller.isExpanded, isTrue);
        expect(find.text('Actual details'), findsOneWidget);
        expect(changes, [true]);
        expect(
          tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns,
          .5,
        );
        expect(find.byKey(_bubble), findsOneWidget);
        controller.collapse();
        await tester.pumpAndSettle();
        expect(changes, [true, false]);
        expect(find.text('Actual details'), findsNothing);
        expect(find.byKey(_bubble), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final direction in TextDirection.values) {
    testWidgets('inline source crystal never covers its label $direction', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: Center(
                child: TextButton.icon(
                  onPressed: () {},
                  icon: const BilNavigationFeedback(
                    child: Icon(Icons.open_in_new_rounded, size: 17),
                  ),
                  label: const Text('Source reference'),
                ),
              ),
            ),
          ),
        ),
      );
      final circle = tester.getRect(find.byKey(_bubble));
      final text = tester.getRect(find.text('Source reference'));
      expect(circle.overlaps(text), isFalse);
      expect(circle.width, 30);
      expect(
        tester.getSize(find.byType(TextButton)).height,
        greaterThanOrEqualTo(44),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
