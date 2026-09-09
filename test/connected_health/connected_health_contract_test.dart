import 'dart:io';
import 'dart:async';

import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_extended.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_page.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/global_platform/health_data/unified_health_data_integration.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'permission requests are single-flight and unlock after failure',
    () async {
      final gateway = _PermissionGateway();
      final controller = ConnectedHealthController(gateway);

      final first = controller.requestPermissions();
      final duplicate = controller.requestPermissions();
      expect(controller.state, isA<AsyncData<ConnectedHealthSnapshot>>());
      expect(controller.state.value?.isBusy, isTrue);
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

  test(
    'permission completion waits for an explicit watch update before import',
    () async {
      final gateway = _PermissionGateway();
      final controller = ConnectedHealthController(gateway);

      final request = controller.requestPermissions();
      gateway.permissionRequest.complete(_authorizationRequestedSnapshot);
      await request;

      expect(gateway.permissionCalls, 1);
      expect(gateway.syncCalls, 0);
      expect(
        controller.state.value?.status,
        ConnectedHealthStatus.authorizationRequested,
      );
      controller.dispose();
    },
  );

  test(
    'permission tap does not wait for a passive native status read',
    () async {
      final gateway = _DelayedLoadGateway();
      final controller = ConnectedHealthController(gateway);

      final request = controller.requestPermissions();
      expect(gateway.permissionCalls, 1);
      expect(gateway.loadRequest.isCompleted, isFalse);

      gateway.permissionRequest.complete(_permissionRequiredSnapshot);
      await request;
      expect(
        controller.state.value?.status,
        ConnectedHealthStatus.permissionRequired,
      );
      controller.dispose();
    },
  );

  test(
    'status refresh does not import native records without an explicit sync',
    () async {
      final gateway = _SynchronizedGateway();
      final controller = ConnectedHealthController(gateway);

      expect(gateway.loadCalls, 0);
      expect(gateway.syncCalls, 0);

      await controller.refresh();
      expect(gateway.loadCalls, 1);
      expect(gateway.syncCalls, 0);

      await controller.synchronize();
      expect(gateway.syncCalls, 1);
      controller.dispose();
    },
  );

  test('foreground refresh keeps the current snapshot visible', () async {
    final gateway = _DelayedRefreshGateway();
    final controller = ConnectedHealthController(gateway);
    await controller.refresh();
    expect(controller.state, isA<AsyncData<ConnectedHealthSnapshot>>());

    final refresh = controller.refresh();
    expect(controller.state, isA<AsyncData<ConnectedHealthSnapshot>>());
    expect(
      controller.state.value?.status,
      ConnectedHealthStatus.permissionDenied,
    );
    expect(controller.state.value?.isBusy, isTrue);

    gateway.refreshLoad.complete(_permissionDeniedSnapshot);
    await refresh;
    expect(controller.state, isA<AsyncData<ConnectedHealthSnapshot>>());
    expect(controller.state.value?.isBusy, isFalse);
    controller.dispose();
  });

  test(
    'a stalled watch update exits busy state with a truthful timeout',
    () async {
      final gateway = _HangingSynchronizationGateway();
      final controller = ConnectedHealthController(
        gateway,
        synchronizationTimeout: Duration.zero,
      );

      await controller.synchronize();

      expect(gateway.syncCalls, 1);
      expect(controller.state, isA<AsyncData<ConnectedHealthSnapshot>>());
      expect(controller.state.value?.status, ConnectedHealthStatus.degraded);
      expect(controller.state.value?.isBusy, isFalse);
      expect(controller.state.value?.failureCode, 'health_sync_timed_out');
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

  test('native read and write scopes stay platform-specific', () {
    expect(
      BilHealthScope.healthConnectReadTypeNames,
      BilHealthScope.appleHealthReadTypeNames,
      reason:
          'The two native bridges now implement the same canonical read scope.',
    );
    expect(
      connectedHealthReadTypesForPlatform(
        TargetPlatform.iOS,
      ).map((type) => type.name).toSet(),
      BilHealthScope.appleHealthReadTypeNames,
    );
    expect(
      connectedHealthReadTypesForPlatform(
        TargetPlatform.android,
      ).map((type) => type.name).toSet(),
      BilHealthScope.healthConnectReadTypeNames,
    );
    expect(
      connectedHealthWriteTypeNamesForPlatform(TargetPlatform.iOS),
      const <String>{'weight'},
    );
    expect(
      connectedHealthWriteTypeNamesForPlatform(TargetPlatform.android),
      const <String>{'weight', 'nutrition'},
    );
    expect(
      connectedHealthReadTypesForPlatform(TargetPlatform.windows),
      isEmpty,
    );
    expect(
      connectedHealthWriteTypeNamesForPlatform(TargetPlatform.windows),
      isEmpty,
    );
  });

  test('iOS never calls an empty HealthKit read synchronized', () {
    expect(
      connectedHealthStatusAfterSynchronization(
        platform: TargetPlatform.iOS,
        hasVerifiedNativeEvidence: false,
      ),
      ConnectedHealthStatus.authorizationRequested,
    );
    expect(
      connectedHealthStatusAfterSynchronization(
        platform: TargetPlatform.iOS,
        hasVerifiedNativeEvidence: true,
      ),
      ConnectedHealthStatus.synchronized,
    );
    expect(
      connectedHealthStatusAfterSynchronization(
        platform: TargetPlatform.android,
        hasVerifiedNativeEvidence: false,
      ),
      ConnectedHealthStatus.synchronized,
    );
  });

  test('watch presentation requires wearable provenance', () {
    final observedAt = DateTime.utc(2026, 9, 4);
    final manual = ConnectedHealthSignalView(
      key: 'weight',
      value: 80,
      unit: 'kg',
      source: 'iPhone',
      observedAt: observedAt,
      confidence: 1,
    );
    final watch = ConnectedHealthSignalView(
      key: 'heartRate',
      value: 70,
      unit: 'count/min',
      source: 'Apple Health',
      observedAt: observedAt,
      confidence: 1,
      attributes: <String, Object?>{'wearableKind': 'apple_watch'},
    );

    expect(connectedHealthSignalHasWearableProvenance(manual), isFalse);
    expect(connectedHealthSignalHasWearableProvenance(watch), isTrue);
  });

  testWidgets(
    'nested gateway override reaches the controller and the page settles',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final gateway = _PermissionGateway();

        await tester.pumpWidget(
          ProviderScope(
            child: ProviderScope(
              overrides: [
                connectedHealthGatewayProvider.overrideWithValue(gateway),
              ],
              child: const MaterialApp(home: ConnectedHealthPage()),
            ),
          ),
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 20),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 1),
        );

        expect(gateway.loadCalls, 1);
        expect(find.byKey(const Key('connected-health-source-card')), findsOne);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('returning from system settings refreshes native health status', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final gateway = _SettingsGateway();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectedHealthGatewayProvider.overrideWithValue(gateway),
            verifiedSubscriptionStateProvider.overrideWithValue(
              const AsyncLoading(),
            ),
          ],
          child: const MaterialApp(home: ConnectedHealthPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(gateway.loadCalls, 1);
      await tester.tap(find.text('Open system settings'));
      await tester.pump();
      expect(gateway.openSettingsCalls, 1);

      final observer =
          tester.state(find.byType(ConnectedHealthPage))
              as WidgetsBindingObserver;
      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pump();
      expect(gateway.loadCalls, 1);

      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(gateway.loadCalls, 2);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
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
    expect(grid, isNot(contains('PersonalHealthAiPanel(')));
    expect(grid, isNot(contains('personalHealthAi:')));
    expect(personal, isNot(contains('ConnectedHealth')));
    expect(connected, contains('PremiumSurface('));
    expect(connected, contains('DashboardCarousel('));
    expect(connected, contains("Key('connected-health-card')"));
  });

  test('connected health uses existing global platform runtimes', () {
    final provider = <String>[
      'lib/features/connected_health/providers/connected_health_provider.dart',
      'lib/features/connected_health/providers/connected_health_gateway_helpers.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    expect(provider, contains('globalProductFlowsProvider'));
    expect(provider, contains('_flows.appleHealth.integration.synchronize'));
    expect(provider, contains('_flows.healthConnect.integration.synchronize'));
    expect(provider, contains("'connected_health_ui'"));
    expect(provider, isNot(contains('http://')));
    expect(provider, isNot(contains('https://')));
  });

  test('device verification requires persisted native evidence', () {
    final provider = <String>[
      'lib/features/connected_health/providers/connected_health_provider.dart',
      'lib/features/connected_health/providers/connected_health_gateway_helpers.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    expect(provider, isNot(contains('deviceVerified: true')));
    expect(provider, contains('signal.provenance.providerId == _bridge.id'));
    expect(provider, contains('selected.any('));
    expect(provider, contains('_isEvidenceFromNativeBridge'));
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
    expect(
      components,
      isNot(contains('bil_medical_hub.png')),
      reason: 'The fitness surface must not show a blood-pressure device.',
    );
    expect(components, isNot(contains("Key('bil-fitness-device-image')")));
  });

  test(
    'dashboard exposes one truthful fitness widget without a side device card',
    () {
      final dashboard = File(
        'lib/features/dashboard/widgets/dashboard_reference_phone.dart',
      ).readAsStringSync();
      final dashboardSections = File(
        'lib/features/dashboard/widgets/dashboard_reference_phone_sections.dart',
      ).readAsStringSync();
      final page = File(
        'lib/features/connected_health/connected_health_page.dart',
      ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
      final card = File(
        'lib/features/connected_health/widgets/connected_health_card.dart',
      ).readAsStringSync();

      expect(dashboard, isNot(contains('Smart-watch and health sync')));
      expect(
        dashboardSections,
        isNot(contains('assets/images/connected_health/bil_medical_hub.png')),
        reason: 'The Dashboard must not retain a blood-pressure side card.',
      );
      expect(page, contains("Key('fitness-devices-premium-gate')"));
      expect(page, contains("'connected-health-live-watch-card'"));
      expect(page, contains("'connected-health-source-card'"));
      expect(page, contains("'connected-health-signals-card'"));
      expect(page, contains('connectedHealthSnapshotHasWearableEvidence('));
      expect(page, contains('defaultTargetPlatform == TargetPlatform.android'));
      expect(page, contains('child: const _FitnessDeviceSection()'));
      expect(card, contains('LiveHealthWatch('));
      expect(card, contains("Key('dashboard-live-fitness-watch-slot')"));
      expect(card, contains("Key('dashboard-compact-health-hub')"));
      expect(
        card,
        isNot(contains("'Manage fitness sources'")),
        reason: 'the compact dashboard card itself is the navigation target',
      );
      expect(card, contains("Key('dashboard-fitness-last-sync')"));
      expect(card, isNot(contains('HealthDevicePager(')));
      expect(card, contains("context.push('/connected-health')"));
    },
  );

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
  int loadCalls = 0;
  int syncCalls = 0;

  @override
  Future<ConnectedHealthSnapshot> load() async {
    loadCalls += 1;
    return _permissionRequiredSnapshot;
  }

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
  Future<ConnectedHealthSnapshot> synchronize() async {
    syncCalls += 1;
    return _synchronizedSnapshot;
  }
}

final class _DelayedLoadGateway implements ConnectedHealthGateway {
  final Completer<ConnectedHealthSnapshot> loadRequest =
      Completer<ConnectedHealthSnapshot>();
  final Completer<ConnectedHealthSnapshot> permissionRequest =
      Completer<ConnectedHealthSnapshot>();
  int permissionCalls = 0;

  @override
  Future<ConnectedHealthSnapshot> load() => loadRequest.future;

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

final class _DelayedRefreshGateway implements ConnectedHealthGateway {
  final Completer<ConnectedHealthSnapshot> refreshLoad =
      Completer<ConnectedHealthSnapshot>();
  int loadCalls = 0;

  @override
  Future<ConnectedHealthSnapshot> load() {
    loadCalls += 1;
    return loadCalls == 1
        ? Future<ConnectedHealthSnapshot>.value(_permissionDeniedSnapshot)
        : refreshLoad.future;
  }

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<ConnectedHealthSnapshot> requestPermissions() async =>
      _permissionDeniedSnapshot;

  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() async =>
      _permissionDeniedSnapshot;

  @override
  Future<ConnectedHealthSnapshot> revokePermissions() async =>
      _permissionDeniedSnapshot;

  @override
  Future<ConnectedHealthSnapshot> synchronize() async =>
      _permissionDeniedSnapshot;
}

final class _SettingsGateway implements ConnectedHealthGateway {
  int loadCalls = 0;
  int openSettingsCalls = 0;

  @override
  Future<ConnectedHealthSnapshot> load() async {
    loadCalls += 1;
    return _permissionDeniedSnapshot;
  }

  @override
  Future<void> openSystemSettings() async {
    openSettingsCalls += 1;
  }

  @override
  Future<ConnectedHealthSnapshot> requestPermissions() async =>
      _permissionDeniedSnapshot;

  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() async =>
      _permissionDeniedSnapshot;

  @override
  Future<ConnectedHealthSnapshot> revokePermissions() async =>
      _permissionDeniedSnapshot;

  @override
  Future<ConnectedHealthSnapshot> synchronize() async =>
      _permissionDeniedSnapshot;
}

final class _SynchronizedGateway implements ConnectedHealthGateway {
  int loadCalls = 0;
  int syncCalls = 0;

  @override
  Future<ConnectedHealthSnapshot> load() async {
    loadCalls += 1;
    return _synchronizedSnapshot;
  }

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<ConnectedHealthSnapshot> requestPermissions() async =>
      _synchronizedSnapshot;

  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() async =>
      _synchronizedSnapshot;

  @override
  Future<ConnectedHealthSnapshot> revokePermissions() async =>
      _permissionRequiredSnapshot;

  @override
  Future<ConnectedHealthSnapshot> synchronize() async {
    syncCalls += 1;
    return _synchronizedSnapshot;
  }
}

final class _HangingSynchronizationGateway implements ConnectedHealthGateway {
  int syncCalls = 0;
  final Completer<ConnectedHealthSnapshot> syncRequest =
      Completer<ConnectedHealthSnapshot>();

  @override
  Future<ConnectedHealthSnapshot> load() async => _synchronizedSnapshot;

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<ConnectedHealthSnapshot> requestPermissions() async =>
      _synchronizedSnapshot;

  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() async =>
      _synchronizedSnapshot;

  @override
  Future<ConnectedHealthSnapshot> revokePermissions() async =>
      _permissionRequiredSnapshot;

  @override
  Future<ConnectedHealthSnapshot> synchronize() {
    syncCalls += 1;
    return syncRequest.future;
  }
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

const _authorizationRequestedSnapshot = ConnectedHealthSnapshot(
  status: ConnectedHealthStatus.authorizationRequested,
  platformSource: 'Apple Health',
  availableSources: <String>['Apple Health'],
  signals: <ConnectedHealthSignalView>[],
  importedCount: 0,
  lastSyncAt: null,
  failureCode: null,
);

const _permissionDeniedSnapshot = ConnectedHealthSnapshot(
  status: ConnectedHealthStatus.permissionDenied,
  platformSource: 'Health Connect',
  availableSources: <String>[],
  signals: <ConnectedHealthSignalView>[],
  importedCount: 0,
  lastSyncAt: null,
  failureCode: null,
);

final _synchronizedSnapshot = ConnectedHealthSnapshot(
  status: ConnectedHealthStatus.synchronized,
  platformSource: 'Apple Health',
  availableSources: const <String>['Apple Health'],
  signals: const <ConnectedHealthSignalView>[],
  importedCount: 0,
  lastSyncAt: DateTime.utc(2026, 9, 4),
  failureCode: null,
);
