import 'package:flutter_test/flutter_test.dart';

import 'package:body_intelligence_log/features/dashboard/domain/dashboard_heart_health_policy.dart';

void main() {
  test('heart-health meters use explicit reference maxima and cap at 100%', () {
    expect(DashboardHeartHealthPolicy.potassiumMaximumMg, 4700);
    expect(DashboardHeartHealthPolicy.sodiumMaximumMg, 2300);
    expect(DashboardHeartHealthPolicy.fiberMaximumG, 35);
    expect(
      DashboardHeartHealthPolicy.coverage(recorded: 1150, maximum: 2300),
      .5,
    );
    expect(
      DashboardHeartHealthPolicy.coverage(recorded: 5000, maximum: 2300),
      1,
    );
    expect(
      DashboardHeartHealthPolicy.coverage(recorded: null, maximum: 2300),
      0,
    );
  });
}
