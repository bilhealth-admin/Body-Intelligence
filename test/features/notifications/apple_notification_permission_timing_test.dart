import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Apple notification initialization never prompts on cold launch', () {
    final source = File(
      'lib/features/notifications/services/bil_daily_notification_grouping.dart',
    ).readAsStringSync();

    expect(
      RegExp(r'requestAlertPermission:\s*false').allMatches(source).length,
      2,
    );
    expect(
      RegExp(r'requestBadgePermission:\s*false').allMatches(source).length,
      2,
    );
    expect(
      RegExp(r'requestSoundPermission:\s*false').allMatches(source).length,
      2,
    );
  });
}
