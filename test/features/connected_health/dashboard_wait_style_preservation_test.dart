import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/connected_health/providers/fitness_device_provider.dart';
import 'package:body_intelligence_log/features/connected_health/widgets/connected_health_card.dart';
import 'package:body_intelligence_log/features/connected_health/widgets/live_health_watch.dart';
import 'package:body_intelligence_log/features/global_platform/fitness_devices/ble_fitness_device_platform.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 15, 12);
final _snapshot = ConnectedHealthSnapshot(
  status: ConnectedHealthStatus.synchronized,
  platformSource: 'Health Connect',
  availableSources: const ['Health Connect'],
  signals: [
    ConnectedHealthSignalView(
      key: 'steps',
      value: 1234,
      unit: 'count',
      source: 'synthetic-phone-fixture',
      observedAt: _now,
      confidence: 1,
    ),
  ],
  importedCount: 1,
  lastSyncAt: _now,
  failureCode: null,
);

class _Gateway implements ConnectedHealthGateway {
  _Gateway({this.failFirstLoad = false});

  final bool failFirstLoad;
  final pendingLoad = Completer<ConnectedHealthSnapshot>();
  final pendingSync = Completer<ConnectedHealthSnapshot>();
  int loads = 0;
  int syncs = 0;
  int permissionActions = 0;

  @override
  Future<ConnectedHealthSnapshot> load() {
    loads++;
    if (failFirstLoad) {
      if (loads == 1) {
        return Future.error(StateError('fixture initial failure'));
      }
      return pendingLoad.future;
    }
    return Future.value(_snapshot);
  }

  @override
  Future<ConnectedHealthSnapshot> synchronize() {
    syncs++;
    return pendingSync.future;
  }

  void finishPending() {
    if (!pendingLoad.isCompleted) pendingLoad.complete(_snapshot);
    if (!pendingSync.isCompleted) pendingSync.complete(_snapshot);
  }

  @override
  Future<void> openSystemSettings() async {
    permissionActions++;
  }

  @override
  Future<ConnectedHealthSnapshot> requestPermissions() async {
    permissionActions++;
    return _snapshot;
  }

  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() async {
    permissionActions++;
    return _snapshot;
  }

  @override
  Future<ConnectedHealthSnapshot> revokePermissions() async {
    permissionActions++;
    return _snapshot;
  }
}

class _NoNativeBle implements BleFitnessBridge {
  int calls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    throw StateError('BLE must not be used by this waiting-style fixture');
  }
}

Widget _subject(
  ConnectedHealthController controller,
  _NoNativeBle ble, {
  required bool dashboardCompact,
}) => ProviderScope(
  overrides: [
    connectedHealthProvider.overrideWith((ref) => controller),
    fitnessDeviceProvider.overrideWith((ref) => FitnessDeviceController(ble)),
    liveHealthNowProvider.overrideWithValue(() => _now),
  ],
  child: MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConnectedHealthCard(
          languageCode: 'en',
          compact: dashboardCompact,
          dashboardCompact: dashboardCompact,
        ),
      ),
    ),
  ),
);

Finder _legacyRingInside(Finder parent) => find.descendant(
  of: parent,
  matching: find.byType(CircularProgressIndicator),
);

void _expectLegacyRing(WidgetTester tester, Finder ring, double size) {
  expect(ring, findsOneWidget);
  final widget = tester.widget<CircularProgressIndicator>(ring);
  expect(widget.value, isNull);
  expect(widget.strokeWidth, 2);
  expect(tester.getSize(ring), Size(size, size));
  expect(find.byType(CupertinoActivityIndicator), findsNothing);
}

void main() {
  for (final width in [360.0, 1024.0]) {
    testWidgets('Dashboard health loading keeps its old ring at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final gateway = _Gateway(failFirstLoad: true);
      final controller = ConnectedHealthController(gateway);
      final ble = _NoNativeBle();
      // Retry a real AsyncError without cached data to exercise AsyncLoading.
      await controller.refresh();
      final pending = controller.refresh();
      try {
        await tester.pumpWidget(
          _subject(controller, ble, dashboardCompact: width < 600),
        );
        await tester.pump(const Duration(milliseconds: 80));
        _expectLegacyRing(
          tester,
          _legacyRingInside(find.byKey(const Key('connected-health-card'))),
          24,
        );
        expect(gateway.loads, 2);
        expect(gateway.syncs, 0);
        expect(gateway.permissionActions, 0);
        expect(ble.calls, 0);
        expect(tester.takeException(), isNull);
      } finally {
        gateway.finishPending();
        await pending;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });

    testWidgets('compact Dashboard sync keeps its old ring at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final gateway = _Gateway();
      final controller = ConnectedHealthController(gateway);
      final ble = _NoNativeBle();
      await controller.refresh();
      final pending = controller.synchronize();
      try {
        await tester.pumpWidget(
          _subject(controller, ble, dashboardCompact: true),
        );
        await tester.pump(const Duration(milliseconds: 80));
        final sync = find.byKey(const Key('dashboard-fitness-last-sync'));
        _expectLegacyRing(tester, _legacyRingInside(sync), 17);
        expect(find.text('Synchronizing…'), findsOneWidget);
        expect(controller.state.value?.isBusy, isTrue);
        expect(gateway.syncs, 1);
        expect(gateway.permissionActions, 0);
        expect(ble.calls, 0);
        expect(tester.takeException(), isNull);
      } finally {
        gateway.finishPending();
        await pending;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });
  }

  testWidgets('wide Dashboard busy content adds no new waiting indicator', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final gateway = _Gateway();
    final controller = ConnectedHealthController(gateway);
    final ble = _NoNativeBle();
    await controller.refresh();
    final pending = controller.synchronize();
    try {
      await tester.pumpWidget(
        _subject(controller, ble, dashboardCompact: false),
      );
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.byType(ConnectedHealthCard), findsOneWidget);
      expect(controller.state.value?.isBusy, isTrue);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(gateway.syncs, 1);
      expect(gateway.permissionActions, 0);
      expect(ble.calls, 0);
      expect(tester.takeException(), isNull);
    } finally {
      gateway.finishPending();
      await pending;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
