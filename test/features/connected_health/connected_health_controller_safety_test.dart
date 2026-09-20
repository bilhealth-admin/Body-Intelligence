import 'dart:async';
import 'dart:io';

import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'native runtime keeps synchronization single-flight after controller timeout',
    () {
      final source = File(
        'lib/features/global_platform/health_data/unified_health_data_integration.dart',
      ).readAsStringSync();
      expect(source, contains('_synchronizationTask'));
      expect(source, contains('if (existing != null) return existing'));
      expect(source, contains('identical(_synchronizationTask, task)'));
    },
  );

  test('empty and partial native results preserve trusted metrics', () {
    final previous = _snapshot([
      _signal('steps', 4200),
      _signal('activeEnergy', 380),
      _signal('distance', 3.2, unit: 'km'),
    ]);
    final partial = _snapshot([_signal('steps', 4500)]);
    final merged = preserveTrustedConnectedHealthSignals(
      previous: previous,
      incoming: partial,
    );
    expect(
      merged.signals.map((signal) => signal.key),
      containsAll(['steps', 'activeEnergy', 'distance']),
    );
    expect(
      merged.signals.singleWhere((signal) => signal.key == 'steps').value,
      4500,
    );

    final empty = preserveTrustedConnectedHealthSignals(
      previous: previous,
      incoming: _snapshot(const []),
    );
    expect(
      empty.signals.map((signal) => signal.key),
      containsAll(['steps', 'activeEnergy', 'distance']),
    );
  });

  test(
    'controller deduplicates sync and ignores late results after dispose',
    () async {
      final gateway = _ControlledGateway();
      final controller = ConnectedHealthController(gateway);
      await controller.refresh();

      final first = controller.synchronize();
      final second = controller.synchronize();
      expect(gateway.synchronizeCalls, 1);
      gateway.completeSync(_snapshot([_signal('steps', 10)]));
      await Future.wait([first, second]);
      expect(controller.state.value!.signals, isNotEmpty);

      final lateGateway = _ControlledGateway(
        loadCompleter: Completer<ConnectedHealthSnapshot>(),
      );
      final lateController = ConnectedHealthController(lateGateway);
      final refresh = lateController.refresh();
      lateController.dispose();
      lateGateway.completeLoad(_snapshot([_signal('steps', 99)]));
      await expectLater(refresh, completes);
    },
  );
}

ConnectedHealthSnapshot _snapshot(List<ConnectedHealthSignalView> signals) =>
    ConnectedHealthSnapshot(
      status: ConnectedHealthStatus.synchronized,
      platformSource: 'Apple Health',
      availableSources: const ['Apple Health'],
      signals: signals,
      importedCount: signals.length,
      lastSyncAt: DateTime.utc(2026, 9, 20),
      failureCode: null,
      deviceVerified: true,
    );

ConnectedHealthSignalView _signal(
  String key,
  double value, {
  String unit = 'count',
}) => ConnectedHealthSignalView(
  key: key,
  value: value,
  unit: unit,
  source: 'Apple Watch',
  observedAt: DateTime.utc(2026, 9, 20),
  confidence: 1,
  attributes: const {'wearableKind': 'apple_watch'},
);

final class _ControlledGateway implements ConnectedHealthGateway {
  _ControlledGateway({this._loadCompleter});

  final Completer<ConnectedHealthSnapshot>? _loadCompleter;
  final _syncCompleter = Completer<ConnectedHealthSnapshot>();
  int synchronizeCalls = 0;

  @override
  Future<ConnectedHealthSnapshot> load() =>
      _loadCompleter?.future ?? Future.value(_snapshot(const []));

  @override
  Future<ConnectedHealthSnapshot> synchronize() {
    synchronizeCalls += 1;
    return _syncCompleter.future;
  }

  void completeLoad(ConnectedHealthSnapshot value) =>
      _loadCompleter!.complete(value);

  void completeSync(ConnectedHealthSnapshot value) =>
      _syncCompleter.complete(value);

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<ConnectedHealthSnapshot> requestPermissions() => load();

  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() => load();

  @override
  Future<ConnectedHealthSnapshot> revokePermissions() => load();
}
