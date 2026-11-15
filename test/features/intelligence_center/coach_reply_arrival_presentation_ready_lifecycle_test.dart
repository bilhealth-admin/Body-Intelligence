import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_reply_arrival.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  String id, {
  required VoidCallback ready,
  bool reduced = false,
  bool animate = true,
}) => MaterialApp(
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: Scaffold(
        body: CoachReplyArrival(
          messageId: id,
          animate: animate,
          onPresentationReady: ready,
          child: const Text(
            'The complete reply is mounted and retains its geometry.',
          ),
        ),
      ),
    ),
  ),
);

double _alpha(WidgetTester tester, String id) => tester
    .widget<FadeTransition>(
      find.byKey(ValueKey('coach-reply-arrival-fade-$id')),
    )
    .opacity
    .value;

void main() {
  testWidgets('readiness is delivered after stable paint exactly once', (
    tester,
  ) async {
    const id = 'qa-ready-once-after-paint-20261115';
    var ready = 0;
    await tester.pumpWidget(_host(id, ready: () => ready++));
    expect(ready, 0);
    await tester.pump(const Duration(milliseconds: 160));
    expect(_alpha(tester, id), greaterThan(0));
    expect(_alpha(tester, id), lessThan(1));
    expect(ready, 0);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(_alpha(tester, id), 1);
    expect(ready, 1);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(ready, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  for (final animateReplacement in [false, true]) {
    testWidgets(
      'a retired message cannot deliver or consume the replacement notice animated=$animateReplacement',
      (tester) async {
        final a = 'qa-queued-ready-owner-a-$animateReplacement';
        final b = 'qa-queued-ready-owner-b-$animateReplacement';
        var aReady = 0, bReady = 0;
        await tester.pumpWidget(_host(a, reduced: true, ready: () => aReady++));
        await tester.pump();
        expect(_alpha(tester, a), 1);
        expect(aReady, 0);
        expect(tester.binding.transientCallbackCount, 0);
        expect(
          tester.binding.hasScheduledFrame,
          isTrue,
          reason:
              'The stable reduced-motion message must request delivery without a ticker or user input.',
        );
        await tester.pumpWidget(
          _host(b, animate: animateReplacement, ready: () => bReady++),
        );
        expect(aReady, 0);
        if (animateReplacement) {
          expect(_alpha(tester, b), 0);
          expect(bReady, 0);
          await tester.pump(const Duration(milliseconds: 160));
          expect(bReady, 0);
          await tester.pump(const Duration(milliseconds: 200));
        }
        await tester.pump();
        expect(_alpha(tester, b), 1);
        expect(aReady, 0);
        expect(bReady, 1);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        expect(aReady, 0);
        expect(bReady, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'disposing a queued stable-paint notice cannot call its retired owner',
    (tester) async {
      const id = 'qa-dispose-queued-ready-20261115';
      var ready = 0;
      await tester.pumpWidget(_host(id, reduced: true, ready: () => ready++));
      await tester.pump();
      expect(_alpha(tester, id), 1);
      expect(ready, 0);
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(ready, 0);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'independent baseline: initial reduced-motion visible reply reports ready once',
    (tester) async {
      const id = 'qa-independent-initial-reduced-ready-baseline-20261115';
      var ready = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: Scaffold(
                body: CoachReplyArrival(
                  messageId: id,
                  animate: true,
                  onPresentationReady: () => ready++,
                  child: const Text('Complete reduced-motion reply'),
                ),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final alpha = tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('coach-reply-arrival-fade-$id')),
          )
          .opacity
          .value;
      expect(alpha, 1);
      expect(
        ready,
        1,
        reason:
            'Actual complete visible paint must deliver its owner callback even when no animation runs.',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'independent: raw safe-area change still regates reduced-motion first paint',
    (tester) async {
      const id = 'qa-independent-reduce-raw-safearea-20261115';
      var ready = 0;
      tester.view.viewPadding = const FakeViewPadding(bottom: 24);
      tester.view.padding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);
      await tester.pumpWidget(_host(id, ready: () => ready++));
      expect(_alpha(tester, id), 0);
      // Trigger the real geometry change while normal entrance is still at
      // alpha zero, then turn Reduce Motion on while its64ms gate is pending.
      // The fixture proves both an actual gate and that preference changes do
      // not bypass the required layout, rather than assuming first paint state.
      // Each TestFlutterView property setter emits its own notification. Apply
      // the coherent raw/derived safe-area pair as one metrics notification,
      // rather than inventing an intermediate inconsistent engine snapshot.
      tester.platformDispatcher.onMetricsChanged = null;
      try {
        tester.view.viewPadding = const FakeViewPadding(bottom: 48);
        tester.view.padding = const FakeViewPadding(bottom: 48);
      } finally {
        tester.platformDispatcher.onMetricsChanged =
            tester.binding.handleMetricsChanged;
      }
      tester.binding.handleMetricsChanged();
      expect(_alpha(tester, id), 0);
      await tester.pumpWidget(_host(id, reduced: true, ready: () => ready++));
      expect(_alpha(tester, id), 0);
      await tester.pump(const Duration(milliseconds: 32));
      expect(_alpha(tester, id), 0);
      await tester.pump(const Duration(milliseconds: 48));
      expect(_alpha(tester, id), 1);
      await tester.pump();
      await tester.pump();
      expect(ready, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
