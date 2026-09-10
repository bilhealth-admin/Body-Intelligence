import 'dart:async';

import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final fails in [false, true]) {
    test(
      'disposed controller ignores a late status ${fails ? 'error' : 'result'}',
      () async {
        final gateway = _PendingGateway();
        final controller = ConnectedHealthController(gateway);
        final pending = controller.refresh();
        controller.dispose();
        final completion = expectLater(pending, completes);
        if (fails) {
          gateway.status.completeError(StateError('offline'));
        } else {
          gateway.status.complete(const ConnectedHealthSnapshot.unavailable());
        }
        await completion;
      },
    );
  }

  test('a queued refresh cannot start native work after disposal', () async {
    final gateway = _PendingGateway();
    final controller = ConnectedHealthController(gateway);
    final mutation = controller.requestPermissions();
    final refresh = controller.refresh();
    controller.dispose();
    final completion = expectLater(Future.wait([mutation, refresh]), completes);
    gateway.permission.complete(const ConnectedHealthSnapshot.unavailable());
    await completion;
    expect(gateway.loadCalls, 0);
  });

  test('an explicit permission request survives an activity refresh', () async {
    final gateway = _PendingActivityGateway();
    final controller = ConnectedHealthController(gateway);
    addTearDown(controller.dispose);
    final activity = controller.refreshDailyActivity(force: true);
    final permission = controller.requestPermissions();
    expect(gateway.permissionCalls, 0);
    gateway.activity.complete(const ConnectedHealthSnapshot.unavailable());
    await activity;
    await Future<void>.delayed(Duration.zero);
    expect(gateway.permissionCalls, 1);
    gateway.permission.complete(const ConnectedHealthSnapshot.unavailable());
    await permission;
  });

  test('repeated permission taps share the same native request', () async {
    final gateway = _PendingGateway();
    final controller = ConnectedHealthController(gateway);
    addTearDown(controller.dispose);
    final first = controller.requestPermissions();
    final second = controller.requestPermissions();
    expect(gateway.permissionCalls, 1);
    gateway.permission.complete(const ConnectedHealthSnapshot.unavailable());
    await Future.wait([first, second]);
    expect(gateway.permissionCalls, 1);
  });
}

class _PendingGateway implements ConnectedHealthGateway {
  final status = Completer<ConnectedHealthSnapshot>();
  final permission = Completer<ConnectedHealthSnapshot>();
  int loadCalls = 0;
  int permissionCalls = 0;

  @override
  Future<ConnectedHealthSnapshot> load() {
    loadCalls++;
    return status.future;
  }

  @override
  Future<ConnectedHealthSnapshot> requestPermissions() {
    permissionCalls++;
    return permission.future;
  }

  @override
  Future<void> openSystemSettings() => throw UnimplementedError();
  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() =>
      throw UnimplementedError();
  @override
  Future<ConnectedHealthSnapshot> revokePermissions() =>
      throw UnimplementedError();
  @override
  Future<ConnectedHealthSnapshot> synchronize() => throw UnimplementedError();
}

class _PendingActivityGateway extends _PendingGateway
    implements ConnectedHealthDailyActivityGateway {
  final activity = Completer<ConnectedHealthSnapshot>();

  @override
  Future<ConnectedHealthSnapshot> loadDailyActivity() => activity.future;
}
