import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'native_hold_observer.dart';

void main() {
  for (final lastVisible in [1931, 2040]) {
    test('deadline is an interval after the real $lastVisible ms frame', () {
      final timeline = NativeHoldTimeline()
        ..record(const Duration(milliseconds: 32), visible: true)
        ..record(Duration(milliseconds: lastVisible), visible: true)
        ..record(const Duration(milliseconds: 2240), visible: false);
      final json = timeline.toJson();
      expect(timeline.deadlineConsistent, isTrue);
      expect(json['deadline_inside_observation_gap'], isTrue);
      expect(json['visible_at_or_after_deadline'], isFalse);
      expect(json['last_visible_ms'], lastVisible);
      expect(
        json['expiry_observation_precision_us'],
        (2240 - lastVisible) * 1000,
      );
    });
  }

  test('missing first frame and an early negative frame fail closed', () {
    final missing = NativeHoldTimeline()
      ..record(const Duration(milliseconds: 2300), visible: false);
    final early = NativeHoldTimeline()
      ..record(const Duration(milliseconds: 32), visible: true)
      ..record(const Duration(milliseconds: 2100), visible: false);
    expect(missing.firstFrameVisible, isFalse);
    expect(missing.deadlineConsistent, isFalse);
    expect(early.deadlineConsistent, isFalse);
    expect(early.toJson()['first_absent_ms'], 2100);
  });

  test(
    'no negative frame is incomplete and observations cannot go backwards',
    () {
      final timeline = NativeHoldTimeline()
        ..record(const Duration(milliseconds: 2201), visible: true);
      expect(timeline.deadlineConsistent, isFalse);
      expect(timeline.toJson()['negative_frame_recorded'], isFalse);
      expect(
        () =>
            timeline.record(const Duration(milliseconds: 2199), visible: false),
        throwsStateError,
      );
    },
  );

  testWidgets(
    'post-frame observer captures disappearance before caller resumes',
    (tester) async {
      const welcomeKey = Key('qa-observed-hold');
      final visible = ValueNotifier(true);
      addTearDown(visible.dispose);
      final observer = NativeHoldObserver(welcome: find.byKey(welcomeKey));
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (_, show, _) => show
                ? Builder(
                    builder: (_) {
                      observer.start();
                      return const SizedBox(key: welcomeKey);
                    },
                  )
                : const SizedBox.shrink(),
          ),
        ),
      );
      expect(observer.timeline.firstFrameVisible, isTrue);
      visible.value = false;
      await tester.pump();
      final negativeFrame = observer.timeline.firstAbsent;
      expect(negativeFrame, isNotNull);
      await tester.pump(const Duration(seconds: 5));
      expect(observer.timeline.firstAbsent, negativeFrame);
      expect(observer.timeline.samples.length, 2);
      expect(tester.takeException(), isNull);
      observer.stop();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
