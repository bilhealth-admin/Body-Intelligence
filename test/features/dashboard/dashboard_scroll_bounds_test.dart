import 'dart:async';

import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform: both edges rebound while refresh is pending, '
        'with no duplicate dock space', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final pending = Completer<void>();
      var refreshes = 0;
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
                  onRefresh: () {
                    refreshes++;
                    return pending.future;
                  },
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
      expect(refreshes, 1);
      expect(pending.isCompleted, isFalse);
      expect(position.pixels, closeTo(position.minScrollExtent, .5));

      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      await tester.drag(viewport, const Offset(0, -280));
      await tester.pumpAndSettle();
      expect(refreshes, 1, reason: 'A bottom pull never starts refresh');
      expect(position.pixels, closeTo(position.maxScrollExtent, .5));
      final end = tester.getBottomRight(
        find.byKey(const Key('last-dashboard-card')),
      );
      expect(tester.getBottomRight(viewport).dy - end.dy, closeTo(16, .5));

      updateContent(() => contentHeight = 1000);
      await tester.pumpAndSettle();
      expect(position.outOfRange, isFalse);
      expect(position.pixels, closeTo(position.maxScrollExtent, .5));
      pending.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
