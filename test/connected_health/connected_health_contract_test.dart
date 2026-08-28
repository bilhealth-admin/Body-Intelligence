import 'dart:io';
import 'dart:async';

import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_extended.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_page.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'permission requests are single-flight and unlock after failure',
    () async {
      final gateway = _PermissionGateway();
      final controller = ConnectedHealthController(gateway);
      await Future<void>.delayed(Duration.zero);

      final first = controller.requestPermissions();
      final duplicate = controller.requestPermissions();
      expect(controller.state, isA<AsyncLoading<ConnectedHealthSnapshot>>());
      expect(gateway.permissionCalls, 1);

      gateway.permissionRequest.completeError(StateError('denied'));
      await first;
      await duplicate;
      expect(controller.state, isA<AsyncError<ConnectedHealthSnapshot>>());

      gateway.permissionRequest = Completer<ConnectedHealthSnapshot>();
      final retry = controller.requestPermissions();
      expect(gateway.permissionCalls, 2);
      gateway.permissionRequest.complete(_permissionRequiredSnapshot);
      await retry;
      expect(controller.state, isA<AsyncData<ConnectedHealthSnapshot>>());
      controller.dispose();
    },
  );

  test('permission action is hidden for an unsupported platform', () {
    expect(
      connectedHealthCanRequestPermissions(ConnectedHealthStatus.unavailable),
      isFalse,
    );
    expect(
      connectedHealthCanRequestPermissions(
        ConnectedHealthStatus.permissionRequired,
      ),
      isTrue,
    );
    expect(
      connectedHealthCanRequestPermissions(
        ConnectedHealthStatus.permissionDenied,
      ),
      isTrue,
    );
  });

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
    expect(provider, contains('_flows.appleHealth.integration.synchronize'));
    expect(provider, contains('_flows.healthConnect.integration.synchronize'));
    expect(provider, contains("'connected_health_ui'"));
    expect(provider, isNot(contains('http://')));
    expect(provider, isNot(contains('https://')));
  });

  test('management route is registered', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    expect(router, contains("path: '/connected-health'"));
    expect(router, contains('ConnectedHealthPage'));
    final healthRouteStart = router.indexOf("path: '/connected-health'");
    final stepsRouteStart = router.indexOf("path: '/connected-health/steps'");
    final healthRoute = router.substring(healthRouteStart, stepsRouteStart);
    expect(healthRoute, isNot(contains('PremiumRouteGlassGate')));
  });

  test('Apps and Devices exposes consumer copy and an empty-state action', () {
    final components = File(
      'lib/features/connected_health/connected_health_components.dart',
    ).readAsStringSync();

    expect(components, contains("Key('connected-sources-add-cta')"));
    expect(components, contains("'Health Connect'"));
    expect(components, contains("'Apple Health'"));
    expect(
      components,
      isNot(
        contains('Implementation ready; physical-device verification required'),
      ),
    );
    expect(components, isNot(contains('entry.protocol')));
  });

  test('watch sync stays free while fitness-device Bluetooth is Premium', () {
    final dashboard = File(
      'lib/features/dashboard/widgets/dashboard_reference_phone.dart',
    ).readAsStringSync();
    final page = File(
      'lib/features/connected_health/connected_health_page.dart',
    ).readAsStringSync();
    final card = File(
      'lib/features/connected_health/widgets/connected_health_card.dart',
    ).readAsStringSync();

    expect(dashboard, isNot(contains('Smart-watch and health sync')));
    expect(page, contains("Key('medical-devices-premium-gate')"));
    expect(page, contains("Key('connected-health-live-watch-card')"));
    expect(page, contains('child: const _MedicalDeviceSection()'));
    expect(card, contains('LiveHealthWatch('));
    expect(card, contains('BilMedicalMonitor('));
    expect(card, contains('PremiumDashboardCardLock('));
    expect(card, contains('locked: !widget.medicalDevicesUnlocked'));
    expect(card, contains("Key('dashboard-live-health-watch-slot')"));
    expect(card, contains("Key('dashboard-medical-device-preview')"));
    expect(card, contains("context.push('/connected-health')"));
  });

  test('all connected health presentation uses the direct25 contract', () {
    final presentation = Directory('lib/features/connected_health')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');
    final copy = File(
      'lib/features/connected_health/connected_health_copy.dart',
    ).readAsStringSync();

    expect(presentation, isNot(contains('required this.arabic')));
    expect(presentation, isNot(contains('widget.arabic')));
    expect(presentation, isNot(contains('arabic ?')));
    for (final locale in const ['fr', 'es', 'tr']) {
      expect(copy, contains("'$locale': {"));
    }
    expect(presentation, contains('languageCode'));

    final frStart = copy.indexOf("  'fr': {");
    final frEnd = copy.indexOf('\n  },', frStart);
    expect(frStart, greaterThanOrEqualTo(0));
    expect(frEnd, greaterThan(frStart));
    final keys = RegExp(r"^\s*'((?:\\.|[^'])*)':", multiLine: true)
        .allMatches(copy.substring(frStart, frEnd))
        .map((match) {
          return match.group(1)!.replaceAll(r"\'", "'");
        })
        .toSet();
    expect(keys.length, greaterThan(60));
    for (final key in keys) {
      for (final locale in RuntimeCopy.supported.skip(5)) {
        final direct = ExtendedRuntimeCopy.values[key]?[locale];
        expect(direct, isNotNull, reason: '$key / $locale');
        expect(direct!.trim(), isNotEmpty, reason: '$key / $locale');
      }
    }
  });
}

final class _PermissionGateway implements ConnectedHealthGateway {
  Completer<ConnectedHealthSnapshot> permissionRequest =
      Completer<ConnectedHealthSnapshot>();
  int permissionCalls = 0;

  @override
  Future<ConnectedHealthSnapshot> load() async => _permissionRequiredSnapshot;

  @override
  Future<ConnectedHealthSnapshot> requestPermissions() {
    permissionCalls += 1;
    return permissionRequest.future;
  }

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() async =>
      _permissionRequiredSnapshot;

  @override
  Future<ConnectedHealthSnapshot> revokePermissions() async =>
      _permissionRequiredSnapshot;

  @override
  Future<ConnectedHealthSnapshot> synchronize() async =>
      _permissionRequiredSnapshot;
}

const _permissionRequiredSnapshot = ConnectedHealthSnapshot(
  status: ConnectedHealthStatus.permissionRequired,
  platformSource: 'Health Connect',
  availableSources: <String>[],
  signals: <ConnectedHealthSignalView>[],
  importedCount: 0,
  lastSyncAt: null,
  failureCode: null,
);
