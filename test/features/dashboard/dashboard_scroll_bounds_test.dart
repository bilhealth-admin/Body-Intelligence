import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform: both edges rebound without synchronization, '
        'with no duplicate dock space', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var contentHeight = 1600.0;
      late StateSetter updateContent;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            bottomNavigationBar: const SizedBox(height: 80),
            body: StatefulBuilder(
              builder: (context, setState) {
                updateContent = setState;
                return DashboardShell(
                  child: Column(
                    children: [
                      SizedBox(height: contentHeight),
                      const SizedBox(
                        key: Key('last-dashboard-card'),
                        height: 64,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      final viewport = find.byKey(const Key('dashboard-scroll-view'));
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: viewport, matching: find.byType(Scrollable)),
          )
          .position;
      await tester.drag(viewport, const Offset(0, 330));
      await tester.pumpAndSettle();
      expect(position.pixels, closeTo(position.minScrollExtent, .5));

      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      await tester.drag(viewport, const Offset(0, -280));
      await tester.pumpAndSettle();
      expect(position.pixels, closeTo(position.maxScrollExtent, .5));
      final end = tester.getBottomRight(
        find.byKey(const Key('last-dashboard-card')),
      );
      expect(tester.getBottomRight(viewport).dy - end.dy, closeTo(16, .5));

      updateContent(() => contentHeight = 1000);
      await tester.pumpAndSettle();
      expect(position.outOfRange, isFalse);
      expect(position.pixels, closeTo(position.maxScrollExtent, .5));
      expect(tester.takeException(), isNull);
    });

  testWidgets('iOS: live dashboard resize preserves held bottom overscroll', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var contentHeight = 1600.0;
    late StateSetter updateContent;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: StatefulBuilder(
          builder: (context, setState) {
            updateContent = setState;
            return DashboardShell(
              child: SizedBox(height: contentHeight),
            );
          },
        ),
      ),
    );

    final viewport = find.byKey(const Key('dashboard-scroll-view'));
    final position = tester
        .state<ScrollableState>(
          find.descendant(of: viewport, matching: find.byType(Scrollable)),
        )
        .position;

    position.jumpTo(position.maxScrollExtent);
    await tester.pump();

    final gesture = await tester.startGesture(tester.getCenter(viewport));
    await gesture.moveBy(const Offset(0, -220));
    await tester.pump();

    final heldOverscroll = position.pixels - position.maxScrollExtent;
    expect(heldOverscroll, greaterThan(0));

    updateContent(() => contentHeight += 240);
    await tester.pump();

    expect(
      position.pixels - position.maxScrollExtent,
      closeTo(heldOverscroll, 1),
      reason:
          'Async dashboard card growth must not make a held elastic edge slip.',
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(position.maxScrollExtent, .5));
    expect(tester.takeException(), isNull);
  });

  }
}
