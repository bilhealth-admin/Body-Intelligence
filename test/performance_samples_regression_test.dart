import 'package:flutter_test/flutter_test.dart';

import 'support/performance_samples.dart';

void main() {
  test('median is stable against one high scheduler outlier', () {
    final result = PerformanceSamples.median(const <Duration>[
      Duration(milliseconds: 365),
      Duration(milliseconds: 376),
      Duration(milliseconds: 358),
      Duration(milliseconds: 615),
      Duration(milliseconds: 350),
    ]);

    expect(result, const Duration(milliseconds: 365));
  });

  test('median rejects empty or even sample sets', () {
    expect(
      () => PerformanceSamples.median(const <Duration>[]),
      throwsArgumentError,
    );
    expect(
      () => PerformanceSamples.median(const <Duration>[
        Duration(milliseconds: 100),
        Duration(milliseconds: 200),
      ]),
      throwsArgumentError,
    );
  });
}
