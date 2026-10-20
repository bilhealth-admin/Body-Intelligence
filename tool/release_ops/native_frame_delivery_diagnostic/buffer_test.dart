import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import '../integration_test/bil_native_frame_delivery_diagnostic.dart' as diagnostic;

ui.FrameTiming frame(int number) => ui.FrameTiming(
  vsyncStart: 100,
  buildStart: 110,
  buildFinish: 210,
  rasterStart: 230,
  rasterFinish: 530,
  rasterFinishWallTime: 900,
  frameNumber: number,
);

void main() {
  test('raw frame identity and every engine phase survive without normalization', () {
    final buffer = diagnostic.NativeFrameDeliveryBuffer();
    buffer.capture([frame(1820)], observedAtUs: 4000001, caseSequence: 2);
    final raw = buffer.toJson()['native_frame_timings']! as List;
    expect(raw.single['frame_number'], 1820);
    expect(raw.single['phase_timestamps_us'], {
      'vsyncStart': 100,
      'buildStart': 110,
      'buildFinish': 210,
      'rasterStart': 230,
      'rasterFinish': 530,
      'rasterFinishWallTime': 900,
    });
    expect(raw.single['callback_observed_at_suite_us'], 4000001);
    expect(raw.single['case_sequence_at_callback'], 2);
    expect(raw.single['build_us'], 100);
    expect(raw.single['raster_us'], 300);
    expect(raw.single['total_us'], 430);
    expect(buffer.toJson()['result_does_not_certify_native_pass'], isTrue);
  });

  test('duplicates and late rows are retained rather than joined or deduplicated', () {
    final buffer = diagnostic.NativeFrameDeliveryBuffer();
    buffer.capture([frame(1820)], observedAtUs: 100, caseSequence: 1);
    buffer.event('case_tearDown', 200, 1, 1821);
    buffer.capture([frame(1820), frame(1900)], observedAtUs: 500, caseSequence: 2);
    expect(buffer.frames.map((row) => row['frame_number']), [1820, 1820, 1900]);
    expect(buffer.frames.last['callback_batch'], 2);
    expect(buffer.frames[1]['callback_observed_at_suite_us'], 500);
    expect(buffer.toJson()['frames_truncated'], isFalse);
  });

  test('frame and event caps preserve early evidence and explicitly flag loss', () {
    final buffer = diagnostic.NativeFrameDeliveryBuffer(maxFrames: 2, maxEvents: 1);
    buffer.capture([frame(1), frame(2), frame(3)], observedAtUs: 10, caseSequence: 1);
    buffer.capture([frame(4)], observedAtUs: 20, caseSequence: 1);
    buffer.event('case_setUp', 1, 1, 0);
    buffer.event('case_tearDown', 30, 1, 4);
    expect(buffer.frames.map((row) => row['frame_number']), [1, 2]);
    expect(buffer.framesSeen, 4);
    expect(buffer.batchesSeen, 2);
    expect(buffer.events.length, 1);
    expect(buffer.toJson()['frames_truncated'], isTrue);
    expect(buffer.toJson()['events_truncated'], isTrue);
  });

  test('unknown frame number is preserved and reviewed bounds cannot expand', () {
    final buffer = diagnostic.NativeFrameDeliveryBuffer();
    buffer.capture([frame(-1)], observedAtUs: 1, caseSequence: 0);
    expect(buffer.frames.single['frame_number'], -1);
    expect(() => diagnostic.NativeFrameDeliveryBuffer(maxFrames: 10001), throwsArgumentError);
    expect(() => diagnostic.NativeFrameDeliveryBuffer(maxFrames: 0), throwsArgumentError);
    expect(() => diagnostic.NativeFrameDeliveryBuffer(maxEvents: 65), throwsArgumentError);
  });
}
