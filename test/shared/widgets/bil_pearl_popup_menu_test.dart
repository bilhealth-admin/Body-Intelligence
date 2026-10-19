import 'package:body_intelligence_log/app/theme/bil_pearl_finish.dart';
import 'package:body_intelligence_log/shared/widgets/bil_pearl_popup_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final direction in TextDirection.values) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'pearl popup preserves selection, disabled actions and cancel $direction $brightness',
        (tester) async {
          String? selected;
          var cancelled = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: Directionality(
                textDirection: direction,
                child: Scaffold(
                  body: Center(
                    child: bilPearlPopupMenuButton<String>(
                      key: const Key('menu'),
                      initialValue: 'report',
                      onSelected: (value) => selected = value,
                      onCanceled: () => cancelled++,
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'report',
                          child: Text('Report content'),
                        ),
                        PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'delete',
                          enabled: false,
                          child: Text('Delete content'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.byKey(const Key('menu')));
          await tester.pumpAndSettle();
          final item = find.text('Report content');
          final finish = tester
              .widgetList<Ink>(
                find.ancestor(of: item, matching: find.byType(Ink)),
              )
              .where(
                (box) => (box.decoration as BoxDecoration).gradient != null,
              )
              .first;
          expect(
            (finish.decoration as BoxDecoration).gradient,
            BilPearlFinish.panel(tester.element(item), shadow: false).gradient,
          );
          await tester.tap(find.text('Delete content'));
          await tester.pumpAndSettle();
          expect(selected, isNull);
          expect(item, findsOneWidget);
          await tester.tap(item);
          await tester.pumpAndSettle();
          expect(selected, 'report');
          expect(cancelled, 0);
          await tester.tap(find.byKey(const Key('menu')));
          await tester.pumpAndSettle();
          await tester.tapAt(const Offset(5, 5));
          await tester.pumpAndSettle();
          expect(cancelled, 1);
          expect(selected, 'report');
        },
      );
    }
  }
}
