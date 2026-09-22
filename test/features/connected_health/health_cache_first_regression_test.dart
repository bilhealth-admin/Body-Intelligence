import 'dart:async';

import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cached watch is visible before a native status response', () async {
    final gateway = _Gateway();
    final controller = ConnectedHealthController(gateway);
    addTearDown(controller.dispose);
    final pending = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(gateway.loads, 1);
    expect(gateway.syncs, 0);
    expect(controller.state.value!.signals.single.value, 1234);
    expect(controller.state.value!.isBusy, isTrue);
    gateway.loadResult.complete(_cached);
    await pending;
    expect(controller.state.value!.isBusy, isFalse);
  });

  for (final activity in [false, true]) {
    test('stalled ${activity ? 'daily totals' : 'status'} keeps cache, ends '
        'busy and remains single-flight', () async {
      final gateway = _Gateway();
      final controller = ConnectedHealthController(
        gateway,
        synchronizationTimeout: const Duration(milliseconds: 10),
      );
      addTearDown(controller.dispose);
      await controller.restoreCachedSnapshot();
      Future<void> read() => activity
          ? controller.refreshDailyActivity(force: true)
          : controller.refresh();
      await read();
      expect(controller.state.value!.signals.single.value, 1234);
      expect(controller.state.value!.isBusy, isFalse);
      expect(controller.state.value!.status, ConnectedHealthStatus.degraded);
      await read();
      expect(activity ? gateway.activities : gateway.loads, 1);
      (activity ? gateway.activityResult : gateway.loadResult).complete(
        _cached.copyWith(signals: []),
      );
      await Future<void>.delayed(Duration.zero);
      // The abandoned response cannot replace the timed-out snapshot.
      expect(controller.state.value!.signals.single.value, 1234);
    });
  }

  test('backgrounding fences a late read; resume can read again', () async {
    final gateway = _Gateway();
    final controller = ConnectedHealthController(gateway);
    addTearDown(controller.dispose);
    await controller.restoreCachedSnapshot();
    final pending = controller.refreshDailyActivity(force: true);
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    gateway.activityResult.complete(_cached.copyWith(signals: []));
    await pending;
    expect(controller.state.value!.signals.single.value, 1234);
    expect(controller.state.value!.isBusy, isFalse);
    await controller.refreshDailyActivity(force: true);
    expect(gateway.activities, 1);
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    gateway.activityResult = Completer<ConnectedHealthSnapshot>()
      ..complete(_cached);
    await controller.refreshDailyActivity(force: true);
    expect(gateway.activities, 2);
  });

  test('explicit revocation is not replaced by retained cache', () async {
    final gateway = _Gateway();
    final controller = ConnectedHealthController(gateway);
    addTearDown(controller.dispose);
    await controller.restoreCachedSnapshot();
    await controller.revokePermissions();
    await controller.restoreCachedSnapshot();
    expect(controller.state.value!.signals, isEmpty);
    expect(controller.state.value!.deviceVerified, isFalse);
  });
}

final _cached = ConnectedHealthSnapshot(
  status: ConnectedHealthStatus.degraded,
  platformSource: 'Apple Health',
  availableSources: const ['Apple Health'],
  signals: [
    ConnectedHealthSignalView(
      key: 'steps',
      value: 1234,
      unit: 'count',
      source: 'Apple Watch',
      observedAt: DateTime(2026, 9, 20),
      confidence: 1,
    ),
  ],
  importedCount: 1,
  lastSyncAt: DateTime(2026, 9, 20),
  failureCode: null,
  deviceVerified: true,
);

class _Gateway
    implements
        ConnectedHealthGateway,
        ConnectedHealthCachedSnapshotGateway,
        ConnectedHealthDailyActivityGateway {
  final loadResult = Completer<ConnectedHealthSnapshot>();
  var activityResult = Completer<ConnectedHealthSnapshot>();
  int loads = 0;
  int activities = 0;
  int syncs = 0;

  @override
  Future<ConnectedHealthSnapshot> loadCachedSnapshot() async => _cached;
  @override
  Future<ConnectedHealthSnapshot> load() {
    loads++;
    return loadResult.future;
  }

  @override
  Future<ConnectedHealthSnapshot> loadDailyActivity() {
    activities++;
    return activityResult.future;
  }

  @override
  Future<ConnectedHealthSnapshot> synchronize() async {
    syncs++;
    return _cached;
  }

  @override
  Future<ConnectedHealthSnapshot> revokePermissions() async =>
      const ConnectedHealthSnapshot.unavailable();
  @override
  Future<ConnectedHealthSnapshot> requestPermissions() async => _cached;
  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() async =>
      _cached;
  @override
  Future<void> openSystemSettings() async {}
}
