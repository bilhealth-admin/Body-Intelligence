import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_sync_models.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_manual_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a failed paused page is attempted once, not twenty times', () async {
    var calls = 0;
    final report = await drainCloudSyncPages(() async {
      calls++;
      return _report(pulled: 0, availability: CloudPlatformAvailability.paused);
    });

    expect(calls, 1);
    expect(report.completed, isFalse);
  });

  test('drains 201 records across three cursor-backed pages', () async {
    var calls = 0;
    final report = await drainCloudSyncPages(() async {
      calls++;
      return _report(
        pulled: calls < 3 ? 100 : 1,
        hasMore: calls < 3,
        cursorAdvanced: true,
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
          hasMore: true,
          cursorAdvanced: true,
          availability: CloudPlatformAvailability.paused,
        );
      }, maximumPages: 2);

      expect(calls, 2);
      expect(report.availability, CloudPlatformAvailability.paused);
      expect(report.pulled, 200);
    },
  );
  test('a page that claims more data without cursor progress stops', () async {
    var calls = 0;
    await drainCloudSyncPages(() async {
      calls++;
      return _report(
        pulled: 100,
        availability: CloudPlatformAvailability.paused,
        hasMore: true,
      );
    });
    expect(calls, 1);
  });

  test('a failure code stops even a page claiming progress', () async {
    var calls = 0;
    final report = await drainCloudSyncPages(() async {
      calls++;
      return _report(
        pulled: 1,
        availability: CloudPlatformAvailability.paused,
        hasMore: true,
        cursorAdvanced: true,
        failureCode: 'cloud_sync_cursor_write_failed',
      );
    });
    expect(calls, 1);
    expect(report.failureCode, 'cloud_sync_cursor_write_failed');
    expect(report.completed, isFalse);
  });

  test('rejects a non-positive page limit before making a request', () async {
    var calls = 0;
    await expectLater(
      drainCloudSyncPages(() async {
        calls++;
        return _report(
          pulled: 0,
          availability: CloudPlatformAvailability.ready,
        );
      }, maximumPages: 0),
      throwsArgumentError,
    );
    expect(calls, 0);
  });
}

CloudSyncReport _report({
  required int pulled,
  required CloudPlatformAvailability availability,
  bool hasMore = false,
  bool cursorAdvanced = false,
  String? failureCode,
}) => CloudSyncReport(
  startedAt: DateTime.utc(2026, 9, 28),
  completedAt: DateTime.utc(2026, 9, 28, 0, 0, 1),
  pushed: 0,
  pulled: pulled,
  conflicts: 0,
  pending: 0,
  availability: availability,
  diagnostics: const [],
  hasMore: hasMore,
  cursorAdvanced: cursorAdvanced,
  failureCode: failureCode,
);
