import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/shared/widgets/bil_crystal_arrow.dart';
import 'package:body_intelligence_log/shared/widgets/secondary_page_app_bar.dart';

const _bubble = Key('bil-crystal-arrow-bubble');

void main() {
  for (final dark in [false, true]) {
    for (final rtl in [false, true]) {
      testWidgets(
        'resting crystal persists across tap dark=' +
            dark.toString() +
            ' rtl=' +
            rtl.toString(),
        (tester) async {
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
        },
      );
    }
  }

  testWidgets('disabled arrow still has a resting crystal and cannot activate', (
    tester,
  ) async {
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
  });

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
              icon: BilCrystalArrow(
                child: Icon(Icons.chevron_left_rounded),
              ),
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
    addTearDown(semantics.dispose);
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
    expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(node.label, 'Go forward');

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
  });
}
