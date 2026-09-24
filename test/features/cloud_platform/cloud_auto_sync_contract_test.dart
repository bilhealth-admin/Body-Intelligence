import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auto sync is bounded, debounced, selective and lifecycle aware', () {
    final source = File(
      'lib/features/cloud_platform/presentation/cloud_auto_sync_coordinator.dart',
    ).readAsStringSync();
    final service = File(
      'lib/features/cloud_platform/services/cloud_manual_sync_service.dart',
    ).readAsStringSync();

    expect(source, contains('Duration(seconds: 2)'));
    expect(source, contains('Duration(seconds: 12)'));
    expect(source, contains('AppLifecycleState.resumed'));
    expect(source, contains('onConnectivityChanged'));
    expect(source, contains('database.userProfile'));
    expect(source, contains('database.weightEntries'));
    expect(source, contains('database.waterEntries'));
    expect(service, contains('CloudEntityKind.profile'));
    expect(service, contains('CloudEntityKind.weight'));
    expect(service, contains('CloudEntityKind.hydration'));
    expect(service, isNot(contains('CloudEntityKind.nutrition')));
  });
}
