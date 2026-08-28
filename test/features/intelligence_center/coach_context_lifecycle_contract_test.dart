import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Coach context survives read-only async voice turns', () {
    final source = File(
      'lib/features/intelligence_center/services/coach_context_provider.dart',
    ).readAsStringSync();

    expect(
      source,
      contains(
        'final coachContextSnapshotProvider = FutureProvider<CoachContextSnapshot>',
      ),
    );
    expect(
      source,
      isNot(contains('FutureProvider.autoDispose<CoachContextSnapshot>')),
    );
  });
}
