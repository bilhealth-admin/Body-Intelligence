import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_shell.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard accepts finger offsets and keeps native fling momentum', () {
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
    expect(physics.createBallisticSimulation(position, 1200), isNotNull);
  });

  test('dashboard returns an overscroll smoothly to the nearest edge', () {
    const physics = DashboardScrollPhysics();
    final position = FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 1000,
      pixels: -42,
      viewportDimension: 600,
      axisDirection: AxisDirection.down,
      devicePixelRatio: 1,
    );

    final simulation = physics.createBallisticSimulation(position, -260);
    expect(simulation, isNotNull);
    expect(simulation!.x(0), -42);
    expect(simulation.x(10), closeTo(0, 0.1));
  });
}
