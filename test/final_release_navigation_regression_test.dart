import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/shared/widgets/bil_modal_bottom_sheet.dart';

import 'responsive_shell_test.dart' as harness;

void main() {
  testWidgets(
    'double opening a sheet coalesces and completes after its barrier is removed',
    (tester) async {
      Future<int?>? first;
      Future<int?>? duplicate;
      var returned = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  Widget sheet(BuildContext inner) => TextButton(
                    onPressed: () => Navigator.pop(inner, 7),
                    child: const Text('select'),
                  );
                  first =
                      showBilModalBottomSheet<int>(
                        context: context,
                        builder: sheet,
                      ).then((value) {
                        returned = true;
                        return value;
                      });
                  duplicate = showBilModalBottomSheet<int>(
                    context: context,
                    builder: sheet,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('select'), findsOneWidget);
      expect(await duplicate, isNull);
      await tester.tap(find.text('select'));
      await tester.pump();
      expect(returned, isFalse);
      await tester.pumpAndSettle();
      expect(await first, 7);
      expect(find.text('select'), findsNothing);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('select'), findsOneWidget);
      await tester.tap(find.text('select'));
      await tester.pumpAndSettle();
      expect(await first, 7);
    },
  );
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      'dock survives repeated tab and Quick Add cycles on $platform',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          harness.shellApp(theme: ThemeData(platform: platform)),
        );
        await tester.pumpAndSettle();
        for (var cycle = 0; cycle < 4; cycle++) {
          await tester.tap(find.byKey(const Key('shell-more-destination')));
          await tester.pumpAndSettle();
          expect(
            find.text('settings'),
            findsOneWidget,
            reason: 'More cycle $cycle',
          );
          await tester.tap(
            find.byKey(const Key('shell-dashboard-destination')),
          );
          await tester.pumpAndSettle();
          expect(
            find.text('dashboard'),
            findsOneWidget,
            reason: 'Dashboard cycle $cycle',
          );
          await tester.tap(find.byKey(const Key('shell-quick-add')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('quick-add-half-sheet')), findsOneWidget);
          await tester.tapAt(const Offset(10, 40));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('quick-add-half-sheet')), findsNothing);
          await tester.tap(find.byKey(const Key('shell-quick-add')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Log food'));
          await tester.pumpAndSettle();
          expect(find.text('daily-log'), findsOneWidget);
          expect(find.byKey(const Key('quick-add-half-sheet')), findsNothing);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('shell-more-destination')));
          await tester.pumpAndSettle();
          expect(find.text('settings'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
