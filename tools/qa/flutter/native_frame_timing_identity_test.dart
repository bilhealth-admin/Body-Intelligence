import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/native_feature_splashes_test.dart' as native;

void main() {
  test('same frame joins despite target and start being different phases', () {
    const presentationTargetUs = 1016666;
    const timing = <String, Object?>{
      'frame_number': 7,
      'vsync_start_us': 1000000,
      'build_us': 100,
      'raster_us': 200,
    };
    final result = native.nativeQaMatchFrameTiming(
      frameNumber: 7,
      timings: [timing],
    );
    expect(result.status, 'matched_frame_identity');
    expect(result.timing, same(timing));
    expect(result.timing!['vsync_start_us'], isNot(presentationTargetUs));
    expect(
      presentationTargetUs - (result.timing!['vsync_start_us']! as int),
      16666,
    );
    expect(result.timing!['raster_us'], 200);
  });

  test(
    'identity does not assume any fixed frame period or timestamp epoch',
    () {
      const timing = <String, Object?>{
        'frame_number': 41,
        'vsync_start_us': 135000000,
      };
      final result = native.nativeQaMatchFrameTiming(
        frameNumber: 41,
        timings: [timing],
      );
      expect(result.status, 'matched_frame_identity');
      expect(result.timing, same(timing));
    },
  );

  test('equal timestamp on another frame never replaces missing identity', () {
    final result = native.nativeQaMatchFrameTiming(
      frameNumber: 99,
      timings: [
        {'frame_number': 100, 'vsync_start_us': 2924166962},
      ],
    );
    expect(result.status, 'missing_exact_frame_timing');
    expect(result.timing, isNull);
  });

  test('nearby earlier and later frames never manufacture an absent frame', () {
    final result = native.nativeQaMatchFrameTiming(
      frameNumber: 99,
      timings: [
        {'frame_number': 98, 'vsync_start_us': 2924150296},
        {'frame_number': 100, 'vsync_start_us': 2924200296},
      ],
    );
    expect(result.status, 'missing_exact_frame_timing');
    expect(result.timing, isNull);
  });

  test('unavailable engine identity stays distinct from missing timing', () {
    for (final frameNumber in [null, -1]) {
      final result = native.nativeQaMatchFrameTiming(
        frameNumber: frameNumber,
        timings: [
          {'frame_number': 99},
        ],
      );
      expect(result.status, 'unavailable_frame_identity');
      expect(result.timing, isNull);
    }
    final missing = native.nativeQaMatchFrameTiming(
      frameNumber: 99,
      timings: [],
    );
    expect(missing.status, 'missing_exact_frame_timing');
    expect(missing.timing, isNull);
  });

  test('duplicate frame identities are ambiguous and cannot pass', () {
    final result = native.nativeQaMatchFrameTiming(
      frameNumber: 99,
      timings: [
        {'frame_number': 99, 'vsync_start_us': 10},
        {'frame_number': 99, 'vsync_start_us': 20},
      ],
    );
    expect(result.status, 'ambiguous_frame_identity');
    expect(result.timing, isNull);
  });

  test('serialized or noninteger identity is never coerced to the frame', () {
    final result = native.nativeQaMatchFrameTiming(
      frameNumber: 99,
      timings: [
        {'frame_number': '99'},
        {'frame_number': 99.0},
      ],
    );
    expect(result.status, 'missing_exact_frame_timing');
    expect(result.timing, isNull);
  });

  test('batched timing order is independent of exact identity matching', () {
    const match = <String, Object?>{'frame_number': 0, 'vsync_start_us': 123};
    final result = native.nativeQaMatchFrameTiming(
      frameNumber: 0,
      timings: [
        {'frame_number': 2},
        match,
        {'frame_number': 1},
      ],
    );
    expect(result.status, 'matched_frame_identity');
    expect(result.timing, same(match));
  });
}
