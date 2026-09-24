import 'dart:async';

import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _BlockedPassiveGateway
    implements ConnectedHealthGateway, ConnectedHealthDailyActivityGateway {
  final passive = Completer<ConnectedHealthSnapshot>();
  final native = Completer<ConnectedHealthSnapshot>();
  var syncCalls = 0;
  var dailyCalls = 0;

  static final cached = ConnectedHealthSnapshot(
    status: ConnectedHealthStatus.synchronized,
    platformSource: 'Apple Health',
    availableSources: const ['Apple Health'],
    signals: const [],
    stepHistory: [
      ConnectedHealthSignalView(
        key: 'steps',
        value: 321,
        unit: 'count',
        source: 'iPhone',
        observedAt: DateTime(2026, 9, 24, 8),
        confidence: 1,
      ),
    ],
    importedCount: 1,
    lastSyncAt: DateTime(2026, 9, 24, 8),
    failureCode: null,
    deviceVerified: true,
  );

  @override
  Future<ConnectedHealthSnapshot> loadDailyActivity() {
    dailyCalls++;
    return passive.future;
  }

  @override
  Future<ConnectedHealthSnapshot> synchronize() {
    syncCalls++;
    return native.future;
  }

  @override
  Future<ConnectedHealthSnapshot> load() async => cached;
  @override
  Future<void> openSystemSettings() async {}
  @override
  Future<ConnectedHealthSnapshot> requestPermissions() async => cached;
  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() async =>
      cached;
  @override
  Future<ConnectedHealthSnapshot> revokePermissions() async =>
      const ConnectedHealthSnapshot.unavailable();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'explicit deadline starts at action and bypasses a blocked passive read',
    () async {
      final gateway = _BlockedPassiveGateway();
      final controller = ConnectedHealthController(
        gateway,
        synchronizationTimeout: const Duration(milliseconds: 20),
      );
      addTearDown(controller.dispose);
      await controller.refresh();

      final passive = controller.refreshDailyActivity(force: true);
      expect(gateway.dailyCalls, 1);
      final first = controller.synchronize();
      final second = controller.synchronize();

      await Future<void>.delayed(const Duration(milliseconds: 2));
      expect(gateway.syncCalls, 1);
      expect(controller.state.value!.isBusy, isTrue);
      await Future.wait([first, second]);
      expect(controller.state.value!.isBusy, isFalse);
      expect(controller.state.value!.failureCode, 'health_sync_timed_out');
      expect(controller.state.value!.stepHistory.single.value, 321);

      gateway.passive.complete(_BlockedPassiveGateway.cached);
      gateway.native.complete(_BlockedPassiveGateway.cached);
      await passive;
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.value!.failureCode, 'health_sync_timed_out');
    },
  );

  test(
    'pause clears visible busy state and fences late native completion',
    () async {
      final gateway = _BlockedPassiveGateway();
      final controller = ConnectedHealthController(
        gateway,
        synchronizationTimeout: const Duration(seconds: 1),
      );
      addTearDown(controller.dispose);
      await controller.refresh();

      final sync = controller.synchronize();
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.value!.isBusy, isTrue);
      controller.didChangeAppLifecycleState(AppLifecycleState.hidden);
      expect(controller.state.value!.isBusy, isFalse);

      gateway.native.complete(
        _BlockedPassiveGateway.cached.copyWith(
          lastSyncAt: DateTime(2026, 9, 24, 9),
        ),
      );
      await sync;
      expect(controller.state.value!.lastSyncAt, DateTime(2026, 9, 24, 8));
    },
  );
}
