import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('community push registration respects permission and categories', () {
    final service = File(
      'lib/features/notifications/services/community_push_service.dart',
    ).readAsStringSync();
    final coordinator = File(
      'lib/features/notifications/presentation/community_push_registration_coordinator.dart',
    ).readAsStringSync();
    final preferences = File(
      'lib/features/notifications/domain/notification_delivery_preferences.dart',
    ).readAsStringSync();
    final ios = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final android = File(
      'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILPushProvider.kt',
    ).readAsStringSync();
    final androidActivity = File(
      'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/MainActivity.kt',
    ).readAsStringSync();
    final actions = File(
      'lib/features/notifications/presentation/notification_settings_actions.dart',
    ).readAsStringSync();
    expect(service, contains('bil_register_push_token_v2'));
    expect(service, contains('bil_set_push_delivery_categories_v2'));
    expect(service, contains('permissionGranted'));
    expect(service, contains('existingPermissionToken'));
    expect(service, contains('CommunityPushRegistrationPolicyStore'));
    expect(
      coordinator,
      contains('NotificationDeliveryPreferencesStore().load()'),
    );
    expect(preferences, contains('friendAccepted'));
    expect(ios, contains('existingPermissionToken'));
    expect(ios, contains('permissionGranted'));
    expect(android, contains('permissionGranted'));
    expect(androidActivity, contains('"existingPermissionToken"'));
    expect(
      actions,
      isNot(contains('if (enabled && !(_pushPreferences?.enabled ?? false))')),
    );
  });
}
