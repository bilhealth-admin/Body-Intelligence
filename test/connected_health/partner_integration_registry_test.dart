import 'dart:io';

import 'package:body_intelligence_log/features/connected_health/partner_integration_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only shipping native and BLE bridges are connectable', () {
    final connectable = PartnerIntegrationRegistry.capabilities
        .where((entry) => entry.canConnect)
        .map((entry) => entry.id)
        .toSet();

    expect(connectable, {'health-connect', 'healthkit', 'medical-ble'});
    expect(PartnerIntegrationRegistry.byId('garmin').canConnect, isFalse);
    expect(PartnerIntegrationRegistry.byId('fitbit').canConnect, isFalse);
    expect(
      PartnerIntegrationRegistry.byId('samsung-health').state,
      PartnerIntegrationState.noAdapter,
    );
  });

  test('unsupported partner entries expose no invented data types', () {
    for (final id in const ['garmin', 'fitbit', 'samsung-health']) {
      expect(PartnerIntegrationRegistry.byId(id).dataTypes, isEmpty);
    }
  });

  test('capability route and five authored locale catalogs are present', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final page = File(
      'lib/features/connected_health/partner_capabilities_page.dart',
    ).readAsStringSync();

    expect(router, contains("path: '/connected-health/capabilities'"));
    for (final locale in const ['en', 'ar', 'fr', 'es', 'tr']) {
      expect(page, contains("'$locale': {"));
    }
  });
}
