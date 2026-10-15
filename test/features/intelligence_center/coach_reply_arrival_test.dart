import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_reply_arrival.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'complete reply fades in softly without changing its reserved geometry',
    (tester) async {
      const messageId = 'qa-cloud-arrival-stable-geometry';
      const reply = 'The complete validated answer is available immediately.';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CoachReplyArrival(
                messageId: messageId,
                animate: true,
                child: SizedBox(
                  key: ValueKey('coach-cloud-reply-size'),
                  width: 320,
                  height: 180,
                  child: Text(reply),
                ),
              ),
            ),
          ),
        ),
      );

      final child = find.byKey(const ValueKey('coach-cloud-reply-size'));
      final initialSize = tester.getSize(child);
      final fade = find.byKey(
        const ValueKey('coach-reply-arrival-fade-$messageId'),
      );
      expect(find.text(reply), findsOneWidget);
      expect(tester.widget<FadeTransition>(fade).opacity.value, 0);

      await tester.pump(const Duration(milliseconds: 160));
      final middleOpacity = tester.widget<FadeTransition>(fade).opacity.value;
      expect(middleOpacity, greaterThan(0));
      expect(middleOpacity, lessThan(1));
      expect(tester.getSize(child), initialSize);

      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
      expect(tester.getSize(child), initialSize);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion skips the reply entrance', (tester) async {
    const messageId = 'qa-cloud-arrival-reduced-motion';
    await tester.pumpWidget(
      const MaterialApp(
        builder: _reducedMotionBuilder,
        home: Scaffold(
          body: CoachReplyArrival(
            messageId: messageId,
            animate: true,
            child: Text('Readable without motion.'),
          ),
        ),
      ),
    );

    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('coach-reply-arrival-fade-$messageId')),
          )
          .opacity
          .value,
      1,
    );
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fresh reduced-motion reply waits only for its reading layout', (
    tester,
  ) async {
    const messageId = 'qa-reduced-first-reading-layout';
    final fade = find.byKey(
      const ValueKey('coach-reply-arrival-fade-$messageId'),
    );
    double? firstLayoutOpacity;
    tester.binding.addPostFrameCallback((_) {
      firstLayoutOpacity = tester.widget<FadeTransition>(fade).opacity.value;
    });
    await tester.pumpWidget(
      const MaterialApp(
        builder: _reducedMotionBuilder,
        home: Scaffold(
          body: CoachReplyArrival(
            messageId: messageId,
            animate: true,
            child: Text('The complete reply is already available.'),
          ),
        ),
      ),
    );
    expect(firstLayoutOpacity, 0);
    expect(
      find.text('The complete reply is already available.'),
      findsOneWidget,
    );
    await tester.pump();
    expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}

Widget _reducedMotionBuilder(BuildContext context, Widget? child) => MediaQuery(
  data: MediaQuery.of(context).copyWith(disableAnimations: true),
  child: child!,
);
