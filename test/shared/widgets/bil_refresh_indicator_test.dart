import 'dart:async';

import 'package:body_intelligence_log/shared/widgets/bil_pearl_feature_welcome.dart';
import 'package:body_intelligence_log/shared/widgets/bil_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> mount(
  WidgetTester tester,
  RefreshCallback onRefresh, {
  bool reverse = false,
  bool showDragIndicator = true,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: BilRefreshIndicator(
        onRefresh: onRefresh,
        showDragIndicator: showDragIndicator,
        child: ListView(
          reverse: reverse,
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          children: const [
            SizedBox(height: 1200, child: Text('Preserved content')),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'quiet drag does not claim refresh before release and shows one pending indicator',
    (tester) async {
      var calls = 0;
      final pending = Completer<void>();
      addTearDown(() {
        if (!pending.isCompleted) pending.complete();
      });
      await mount(tester, () {
        calls++;
        return pending.future;
      }, showDragIndicator: false);
      final list = find.byType(ListView);
      final before = tester.getTopLeft(list);
      final finger = await tester.startGesture(tester.getCenter(list));
      await finger.moveBy(const Offset(0, 400));
      await tester.pump(const Duration(milliseconds: 300));
      expect(calls, 0);
      expect(find.byType(BilFeatureWelcomeStatus), findsNothing);
      await finger.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(calls, 1);
      expect(find.byType(BilFeatureWelcomeStatus), findsOneWidget);
      expect(tester.getTopLeft(list), before);
      await tester.drag(list, const Offset(0, 400));
      await tester.pump(const Duration(milliseconds: 500));
      expect(calls, 1);
      expect(find.byType(BilFeatureWelcomeStatus), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(BilFeatureWelcomeStatus), findsNothing);
      expect(find.text('Preserved content'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'quiet ordinary scrolling and canceled short drag never become busy',
    (tester) async {
      var calls = 0;
      await mount(tester, () async {
        calls++;
      }, showDragIndicator: false);
      final list = find.byType(ListView);
      var finger = await tester.startGesture(tester.getCenter(list));
      await finger.moveBy(const Offset(0, 12));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(BilFeatureWelcomeStatus), findsNothing);
      await finger.up();
      await tester.pumpAndSettle();
      await tester.drag(list, const Offset(0, -150));
      finger = await tester.startGesture(tester.getCenter(list));
      await finger.moveBy(const Offset(0, -50));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(BilFeatureWelcomeStatus), findsNothing);
      await finger.up();
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.byType(BilFeatureWelcomeStatus), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final reverse in [false, true]) {
    testWidgets(
      'real pull refresh uses Splash and coalesces until completion; reverse=$reverse',
      (tester) async {
        final pending = Completer<void>();
        addTearDown(() {
          if (!pending.isCompleted) pending.complete();
        });
        var calls = 0;
        await mount(tester, () {
          calls++;
          return pending.future;
        }, reverse: reverse);
        expect(find.byType(BilFeatureWelcomeStatus), findsNothing);
        expect(find.byType(RefreshProgressIndicator), findsNothing);
        final list = find.byType(ListView);
        if (reverse) {
          // The SDK refreshes a reversed history at extentAfter == 0,
          // which is its visual top, not the newest-message end.
          final scrollable = tester.state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)),
          );
          scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
          await tester.pump();
          expect(scrollable.position.extentAfter, 0);
        }
        final position = tester.getTopLeft(list);
        // At the visual top, refresh is a downward finger drag in both orders.
        const delta = Offset(0, 400);
        await tester.drag(list, delta);
        // Start the SDK snap animation before advancing its clock.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(calls, 1);
        expect(find.byType(BilFeatureWelcomeStatus), findsOneWidget);
        expect(find.byType(RefreshProgressIndicator), findsNothing);
        expect(tester.getTopLeft(list), position);
        await tester.drag(list, delta);
        // Start the SDK snap animation before advancing its clock.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(calls, 1);
        pending.complete();
        await tester.pumpAndSettle();
        expect(find.byType(BilFeatureWelcomeStatus), findsNothing);
        expect(find.text('Preserved content'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('short pull does not run refresh or leave a waiting glyph', (
    tester,
  ) async {
    var calls = 0;
    await mount(tester, () async {
      calls++;
    });
    await tester.drag(find.byType(ListView), const Offset(0, 12));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byType(BilFeatureWelcomeStatus), findsNothing);
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending refresh can complete after its screen is disposed', (
    tester,
  ) async {
    final pending = Completer<void>();
    await mount(tester, () => pending.future);
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(BilFeatureWelcomeStatus), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
