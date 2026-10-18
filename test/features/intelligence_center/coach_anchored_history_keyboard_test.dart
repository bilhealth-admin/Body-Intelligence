import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_anchored_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('vertical history drag dismisses the focused composer', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: CoachAnchoredHistory(
                    controller: controller,
                    rowIds: List.generate(30, (index) => 'row-$index'),
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.all(18),
                      child: SelectableText('History message $index'),
                    ),
                  ),
                ),
                const TextField(key: Key('history-composer')),
              ],
            ),
          ),
        ),
      ),
    );

    final composer = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('history-composer')),
        matching: find.byType(EditableText),
      ),
    );
    await tester.tap(find.byKey(const Key('history-composer')));
    await tester.pumpAndSettle();
    expect(composer.focusNode.hasFocus, isTrue);

    final history = tester.getRect(find.byType(CoachAnchoredHistory));
    await tester.dragFrom(
      Offset(history.left + 2, history.center.dy),
      const Offset(0, 180),
    );
    await tester.pumpAndSettle();

    expect(composer.focusNode.hasFocus, isFalse);
    expect(controller.offset, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
