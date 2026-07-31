import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_carousel.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app() => MaterialApp(
    theme: ThemeData(platform: TargetPlatform.windows),
    home: const Scaffold(
      body: Center(
        child: SizedBox(
          width: 700,
          child: DashboardCarousel(
            height: 180,
            pages: [
              ColoredBox(
                color: Colors.blue,
                child: Center(child: Text('page one')),
              ),
              ColoredBox(
                color: Colors.green,
                child: Center(child: Text('page two')),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  testWidgets('desktop arrow advances and indicator follows the active page', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.tap(find.byKey(const Key('dashboard-carousel-next')));
    await tester.pumpAndSettle();

    expect(find.text('page two'), findsOneWidget);
    final previous = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const Key('dashboard-carousel-previous')),
        matching: find.byType(IconButton),
      ),
    );
    expect(previous.onPressed, isNotNull);
    expect(find.byKey(const Key('dashboard-deck-active-card')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-deck-layer-1')), findsNothing);
    expect(find.byKey(const Key('dashboard-deck-layer-2')), findsNothing);
  });

  testWidgets('transition rotates in place without translating horizontally', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    final before = tester.getCenter(
      find.byKey(const Key('dashboard-deck-active-card')),
    );
    await tester.tap(find.byKey(const Key('dashboard-carousel-next')));
    await tester.pump(const Duration(milliseconds: 100));
    final during = tester.getCenter(
      find.byKey(const Key('dashboard-deck-active-card')),
    );

    expect(during.dx, closeTo(before.dx, .01));
    expect(during.dy, closeTo(before.dy, .01));
  });

  testWidgets('reduced motion swaps cards without an animated transition', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: app(),
      ),
    );
    await tester.tap(find.byKey(const Key('dashboard-carousel-next')));
    await tester.pump();

    expect(find.text('page two'), findsOneWidget);
  });

  testWidgets('primary mouse drag changes page on Windows', (tester) async {
    await tester.pumpWidget(app());
    final center = tester.getCenter(find.text('page one'));
    final gesture = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await gesture.moveBy(const Offset(-500, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('page two'), findsOneWidget);
  });

  testWidgets('mouse wheel advances a focused dashboard carousel', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    final center = tester.getCenter(find.text('page one'));
    await tester.sendEventToBinding(
      PointerScrollEvent(position: center, scrollDelta: const Offset(0, 80)),
    );
    await tester.pumpAndSettle();

    expect(find.text('page two'), findsOneWidget);
  });
}
