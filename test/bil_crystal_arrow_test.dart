import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/app/theme/bil_navigation_press_style.dart';
import 'package:body_intelligence_log/shared/widgets/bil_crystal_arrow.dart';
import 'package:body_intelligence_log/shared/widgets/secondary_page_app_bar.dart';

const _bubble = Key('bil-crystal-arrow-bubble');

void main() {
  for (final opacity in [1.0, .38]) {
    testWidgets(
      'Pearl composer navy keeps legible light glass on a dark page alpha=$opacity',
      (tester) async {
        final ink = const Color(0xFF14243A).withValues(alpha: opacity);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: Brightness.dark),
            home: Scaffold(
              body: Center(
                child: BilCrystalArrow(
                  child: Icon(
                    Icons.arrow_upward,
                    color: ink,
                    semanticLabel: 'Send',
                  ),
                ),
              ),
            ),
          ),
        );
        final glyph = tester.widget<Icon>(find.byIcon(Icons.arrow_upward));
        expect(glyph.color, ink);
        final surface = tester.widget<DecoratedBox>(find.byKey(_bubble));
        final gradient =
            (surface.decoration as BoxDecoration).gradient! as LinearGradient;
        for (final stop in gradient.colors) {
          expect(stop.computeLuminance(), greaterThan(.7));
        }
        expect(glyph.semanticLabel, 'Send');
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final dark in [false, true]) {
    for (final explicit in [false, true]) {
      for (final foreground in [Colors.white, Colors.black]) {
        testWidgets(
          'crystal glyph contrasts on button background dark=$dark explicit=$explicit foreground=$foreground',
          (tester) async {
            const backing = Color(0xFF006AC2);
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(
                  brightness: dark ? Brightness.dark : Brightness.light,
                ),
                home: Scaffold(
                  body: Center(
                    child: ColoredBox(
                      color: backing,
                      child: IconTheme(
                        data: IconThemeData(color: foreground),
                        child: BilCrystalArrow(
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: explicit ? foreground : null,
                            semanticLabel: 'Next',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            final finder = find.byIcon(Icons.arrow_forward_rounded);
            final icon = tester.widget<Icon>(finder);
            final color =
                icon.color ?? IconTheme.of(tester.element(finder)).color!;
            final decoration =
                tester.widget<DecoratedBox>(find.byKey(_bubble)).decoration
                    as BoxDecoration;
            final gradient = decoration.gradient! as LinearGradient;
            for (final stop in gradient.colors) {
              final background = Color.alphaBlend(stop, backing);
              final lighter =
                  color.computeLuminance() > background.computeLuminance()
                  ? color
                  : background;
              final darker = lighter == color ? background : color;
              expect(
                (lighter.computeLuminance() + .05) /
                    (darker.computeLuminance() + .05),
                greaterThanOrEqualTo(3),
                reason:
                    'The visible glyph must contrast against both glass stops',
              );
            }
            expect(icon.semanticLabel, 'Next');
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
  testWidgets(
    'plugin Icon subtype retains one GlobalKey and disabled opacity',
    (tester) async {
      final identity = GlobalKey();
      final disabled = Colors.white.withValues(alpha: .38);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BilCrystalActionIcon(
                Icons.arrow_back,
                key: identity,
                color: disabled,
                semanticLabel: 'Back',
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(identity), findsOneWidget);
      final glyph = tester.widget<Icon>(find.byType(Icon));
      expect(glyph.color!.a, closeTo(disabled.a, .0001));
      expect(glyph.semanticLabel, 'Back');
      expect(tester.takeException(), isNull);
    },
  );
  for (final dark in [false, true]) {
    for (final rtl in [false, true]) {
      testWidgets('resting crystal persists across tap dark=$dark rtl=$rtl', (
        tester,
      ) async {
        var taps = 0;
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            home: Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: Scaffold(
                body: Center(
                  child: IconButton(
                    key: const Key('crystal-arrow-button'),
                    tooltip: 'Forward',
                    onPressed: () => taps++,
                    icon: const BilCrystalArrow(
                      child: Icon(Icons.arrow_forward_rounded),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final button = find.byKey(const Key('crystal-arrow-button'));
        final before = tester.getRect(button);
        expect(find.byKey(_bubble), findsOneWidget);
        expect(tester.getSize(find.byKey(_bubble)), const Size(48, 48));

        final gesture = await tester.startGesture(tester.getCenter(button));
        await tester.pump();
        expect(find.byKey(_bubble), findsOneWidget);
        expect(taps, 0);
        expect(tester.getRect(button), before);

        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.byKey(_bubble), findsOneWidget);
        expect(taps, 1);
        expect(tester.getRect(button), before);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'disabled arrow still has a resting crystal and cannot activate',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: IconButton(
              key: const Key('disabled-crystal-arrow'),
              onPressed: null,
              icon: const BilCrystalArrow(
                child: Icon(Icons.chevron_right_rounded),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(_bubble), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('disabled-crystal-arrow')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(taps, 0);
      expect(find.byKey(_bubble), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('secondary-page back uses the crystal and keeps its callback', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: SecondaryPageAppBar(
            title: const Text('Settings'),
            onBack: () => taps++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('secondary-page-back'));
    final buttonRect = tester.getRect(button);
    expect(find.byKey(_bubble), findsOneWidget);
    final bubbleRect = tester.getRect(find.byKey(_bubble));

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(taps, 1);
    expect(find.byKey(_bubble), findsOneWidget);
    expect(tester.getRect(button), buttonRect);
    expect(tester.getRect(find.byKey(_bubble)), bubbleRect);
    expect(tester.takeException(), isNull);
  });

  testWidgets('high-contrast crystal uses a stronger visible border', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(highContrast: true),
          child: const Center(
            child: IconButton(
              onPressed: null,
              icon: BilCrystalArrow(child: Icon(Icons.chevron_left_rounded)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final surface = tester.widget<DecoratedBox>(find.byKey(_bubble));
    final decoration = surface.decoration as BoxDecoration;
    expect(decoration.border, isNotNull);
    expect(decoration.border!.top.width, 1.5);
    expect(find.byKey(_bubble), findsOneWidget);
    expect(
      find.byType(BackdropFilter),
      findsNothing,
      reason:
          'Solid accessibility rendering must omit the raster filter entirely',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('crystal does not replace button semantics or keyboard action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final focus = FocusNode();
    addTearDown(focus.dispose);
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: IconButton(
            key: const Key('semantic-crystal-arrow'),
            focusNode: focus,
            tooltip: 'Go forward',
            onPressed: () => taps++,
            icon: const BilCrystalArrow(
              child: Icon(Icons.arrow_forward_rounded),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_bubble), findsOneWidget);
    final node = tester.getSemantics(
      find.byKey(const Key('semantic-crystal-arrow')),
    );
    expect(node.flagsCollection.isButton, isTrue);
    // Flutter 3.44.6 exposes IconButton.tooltip in the SemanticsData
    // tooltip field, not label. Keep the role and keyboard checks strict.
    expect(node.getSemanticsData().tooltip, 'Go forward');

    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.byKey(_bubble), findsOneWidget);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(taps, 1);
    expect(find.byKey(_bubble), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Flutter verifies SemanticsHandles before addTearDown callbacks run.
    // Explicitly close this handle after all strict assertions.
    semantics.dispose();
  });

  for (final rtl in [false, true]) {
    testWidgets('backIcon uses one SDK RTL mirror and keeps crystal rtl=$rtl', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(child: BilNavigationPressStyle.backIcon(context)),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final glyph = find.descendant(
        of: find.byType(BilCrystalArrow),
        matching: find.byType(Icon),
      );
      expect(glyph, findsOneWidget);
      expect(tester.widget<Icon>(glyph).icon, Icons.chevron_left_rounded);
      expect(tester.widget<Icon>(glyph).icon!.matchTextDirection, isTrue);
      expect(
        Directionality.of(tester.element(glyph)),
        rtl ? TextDirection.rtl : TextDirection.ltr,
      );
      expect(find.byKey(_bubble), findsOneWidget);
      expect(tester.getSize(find.byKey(_bubble)), const Size(48, 48));
      expect(tester.takeException(), isNull);
    });
  }

  // Isolated component matrix: these checks do not claim that every feature
  // route has already migrated to BilCrystalArrow.
  for (final width in <double>[320, 390, 430, 768]) {
    for (final rtl in [false, true]) {
      testWidgets(
        'crystal retains hit target through cancelled drags width=$width rtl=$rtl',
        (tester) async {
          tester.view.physicalSize = Size(width, 1024);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          var actions = 0;

          await tester.pumpWidget(
            MaterialApp(
              home: Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: const Key('matrix-crystal-arrow'),
                          tooltip: 'Navigate',
                          onPressed: () => actions++,
                          icon: const BilCrystalArrow(
                            child: Icon(Icons.chevron_right_rounded),
                          ),
                        ),
                        const SizedBox(height: 80),
                        const Text('Unrelated action area'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final button = find.byKey(const Key('matrix-crystal-arrow'));
          final buttonRect = tester.getRect(button);
          final bubbleRect = tester.getRect(find.byKey(_bubble));

          expect(buttonRect.width, greaterThanOrEqualTo(44));
          expect(buttonRect.height, greaterThanOrEqualTo(44));
          expect(bubbleRect.size, const Size(48, 48));
          expect((bubbleRect.center - buttonRect.center).distance, lessThan(1));

          await tester.tap(find.text('Unrelated action area'));
          await tester.pumpAndSettle();
          expect(actions, 0);
          expect(find.byKey(_bubble), findsOneWidget);

          final drag = await tester.startGesture(tester.getCenter(button));
          await tester.pump();
          expect(find.byKey(_bubble), findsOneWidget);
          await drag.moveBy(const Offset(100, 0));
          await tester.pump();
          await drag.up();
          await tester.pumpAndSettle();
          expect(actions, 0);
          expect(find.byKey(_bubble), findsOneWidget);

          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(actions, 1);
          expect(tester.getRect(button), buttonRect);
          expect(tester.getRect(find.byKey(_bubble)), bubbleRect);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('crystal composes with expansion, row detail and dropdown', (
    tester,
  ) async {
    var rowTaps = 0;
    String selected = 'first';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ListView(
              children: [
                ExpansionTile(
                  title: const Text('Expand section'),
                  trailing: const BilCrystalArrow(
                    child: Icon(Icons.expand_more_rounded),
                  ),
                  children: const [Text('Expanded content')],
                ),
                ListTile(
                  key: const Key('crystal-detail-row'),
                  title: const Text('Details'),
                  trailing: const BilCrystalArrow(
                    child: Icon(Icons.chevron_right_rounded),
                  ),
                  onTap: () => rowTaps++,
                ),
                DropdownButton<String>(
                  key: const Key('crystal-dropdown'),
                  value: selected,
                  icon: const BilCrystalArrow(
                    child: Icon(Icons.arrow_drop_down_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'first', child: Text('First')),
                    DropdownMenuItem(value: 'second', child: Text('Second')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => selected = value);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_bubble), findsNWidgets(3));

    await tester.tap(find.text('Expand section'));
    await tester.pumpAndSettle();
    expect(find.text('Expanded content'), findsOneWidget);
    expect(find.byKey(_bubble), findsNWidgets(3));

    await tester.tap(find.byKey(const Key('crystal-detail-row')));
    await tester.pumpAndSettle();
    expect(rowTaps, 1);

    await tester.tap(find.byKey(const Key('crystal-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second').last);
    await tester.pumpAndSettle();
    expect(selected, 'second');
    expect(find.byKey(_bubble), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('accessible navigation keeps a solid permanent crystal', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            accessibleNavigation: true,
            disableAnimations: true,
          ),
          child: const Scaffold(
            body: Center(
              child: IconButton(
                onPressed: null,
                icon: BilCrystalArrow(child: Icon(Icons.chevron_left_rounded)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final surface = tester.widget<DecoratedBox>(find.byKey(_bubble));
    final decoration = surface.decoration as BoxDecoration;
    expect(decoration.border!.top.width, 1.5);
    expect(find.byKey(_bubble), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Exercises the actual production secondary AppBar, not only synthetic
  // icon fixtures. It must preserve native direction, hit geometry and its
  // caller callback while the glass remains at rest/press/cancel/release.
  for (final width in <double>[320, 390, 430, 768]) {
    for (final dark in [false, true]) {
      for (final rtl in [false, true]) {
        testWidgets(
          'real SecondaryPageAppBar retains its glass at rest width=$width dark=$dark rtl=$rtl',
          (tester) async {
            tester.view.physicalSize = Size(width, 1024);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            var backTaps = 0;

            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(
                  brightness: dark ? Brightness.dark : Brightness.light,
                ),
                home: Directionality(
                  textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                  child: Scaffold(
                    appBar: SecondaryPageAppBar(
                      title: const Text('BIL'),
                      showDashboardAction: false,
                      onBack: () => backTaps++,
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            final button = find.byKey(const Key('secondary-page-back'));
            final crystal = find.descendant(
              of: button,
              matching: find.byKey(_bubble),
            );
            final glyph = find.descendant(
              of: button,
              matching: find.byType(BackButtonIcon),
            );
            expect(button, findsOneWidget);
            expect(crystal, findsOneWidget);
            expect(glyph, findsOneWidget);
            expect(tester.getSize(crystal), const Size(48, 48));
            expect(tester.getSize(button).width, greaterThanOrEqualTo(44));
            expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
            expect(tester.widget<IconButton>(button).tooltip, 'Back');
            expect(
              Directionality.of(tester.element(glyph)),
              rtl ? TextDirection.rtl : TextDirection.ltr,
            );

            final initialButtonRect = tester.getRect(button);
            final initialBubbleRect = tester.getRect(crystal);
            final touch = await tester.startGesture(tester.getCenter(button));
            await tester.pump();
            expect(crystal, findsOneWidget);
            expect(backTaps, 0);
            await touch.cancel();
            await tester.pumpAndSettle();
            expect(backTaps, 0);
            expect(tester.getRect(crystal), initialBubbleRect);

            await tester.tap(button);
            await tester.pumpAndSettle();
            expect(backTaps, 1);
            expect(crystal, findsOneWidget);
            expect(tester.getRect(button), initialButtonRect);
            expect(tester.getRect(crystal), initialBubbleRect);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
