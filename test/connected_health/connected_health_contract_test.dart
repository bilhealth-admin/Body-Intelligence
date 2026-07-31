import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('connected health card is independent from personal health AI', () {
    final grid = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();
    final personal = File(
      'lib/features/dashboard/widgets/personal_health_ai_panel.dart',
    ).readAsStringSync();
    final connected = File(
      'lib/features/connected_health/widgets/connected_health_card.dart',
    ).readAsStringSync();

    expect(grid, contains('ConnectedHealthCard('));
    expect(grid, contains('personalHealthAi: personalHealthAiPanel'));
    expect(personal, isNot(contains('ConnectedHealth')));
    expect(connected, contains('PremiumSurface('));
    expect(connected, contains('DashboardCarousel('));
    expect(connected, contains("Key('connected-health-card')"));
  });

  test('connected health uses existing global platform runtimes', () {
    final provider = File(
      'lib/features/connected_health/providers/connected_health_provider.dart',
    ).readAsStringSync();

    expect(provider, contains('globalProductFlowsProvider'));
    expect(provider, contains('_flows.appleHealth.synchronize'));
    expect(provider, contains('_flows.healthConnect.synchronize'));
    expect(provider, contains("'connected_health_ui'"));
    expect(provider, isNot(contains('http://')));
    expect(provider, isNot(contains('https://')));
  });

  test('management route is registered', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    expect(router, contains("path: '/connected-health'"));
    expect(router, contains('ConnectedHealthPage'));
  });
}
