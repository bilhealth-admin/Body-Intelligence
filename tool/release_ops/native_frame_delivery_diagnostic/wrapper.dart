import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Installed as an UNTRACKED QA target beside this exact original library.
import 'native_feature_splashes_test.dart' as original;

/// Diagnostic storage only. Never participates in the original pass matcher.
class NativeFrameDeliveryBuffer {
  NativeFrameDeliveryBuffer({this.maxFrames = 10000, this.maxEvents = 64}) {
    if (maxFrames < 1 || maxFrames > 10000 || maxEvents < 1 || maxEvents > 64) {
      throw ArgumentError('Diagnostic bounds exceed reviewed limits');
    }
  }

  final int maxFrames;
  final int maxEvents;
  final frames = <Map<String, Object?>>[];
  final events = <Map<String, Object?>>[];
  int framesSeen = 0;
  int batchesSeen = 0;
  int eventsSeen = 0;

  void capture(
    List<ui.FrameTiming> timings, {
    required int observedAtUs,
    required int caseSequence,
  }) {
    batchesSeen++;
    for (final timing in timings) {
      framesSeen++;
      if (frames.length >= maxFrames) continue;
      frames.add({
        'frame_number': timing.frameNumber,
        'phase_timestamps_us': {
          for (final phase in ui.FramePhase.values)
            phase.name: timing.timestampInMicroseconds(phase),
        },
        'build_us': timing.buildDuration.inMicroseconds,
        'raster_us': timing.rasterDuration.inMicroseconds,
        'total_us': timing.totalSpan.inMicroseconds,
        'callback_observed_at_suite_us': observedAtUs,
        'callback_batch': batchesSeen,
        'case_sequence_at_callback': caseSequence,
      });
    }
  }

  void event(String name, int atUs, int caseSequence, int engineFrameNumber) {
    eventsSeen++;
    if (events.length >= maxEvents) return;
    events.add({
      'event': name,
      'at_suite_us': atUs,
      'case_sequence': caseSequence,
      'current_engine_frame_number': engineFrameNumber,
      'frames_seen': framesSeen,
      'batches_seen': batchesSeen,
    });
  }

  Map<String, Object?> toJson() => {
    'classification': 'DIAGNOSTIC_ONLY',
    'result_does_not_certify_native_pass': true,
    'original_exact_matcher_unchanged': true,
    'original_delivery_budget_ms': 1000,
    'original_cold_observation_budget_ms': 3200,
    'timing_identity_policy': 'raw engine frame_number; no matching or fallback',
    'collection_scope': 'suite-wide, including after each route collector stops',
    'case_sequence_semantics': 'actual setUp/tearDown execution order; no inferred test result or name',
    'app_source': const String.fromEnvironment('BIL_QA_SOURCE_HEAD'),
    'app_tree': const String.fromEnvironment('BIL_QA_SOURCE_FINGERPRINT'),
    'controller_source': const String.fromEnvironment('BIL_DIAGNOSTIC_CONTROLLER_HEAD'),
    'wrapper_sha256': const String.fromEnvironment('BIL_DIAGNOSTIC_WRAPPER_SHA256'),
    'compile_target': 'integration_test/bil_native_frame_delivery_diagnostic.dart',
    'max_frames': maxFrames,
    'max_events': maxEvents,
    'frames_seen': framesSeen,
    'batches_seen': batchesSeen,
    'events_seen': eventsSeen,
    'frames_truncated': framesSeen > frames.length,
    'events_truncated': eventsSeen > events.length,
    'events': events,
    'native_frame_timings': frames,
  };
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final buffer = NativeFrameDeliveryBuffer();
  final watch = Stopwatch()..start();
  int caseSequence = 0;
  void mark(String name) => buffer.event(
    name,
    watch.elapsedMicroseconds,
    caseSequence,
    binding.platformDispatcher.frameData.frameNumber,
  );
  void capture(List<ui.FrameTiming> timings) => buffer.capture(
    timings,
    observedAtUs: watch.elapsedMicroseconds,
    caseSequence: caseSequence,
  );

  WidgetsBinding.instance.addTimingsCallback(capture);
  mark('suite_listener_registered');
  setUp(() {
    caseSequence++;
    mark('case_setUp');
  });
  tearDown(() => mark('case_tearDown'));
  tearDownAll(() {
    mark('suite_tearDownAll');
    WidgetsBinding.instance.removeTimingsCallback(capture);
    watch.stop();
    var report = buffer.toJson();
    final encoded = utf8.encode(jsonEncode(report));
    const maxBytes = 8 * 1024 * 1024;
    if (encoded.length > maxBytes) {
      report = {
        'classification': 'DIAGNOSTIC_ONLY_INCOMPLETE',
        'error': 'diagnostic_json_size_limit_exceeded',
        'raw_frame_count': buffer.frames.length,
        'frames_seen': buffer.framesSeen,
        'encoded_bytes': encoded.length,
        'max_bytes': maxBytes,
        'frames_truncated': true,
      };
    }
    // Original host driver preserves the scenes map even on a test failure.
    // Add one diagnostic field only; no existing evidence/result is replaced.
    final scenes = binding.reportData?['native_feature_splashes'];
    if (scenes is List && scenes.isNotEmpty && scenes.first is Map) {
      final first = scenes.first as Map;
      if (!first.containsKey('suite_frame_delivery_diagnostic')) {
        first['suite_frame_delivery_diagnostic'] = report;
      }
    }
  });
  // Register every original test and hook. No route/frame/timer manipulation.
  original.main();
}
