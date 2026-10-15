import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wall-clock observations, not nominal pump durations or an interpolated
/// expiry time. A deadline inside a frame gap is reported as an interval.
class NativeHoldTimeline {
  NativeHoldTimeline({this.requiredHold = const Duration(milliseconds: 2200)});

  final Duration requiredHold;
  final samples = <({Duration elapsed, bool visible})>[];

  void record(Duration elapsed, {required bool visible}) {
    if (elapsed.isNegative ||
        (samples.isNotEmpty && elapsed < samples.last.elapsed)) {
      throw StateError('Native hold observations must be monotonic');
    }
    samples.add((elapsed: elapsed, visible: visible));
  }

  bool get firstFrameVisible => samples.isNotEmpty && samples.first.visible;
  Duration? get firstVisible =>
      samples.where((sample) => sample.visible).firstOrNull?.elapsed;
  Duration? get firstAbsent =>
      samples.where((sample) => !sample.visible).firstOrNull?.elapsed;
  Duration? get lastVisible {
    final absent = firstAbsent;
    return samples
        .where(
          (sample) =>
              sample.visible && (absent == null || sample.elapsed <= absent),
        )
        .lastOrNull
        ?.elapsed;
  }

  bool get deadlineConsistent =>
      firstFrameVisible &&
      lastVisible != null &&
      firstAbsent != null &&
      firstAbsent! >= requiredHold;

  Map<String, Object?> toJson() {
    final absent = firstAbsent;
    final visible = lastVisible;
    var maximumGap = Duration.zero;
    for (var i = 1; i < samples.length; i++) {
      final gap = samples[i].elapsed - samples[i - 1].elapsed;
      if (gap > maximumGap) maximumGap = gap;
    }
    return {
      'required_hold_ms': requiredHold.inMilliseconds,
      'first_frame_visible': firstFrameVisible,
      'first_visible_ms': firstVisible?.inMilliseconds,
      'last_visible_ms': visible?.inMilliseconds,
      'first_absent_ms': absent?.inMilliseconds,
      'negative_frame_recorded': absent != null,
      'deadline_consistent_with_observations': deadlineConsistent,
      'visible_at_or_after_deadline':
          visible != null && visible >= requiredHold,
      'deadline_inside_observation_gap':
          visible != null &&
          absent != null &&
          visible < requiredHold &&
          absent >= requiredHold,
      'expiry_observation_precision_us': visible == null || absent == null
          ? null
          : (absent - visible).inMicroseconds,
      'maximum_frame_gap_us': maximumGap.inMicroseconds,
      'samples': [
        for (final sample in samples)
          {'at_us': sample.elapsed.inMicroseconds, 'visible': sample.visible},
      ],
      'measurement_scope':
          'post-frame wall clock; expiry is bracketed by actual positive and '
          'negative frames, never inferred from the requested pump interval',
    };
  }
}

/// Installed during the route's mount, before its first layout. It records the
/// first absent frame even if a live tester.pump future resumes much later.
/// This observer never schedules a frame or changes a production timer.
class NativeHoldObserver {
  NativeHoldObserver({required this.welcome, this.readVisibleFrame});

  final Finder welcome;
  final Map<String, Object?> Function()? readVisibleFrame;
  final watch = Stopwatch();
  final timeline = NativeHoldTimeline();
  Map<String, Object?>? firstVisibleFrame;
  bool _active = false;

  void start() {
    _active = true;
    watch.start();
    WidgetsBinding.instance.addPostFrameCallback(_sample);
  }

  void _sample(Duration _) {
    if (!_active) return;
    final visible = welcome.evaluate().isNotEmpty;
    timeline.record(watch.elapsed, visible: visible);
    if (visible) {
      firstVisibleFrame ??= readVisibleFrame?.call();
      WidgetsBinding.instance.addPostFrameCallback(_sample);
    } else {
      _active = false;
    }
  }

  void stop() {
    _active = false;
    watch.stop();
  }

  Map<String, Object?> toJson() => {
    ...timeline.toJson(),
    'first_visible_frame': firstVisibleFrame,
    'observation_origin': 'route mount, before the first child layout',
  };
}

Future<Map<String, Object?>> observeNativeHoldEnd(
  WidgetTester tester,
  NativeHoldObserver observer,
) async {
  try {
    while (observer.timeline.firstAbsent == null &&
        observer.watch.elapsedMilliseconds < 4500) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(
      observer.timeline.deadlineConsistent,
      isTrue,
      reason:
          'Missing first/negative frames and absence before 2.2s fail. '
          'A deadline inside a frame gap remains an explicit interval.',
    );
    expect(
      observer.timeline.firstAbsent?.inMilliseconds,
      lessThan(3200),
      reason:
          'Existing debug-emulator observation budget, not a production SLA.',
    );
    return observer.toJson();
  } finally {
    observer.stop();
  }
}
