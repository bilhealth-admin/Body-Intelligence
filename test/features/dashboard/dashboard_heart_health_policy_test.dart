import 'package:flutter_test/flutter_test.dart';

import 'package:body_intelligence_log/features/dashboard/domain/dashboard_heart_health_policy.dart';

void main() {
  test('heart-health meters use WHO daily defaults and cap at 100%', () {
    expect(DashboardHeartHealthPolicy.potassiumDailyTargetMg, 3510);
    expect(DashboardHeartHealthPolicy.sodiumDailyReferenceMg, 2000);
    expect(DashboardHeartHealthPolicy.fiberDailyTargetG, 25);
    expect(DashboardHeartHealthPolicy.potassiumGoal(null), 3510);
    expect(DashboardHeartHealthPolicy.sodiumGoal(null), 2000);
    expect(DashboardHeartHealthPolicy.fiberGoal(null), 25);
    expect(DashboardHeartHealthPolicy.potassiumGoal(4200), 4200);
    expect(
      DashboardHeartHealthPolicy.coverage(recorded: 1000, maximum: 2000),
      .5,
    );
    expect(
      DashboardHeartHealthPolicy.coverage(recorded: 5000, maximum: 2000),
      1,
    );
    expect(
      DashboardHeartHealthPolicy.coverage(recorded: null, maximum: 2000),
      0,
    );
  });
}
