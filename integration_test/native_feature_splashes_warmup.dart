part of 'native_feature_splashes_test.dart';

/// Pure identity join. Presentation targets and vsync starts are different
/// phases, so matching or normalizing their timestamps cannot identify a frame.
({String status, Map<String, Object?>? timing}) nativeQaMatchFrameTiming({
  required int? frameNumber,
  required Iterable<Map<String, Object?>> timings,
}) {
  if (frameNumber == null || frameNumber < 0) {
    return (status: 'unavailable_frame_identity', timing: null);
  }
  final matches = timings.where(
    (timing) =>
        timing['frame_number'] is int && timing['frame_number'] == frameNumber,
  );
  final iterator = matches.iterator;
  if (!iterator.moveNext()) {
    return (status: 'missing_exact_frame_timing', timing: null);
  }
  final match = iterator.current;
  if (iterator.moveNext()) {
    return (status: 'ambiguous_frame_identity', timing: null);
  }
  return (status: 'matched_frame_identity', timing: match);
}

/// A separate real route visit, never part of the measured repeat visit.
/// Retain cold evidence even if the observer budget or destination fails.
class _NativeEntryWarmupTrace {
  _NativeEntryWarmupTrace(this.kind);

  final String kind;
  final nativeTimings = <Map<String, Object?>>[];
  NativeHoldObserver? observer;
  int? originTargetUs, endTargetUs, absentTargetUs, destinationReadyUs;
  int? originFrameNumber, endFrameNumber, absentFrameNumber;
  bool active = false, completed = false, timingsTruncated = false;

  void start() {
    active = true;
    WidgetsBinding.instance.addTimingsCallback(_timings);
  }

  void attach(String entryKind, NativeHoldObserver value) {
    if (!active || entryKind != kind) return;
    if (observer != null) throw StateError('Warm-up route remounted: $kind');
    observer = value;
    originTargetUs =
        WidgetsBinding.instance.currentSystemFrameTimeStamp.inMicroseconds;
    originFrameNumber =
        WidgetsBinding.instance.platformDispatcher.frameData.frameNumber;
    WidgetsBinding.instance.addPostFrameCallback(_sample);
  }

  void _sample(Duration _) {
    if (!active) return;
    if (observer?.timeline.firstAbsent != null) {
      absentTargetUs ??=
          WidgetsBinding.instance.currentSystemFrameTimeStamp.inMicroseconds;
      absentFrameNumber ??=
          WidgetsBinding.instance.platformDispatcher.frameData.frameNumber;
    }
    // Observe real frames without scheduling frames or changing the hold.
    WidgetsBinding.instance.addPostFrameCallback(_sample);
  }

  void _timings(List<ui.FrameTiming> values) {
    if (!active || originFrameNumber == null) return;
    for (final value in values) {
      final vsyncUs = value.timestampInMicroseconds(ui.FramePhase.vsyncStart);
      if (value.frameNumber < originFrameNumber! ||
          (endFrameNumber != null && value.frameNumber > endFrameNumber!)) {
        continue;
      }
      if (nativeTimings.length >= 500) {
        timingsTruncated = true;
        continue;
      }
      nativeTimings.add({
        'frame_number': value.frameNumber,
        'vsync_start_us': vsyncUs,
        'build_start_us': value.timestampInMicroseconds(
          ui.FramePhase.buildStart,
        ),
        'build_finish_us': value.timestampInMicroseconds(
          ui.FramePhase.buildFinish,
        ),
        'raster_start_us': value.timestampInMicroseconds(
          ui.FramePhase.rasterStart,
        ),
        'raster_finish_us': value.timestampInMicroseconds(
          ui.FramePhase.rasterFinish,
        ),
        'build_us': value.buildDuration.inMicroseconds,
        'raster_us': value.rasterDuration.inMicroseconds,
        'total_us': value.totalSpan.inMicroseconds,
        'callback_observed_at_us': observer!.watch.elapsedMicroseconds,
      });
    }
  }

  ({String status, Map<String, Object?>? timing}) get absentFrameTimingMatch =>
      nativeQaMatchFrameTiming(
        frameNumber: absentFrameNumber,
        timings: nativeTimings,
      );

  bool get absentFrameTimingReceived =>
      absentFrameTimingMatch.status == 'matched_frame_identity';

  Future<void> complete(WidgetTester tester) async {
    await tester.pump();
    final hold = observer!;
    expect(originFrameNumber, greaterThanOrEqualTo(0));
    expect(hold.timeline.firstFrameVisible, isTrue);
    while (hold.timeline.firstAbsent == null &&
        hold.watch.elapsedMilliseconds < 4500) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(hold.timeline.deadlineConsistent, isTrue);
    expect(_welcome(kind), findsNothing);
    if (kind == 'coach') {
      final composer = find.byKey(const Key('ai-coach-question-field'));
      bool ready() =>
          composer.hitTestable().evaluate().length == 1 &&
          tester.widget<TextField>(composer).enabled == true;
      while (!ready() && hold.watch.elapsedMilliseconds < 4500) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(composer.hitTestable(), findsOneWidget);
      expect(tester.widget<TextField>(composer).enabled, isTrue);
    } else if (kind == 'diet') {
      expect(find.byType(NutritionPathwaysPage), findsOneWidget);
    } else {
      expect(find.byKey(ValueKey('native-destination-$kind')), findsOneWidget);
    }
    destinationReadyUs = hold.watch.elapsedMicroseconds;
    await _nativeSettle(tester);
    endTargetUs =
        WidgetsBinding.instance.currentSystemFrameTimeStamp.inMicroseconds;
    endFrameNumber =
        WidgetsBinding.instance.platformDispatcher.frameData.frameNumber;
    // Engine timings are batched (about 100ms in debug). Drain outside the
    // measured visit; never invent a missing release-frame raster duration.
    final delivery = Stopwatch()..start();
    while (!absentFrameTimingReceived && delivery.elapsedMilliseconds < 1000) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(
      absentFrameTimingReceived,
      isTrue,
      reason:
          'Exact engine frame identity required: ${absentFrameTimingMatch.status}',
    );
    expect(timingsTruncated, isFalse);
    expect(tester.takeException(), isNull);
    completed = true;
  }

  void stop() {
    active = false;
    endTargetUs ??=
        WidgetsBinding.instance.currentSystemFrameTimeStamp.inMicroseconds;
    endFrameNumber ??=
        WidgetsBinding.instance.platformDispatcher.frameData.frameNumber;
    WidgetsBinding.instance.removeTimingsCallback(_timings);
    observer?.stop();
  }

  Map<String, Object?> toJson() {
    final hold = observer;
    final match = absentFrameTimingMatch;
    final reportedStartUs = match.timing?['vsync_start_us'];
    return {
      'kind': kind,
      'visit': 'cold QA warm-up, separate from measured repeat visit',
      'preparation_scope':
          'first full route visit in this QA case, after shared asset precache; not a cold app launch',
      'completed_to_destination': destinationReadyUs != null,
      'warmup_evidence_complete': completed,
      'destination_ready_at_us': destinationReadyUs,
      'coach_composer_enabled_verified': kind == 'coach'
          ? destinationReadyUs != null
          : null,
      'cold_observation_budget_met':
          hold == null || hold.timeline.firstAbsent == null
          ? null
          : hold.timeline.deadlineConsistent &&
                hold.timeline.firstAbsent!.inMilliseconds < 3200,
      'cold_scope':
          'diagnostic cold visit; repeat-visit success does not certify cold performance',
      if (hold != null) ...hold.toJson(),
      'engine_origin_frame_number': originFrameNumber,
      'engine_end_frame_number': endFrameNumber,
      'first_absent_frame_number': absentFrameNumber,
      'engine_origin_presentation_target_us': originTargetUs,
      'engine_end_presentation_target_us': endTargetUs,
      'first_absent_presentation_target_us': absentTargetUs,
      'first_absent_reported_vsync_start_us': reportedStartUs,
      'first_absent_target_minus_vsync_start_us':
          absentTargetUs != null && reportedStartUs is int
          ? absentTargetUs! - reportedStartUs
          : null,
      'first_absent_frame_timing_received': absentFrameTimingReceived,
      'first_absent_frame_timing_status': match.status,
      'first_absent_reported_frame_timing': match.timing,
      'engine_timestamp_semantics':
          'post-frame raw timestamp is presentation target, not vsync start; '
          'correlation uses exact engine frame_number, never nearest timestamp '
          'or a fixed frame-period adjustment',
      'native_frame_timings': nativeTimings,
      'frame_timings_truncated': timingsTruncated,
    };
  }
}
