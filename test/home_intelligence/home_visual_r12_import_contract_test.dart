import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy nested dashboard carousels stay removed', () {
    final benchmark = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();

    expect(benchmark, isNot(contains("import 'dashboard_carousel.dart';")));
    expect(
      benchmark,
      isNot(contains("Key('dashboard-action-inner-carousel')")),
    );
    expect(
      benchmark,
      isNot(contains("Key('dashboard-insights-inner-carousel')")),
    );
    expect(benchmark, isNot(contains('DashboardCarousel(')));
  });
}
