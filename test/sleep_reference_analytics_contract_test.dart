import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sleep insights expose measured total, honest stages, and meal link', () {
    final source = File(
      'lib/features/wellness/presentation/sleep_tracker_experience.dart',
    ).readAsStringSync();
    expect(source, contains("key: const Key('sleep-stage-overview')"));
    expect(source, contains("const Text('N/A'"));
    expect(source, contains("context.push('/connected-health')"));
    expect(source, contains('ref.watch(dailyMealsProvider)'));
    expect(source, contains("context.push('/daily-log')"));
  });
}
