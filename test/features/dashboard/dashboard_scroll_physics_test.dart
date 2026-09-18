import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_shell.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard accepts finger offsets but does not start a fling', () {
    const physics = DashboardScrollPhysics();
    final position = FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 1000,
      pixels: 400,
      viewportDimension: 600,
      axisDirection: AxisDirection.down,
      devicePixelRatio: 1,
    );

    expect(physics.shouldAcceptUserOffset(position), isTrue);
    expect(physics.createBallisticSimulation(position, 1200), isNull);
  });
}
