import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_sync_models.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_manual_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('drains 201 records across three cursor-backed pages', () async {
    var calls = 0;
    final report = await drainCloudSyncPages(() async {
      calls++;
      return _report(
        pulled: calls < 3 ? 100 : 1,
        availability: calls < 3
            ? CloudPlatformAvailability.paused
            : CloudPlatformAvailability.ready,
      );
    });

    expect(calls, 3);
    expect(report.availability, CloudPlatformAvailability.ready);
    expect(report.pulled, 201);
  });

  test(
    'bounded drain preserves a partial result without calling it unavailable',
    () async {
      var calls = 0;
      final report = await drainCloudSyncPages(() async {
        calls++;
        return _report(
          pulled: 100,
          availability: CloudPlatformAvailability.paused,
        );
      }, maximumPages: 2);

      expect(calls, 2);
      expect(report.availability, CloudPlatformAvailability.paused);
      expect(report.pulled, 200);
    },
  );
}

CloudSyncReport _report({
  required int pulled,
  required CloudPlatformAvailability availability,
}) => CloudSyncReport(
  startedAt: DateTime.utc(2026, 9, 28),
  completedAt: DateTime.utc(2026, 9, 28, 0, 0, 1),
  pushed: 0,
  pulled: pulled,
  conflicts: 0,
  pending: 0,
  availability: availability,
  diagnostics: const [],
);
