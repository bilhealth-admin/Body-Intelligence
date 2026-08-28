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

    expect(dashboard, contains('CloudSyncConsentNotice'));
    expect(notice, contains('showModalBottomSheet<bool>'));
    expect(notice, isNot(contains('showDialog<bool>')));
    expect(notice, contains('isDismissible: false'));
    expect(notice, contains('enableDrag: false'));
    expect(notice, contains('state.recordedAt == null'));
    expect(notice, contains('.setGranted(enable)'));
    expect(notice, contains('cloud-sync-keep-local'));
    expect(notice, contains('cloud-sync-enable-backup'));
    expect(notice, contains('future uploads stop'));
    expect(notice, contains('request data deletion'));
    expect(notice, isNot(contains('setGranted(true);')));
  });
}
