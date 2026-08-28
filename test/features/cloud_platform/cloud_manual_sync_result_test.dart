import 'package:body_intelligence_log/features/cloud_platform/services/cloud_manual_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual sync result is completed only for completed disposition', () {
    final completedAt = DateTime.utc(2026, 8, 21, 9, 30);
    final completed = CloudManualSyncResult(
      disposition: CloudManualSyncDisposition.completed,
      completedAt: completedAt,
      pushed: 2,
      pulled: 1,
      applied: 1,
    );
    const offline = CloudManualSyncResult(
      disposition: CloudManualSyncDisposition.offline,
    );

    expect(completed.completed, isTrue);
    expect(completed.completedAt, completedAt);
    expect(completed.pushed, 2);
    expect(offline.completed, isFalse);
    expect(offline.completedAt, isNull);
  });

  test('completed disposition cannot invent or omit completion time', () {
    expect(
      () => CloudManualSyncResult(
        disposition: CloudManualSyncDisposition.completed,
      ),
      throwsAssertionError,
    );
    expect(
      () => CloudManualSyncResult(
        disposition: CloudManualSyncDisposition.offline,
        completedAt: DateTime.utc(2026, 8, 21),
      ),
      throwsAssertionError,
    );
  });
}
