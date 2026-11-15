import 'package:body_intelligence_log/shared/widgets/bil_compact_activity_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/native_feature_splashes_test.dart' as native;
import '../../../tools/qa/flutter/native_compact_activity_evidence.dart';

// These are protocol-only fixtures, not substitutes for actual pixel reads.
Map<String, Object?> _evidence({bool reduced = false}) => {
  'schema': nativeCompactActivityEvidenceSchema,
  'indicator_kind': 'BIL_COMPACT_CIRCULAR_WAIT',
  'render_width': 24.0,
  'render_height': 24.0,
  'crop_width': 24,
  'crop_height': 24,
  'reduced_motion': reduced,
  'first_foreground_pixel_count': 50,
  'second_foreground_pixel_count': 55,
  'distinct_rgba_colors': 20,
  'changed_rgba_pixel_count': reduced ? 0 : 30,
  'indeterminate_without_percentage': true,
  'sample_interval_ms': 320,
  'sampling_scope': nativeCompactActivitySamplingScope,
};

Widget _frame({required bool reduced, required Widget child}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: RepaintBoundary(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: child),
      ),
    ),
  ),
);

void main() {
  test('strict native compact paint contract accepts both observed modes', () {
    expect(isNativeCompactActivityPaintEvidence(_evidence()), isTrue);
    expect(
      isNativeCompactActivityPaintEvidence(_evidence(reduced: true)),
      isTrue,
    );
  });

  test('native compact paint contract rejects missing and extra fields', () {
    for (final key in _evidence().keys) {
      final missing = _evidence()..remove(key);
      expect(
        isNativeCompactActivityPaintEvidence(missing),
        isFalse,
        reason: key,
      );
    }
    expect(
      isNativeCompactActivityPaintEvidence({..._evidence(), 'percentage': 72}),
      isFalse,
    );
  });

  test('native compact contract rejects legacy and determinate reports', () {
    for (final mutant in [
      {..._evidence(), 'schema': 'bil.legacy-capsule.v1'},
      {..._evidence(), 'indicator_kind': 'BIL_SPLASH_CAPSULE'},
      {..._evidence(), 'indeterminate_without_percentage': false},
      {..._evidence(), 'sample_interval_ms': 0},
    ]) {
      expect(isNativeCompactActivityPaintEvidence(mutant), isFalse);
    }
  });

  test('native compact contract refuses blank and contradictory motion', () {
    for (final mutant in [
      {..._evidence(), 'first_foreground_pixel_count': 0},
      {..._evidence(), 'second_foreground_pixel_count': 0},
      {..._evidence(), 'distinct_rgba_colors': 1},
      {..._evidence(), 'changed_rgba_pixel_count': 0},
      {..._evidence(reduced: true), 'changed_rgba_pixel_count': 1},
    ]) {
      expect(isNativeCompactActivityPaintEvidence(mutant), isFalse);
    }
  });

  test('native compact contract validates pixel budgets and dimensions', () {
    for (final mutant in [
      {..._evidence(), 'render_width': 112},
      {..._evidence(), 'render_height': 7},
      {..._evidence(), 'render_width': double.nan},
      {..._evidence(), 'crop_width': 26},
      {..._evidence(), 'changed_rgba_pixel_count': 577},
      {..._evidence(), 'first_foreground_pixel_count': '50'},
      {..._evidence(), 'reduced_motion': 'false'},
    ]) {
      expect(isNativeCompactActivityPaintEvidence(mutant), isFalse);
    }
  });

  testWidgets('actual compact probe rejects an unpainted reduced indicator', (
    tester,
  ) async {
    try {
      await tester.pumpWidget(
        _frame(
          reduced: true,
          child: const Opacity(
            opacity: 0,
            child: BilCompactActivityIndicator(),
          ),
        ),
      );
      await tester.pump();
      await expectLater(
        native.verifyNativeCompactActivityProbe(
          tester,
          find.byType(BilCompactActivityIndicator),
          reduced: true,
        ),
        throwsA(isA<TestFailure>()),
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('actual compact probe rejects a frozen normal indicator', (
    tester,
  ) async {
    try {
      await tester.pumpWidget(
        _frame(
          reduced: false,
          child: const TickerMode(
            enabled: false,
            child: BilCompactActivityIndicator(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 160));
      await expectLater(
        native.verifyNativeCompactActivityProbe(
          tester,
          find.byType(BilCompactActivityIndicator),
          reduced: false,
        ),
        throwsA(isA<TestFailure>()),
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
