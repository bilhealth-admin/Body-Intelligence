import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 3C keeps transport locked and nutrition out of cloud scope', () {
    final providers = File(
      'lib/features/cloud_platform/providers/cloud_sync_providers.dart',
    ).readAsStringSync();
    final lock = File(
      'lib/features/cloud_platform/services/cloud_transport_activation_lock.dart',
    ).readAsStringSync();
    final applier = File(
      'lib/features/cloud_platform/services/app_database_cloud_inbox_applier.dart',
    ).readAsStringSync();

    final enabledKinds =
        RegExp(
          r'enabledKinds:\s*const <CloudEntityKind>\{([\s\S]*?)\}',
        ).firstMatch(providers)?.group(1) ??
        '';

    expect(enabledKinds, contains('CloudEntityKind.profile'));
    expect(enabledKinds, contains('CloudEntityKind.weight'));
    expect(enabledKinds, contains('CloudEntityKind.hydration'));
    expect(enabledKinds, isNot(contains('CloudEntityKind.nutrition')));
    expect(lock, contains('bool get isOnline => false'));
    expect(applier, isNot(contains('CloudEntityKind.nutrition =>')));
    expect(applier, contains('_InboxOutcome.unsupported'));
    expect(applier, isNot(contains('progressPhotoPath: Value(')));
  });
}
