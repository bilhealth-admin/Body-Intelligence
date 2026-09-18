import 'dart:async';

import 'package:body_intelligence_log/features/cloud_platform/services/cloud_auto_sync_controller.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_manual_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('resume requests one sync and coalesces concurrent requests', (
    tester,
  ) async {
    final pending = Completer<CloudManualSyncResult>();
    var calls = 0;
    final controller = CloudAutoSyncController(
      interval: const Duration(hours: 1),
      runSync: () {
        calls++;
        return pending.future;
      },
    )..start();

    await tester.pump();
    expect(calls, 1);
    unawaited(controller.requestSync());
    expect(calls, 1);

    pending.complete(
      CloudManualSyncResult(
        disposition: CloudManualSyncDisposition.completed,
        completedAt: DateTime.utc(2026, 9, 19),
      ),
    );
    await tester.pump();
    expect(controller.isRunning, isTrue);
    controller.dispose();
  });

  testWidgets('pause makes the worker inactive and resume retries', (
    tester,
  ) async {
    var calls = 0;
    final controller = CloudAutoSyncController(
      interval: const Duration(hours: 1),
      runSync: () async {
        calls++;
        return const CloudManualSyncResult(
          disposition: CloudManualSyncDisposition.offline,
        );
      },
    )..start();

    await tester.pump();
    final initialCalls = calls;
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    await controller.requestSync();
    expect(calls, initialCalls + 1);

    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(calls, greaterThan(initialCalls + 1));
    controller.dispose();
  });
}
