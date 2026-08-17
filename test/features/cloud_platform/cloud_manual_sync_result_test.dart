import 'package:body_intelligence_log/features/cloud_platform/services/cloud_manual_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual sync result is completed only for completed disposition', () {
    const completed = CloudManualSyncResult(
      disposition: CloudManualSyncDisposition.completed,
      pushed: 2,
      pulled: 1,
      applied: 1,
    );
    const offline = CloudManualSyncResult(
      disposition: CloudManualSyncDisposition.offline,
    );

    expect(completed.completed, isTrue);
    expect(completed.pushed, 2);
    expect(offline.completed, isFalse);
  });
}
