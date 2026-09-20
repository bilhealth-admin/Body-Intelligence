import 'dart:io';

import 'package:body_intelligence_log/features/connected_health/partner_setup_copy.dart';
import 'package:body_intelligence_log/features/connected_health/partner_integration_registry.dart';
import 'package:body_intelligence_log/features/global_platform/health_data/unified_health_data_integration.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only shipping native and BLE bridges are connectable', () {
    final connectable = PartnerIntegrationRegistry.capabilities
        .where((entry) => entry.canConnect)
        .map((entry) => entry.id)
        .toSet();

    expect(connectable, {'health-connect', 'healthkit', 'fitness-ble'});
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

  test('capabilities expose only this platform native source and BLE', () {
    expect(
      PartnerIntegrationRegistry.forTargetPlatform(
        TargetPlatform.iOS,
      ).map((entry) => entry.id),
      ['healthkit', 'fitness-ble'],
    );
    expect(
      PartnerIntegrationRegistry.forTargetPlatform(
        TargetPlatform.android,
      ).map((entry) => entry.id),
      ['health-connect', 'fitness-ble'],
    );
    expect(
      PartnerIntegrationRegistry.forTargetPlatform(
        TargetPlatform.iOS,
        isWeb: true,
      ),
      isEmpty,
    );
  });

  test('native capability contract matches the complete requested scope', () {
    expect(
      PartnerIntegrationRegistry.byId('healthkit').dataTypes,
      BilHealthScope.appleHealthReadTypeNames,
    );
    expect(
      PartnerIntegrationRegistry.byId('health-connect').dataTypes,
      BilHealthScope.healthConnectReadTypeNames,
    );
  });

  test('capability route and complete setup locale catalog are present', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final page = File(
      'lib/features/connected_health/partner_capabilities_page.dart',
    ).readAsStringSync();

    expect(router, contains("path: '/connected-health/capabilities'"));
    expect(PartnerSetupCopy.supported, hasLength(25));
    expect(PartnerSetupCopy.balanced, isTrue);
    expect(page, contains('PartnerSetupCopy.of(context)'));
    expect(page, isNot(contains('OAuth')));
    expect(page, isNot(contains('runtime registration')));
    expect(page, isNot(contains('Native bridge')));
    expect(page, contains('entry.dataTypes'));
    expect(page, contains('Not available yet'));
  });

  test('official setup links are exact HTTPS allowlist entries', () {
    for (final id in const ['garmin', 'fitbit', 'samsung-health']) {
      final entry = PartnerIntegrationRegistry.byId(id);
      final uri = Uri.parse(entry.officialSetupUrl!);
      expect(
        PartnerIntegrationRegistry.isVerifiedOfficialSetupUri(id, uri),
        isTrue,
        reason: id,
      );
      expect(entry.canConnect, isFalse, reason: '$id remains setup-only');
      expect(
        PartnerIntegrationRegistry.isVerifiedOfficialSetupUri(
          id,
          uri.replace(queryParameters: <String, String>{'redirect': 'evil'}),
        ),
        isFalse,
        reason: '$id must not accept URL variants',
      );
      expect(
        PartnerIntegrationRegistry.isVerifiedOfficialSetupUri(
          id,
          uri.replace(port: 444),
        ),
        isFalse,
        reason: '$id must reject alternate ports',
      );
      expect(
        PartnerIntegrationRegistry.isVerifiedOfficialSetupUri(
          id,
          uri.replace(path: uri.path.toUpperCase()),
        ),
        isFalse,
        reason: '$id must reject path-case variants',
      );
      expect(
        PartnerIntegrationRegistry.isVerifiedOfficialSetupUri(
          id,
          uri.replace(fragment: 'redirect'),
        ),
        isFalse,
        reason: '$id must reject fragments',
      );
    }
  });

  test('setup-only tiles remain accessible and QR repaint is data-bound', () {
    final page = File(
      'lib/features/connected_health/partner_capabilities_page.dart',
    ).readAsStringSync();

    expect(page, contains('enabled: ready || verifiedSetupUri != null'));
    expect(page, contains('PartnerSetupCopy.guidanceOnly'));
    expect(page, contains('oldDelegate.data != data'));
    expect(page, contains("Key('verified-partner-qr-\${entry.id}')"));
    expect(page, contains('onTap: () => launcher(uri)'));
  });
}
