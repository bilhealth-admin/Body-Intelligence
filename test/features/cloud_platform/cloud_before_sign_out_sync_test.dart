import 'package:body_intelligence_log/features/cloud_platform/presentation/cloud_auto_sync_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    Future<void> noop() async {}
    CloudBeforeSignOutSync.install(noop);
    CloudBeforeSignOutSync.uninstall();
  });

  test('runs the installed cloud flush before sign-out', () async {
    var calls = 0;
    Future<void> runner() async => calls++;

    CloudBeforeSignOutSync.install(runner);
    await CloudBeforeSignOutSync.runBounded();

    expect(calls, 1);
    CloudBeforeSignOutSync.uninstall();
  });

  test('keeps sign-out available when the cloud flush fails', () async {
    Future<void> runner() => Future<void>.error(StateError('offline'));

    CloudBeforeSignOutSync.install(runner);
    await expectLater(CloudBeforeSignOutSync.runBounded(), completes);
    CloudBeforeSignOutSync.uninstall();
  });
}
