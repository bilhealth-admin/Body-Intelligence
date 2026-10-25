import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/app/theme/bil_navigation_press_style.dart';
import 'package:body_intelligence_log/shared/widgets/bil_crystal_arrow.dart';
import 'package:body_intelligence_log/shared/widgets/secondary_page_app_bar.dart';

const _bubble = Key('bil-crystal-arrow-bubble');

void main() {
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
                body: Center(
                  child: BilNavigationPressStyle.backIcon(context),
                ),
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
}
