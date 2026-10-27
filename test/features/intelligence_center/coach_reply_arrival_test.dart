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

  testWidgets(
    'repeated native metric notifications cannot keep the first reply hidden',
    (tester) async {
      const messageId = 'qa-cloud-arrival-metric-churn';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _MetricChurner(
              child: CoachReplyArrival(
                messageId: messageId,
                animate: true,
                child: const Text('The complete reply remains readable.'),
              ),
            ),
          ),
        ),
      );
      final fade = find.byKey(
        const ValueKey('coach-reply-arrival-fade-$messageId'),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
      await tester.pumpWidget(const SizedBox.shrink());
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

  testWidgets(
    'closing IME cannot starve first paint under recorded native frame gaps',
    (tester) async {
      const messageId = 'qa-native-closing-ime-frame-gaps';
      tester.view.viewPadding = const FakeViewPadding(bottom: 24);
      tester.view.padding = FakeViewPadding.zero;
      tester.view.viewInsets = const FakeViewPadding(bottom: 264.3809523809524);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CoachReplyArrival(
              messageId: messageId,
              animate: true,
              child: Text('The complete reply is ready while the IME closes.'),
            ),
          ),
        ),
      );
      final fade = find.byKey(
        const ValueKey('coach-reply-arrival-fade-$messageId'),
      );
      final samples = <({int milliseconds, double opacity})>[];
      var elapsed = 0;
      // API33's failed native trace: 520, 750, 1256, 1452 and 1519ms.
      // These are virtual frame gaps for a behavior regression, not a speed claim.
      for (final frame in <({int gap, double inset})>[
        (gap: 520, inset: 65.1619844590557),
        (gap: 230, inset: 0),
        (gap: 506, inset: 264.3809523809524),
        (gap: 196, inset: 65.1619844590557),
        (gap: 67, inset: 65.1619844590557),
      ]) {
        tester.view.padding = FakeViewPadding(
          bottom: frame.inset == 0 ? 24 : 0,
        );
        tester.view.viewInsets = FakeViewPadding(bottom: frame.inset);
        await tester.pump(Duration(milliseconds: frame.gap));
        elapsed += frame.gap;
        samples.add((
          milliseconds: elapsed,
          opacity: tester.widget<FadeTransition>(fade).opacity.value,
        ));
      }
      expect(
        samples.where(
          (frame) => frame.milliseconds <= 1500 && frame.opacity > 0,
        ),
        isNotEmpty,
        reason:
            'A retracting IME must not repeatedly reset a ready reply to zero.',
      );
      expect(samples.last.opacity, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _MetricChurner extends StatefulWidget {
  const _MetricChurner({required this.child});

  final Widget child;

  @override
  State<_MetricChurner> createState() => _MetricChurnerState();
}

class _MetricChurnerState extends State<_MetricChurner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 16),
          )
          ..addListener(WidgetsBinding.instance.handleMetricsChanged)
          ..repeat();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

Widget _reducedMotionBuilder(BuildContext context, Widget? child) => MediaQuery(
  data: MediaQuery.of(context).copyWith(disableAnimations: true),
  child: child!,
);
