import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard requests a recorded cloud retention choice', () {
    final dashboard = File(
      'lib/features/dashboard/dashboard_page.dart',
    ).readAsStringSync();
    final notice = File(
      'lib/features/cloud_platform/presentation/cloud_sync_consent_notice.dart',
    ).readAsStringSync();
    final summary = File(
      'lib/features/cloud_platform/presentation/cloud_sync_consent_summary.dart',
    ).readAsStringSync();

    expect(dashboard, contains('CloudSyncConsentNotice'));
    expect(notice, contains('showModalBottomSheet<bool>'));
    expect(notice, isNot(contains('showDialog<bool>')));
    expect(notice, contains('isDismissible: false'));
    expect(notice, contains('enableDrag: false'));
    expect(notice, contains('state.recordedAt == null'));
    expect(notice, contains('.setGranted(enable)'));
    expect(notice, contains('cloud-sync-keep-local'));
    expect(notice, contains('cloud-sync-enable-backup'));
    expect(notice, contains('CloudSyncConsentCopy.title'));
    expect(notice, contains('CloudSyncConsentCopy.primaryAction'));
    expect(notice, contains('CloudSyncConsentCopy.localAction'));
    expect(notice, contains('const CloudSyncConsentSummary()'));
    expect(notice, contains('Icons.backup_rounded'));
    expect(notice, isNot(contains('Icons.warning')));
    expect(notice, isNot(contains('Keep your BIL data safe?')));
    expect(summary, contains('cloud-sync-benefit-restore'));
    expect(summary, contains('cloud-sync-benefit-continuity'));
    expect(summary, contains('cloud-sync-benefit-privacy'));
    expect(summary, contains('cloud-sync-local-nutrition'));
    expect(summary, contains('cloud-sync-choice-control'));
    expect(summary, contains('if (showDeletionControl)'));
    expect(notice, isNot(contains('setGranted(true);')));
  });
}
