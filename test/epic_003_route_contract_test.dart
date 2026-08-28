import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('location settings route is registered and reachable from settings', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final settings = File(
      'lib/features/settings/settings_page.dart',
    ).readAsStringSync();

    expect(router, contains("path: '/location-settings'"));
    expect(router, contains('const LocationSettingsPage()'));
    expect(settings, contains("'/location-settings'"));
    expect(settings, contains("Key('more-location-settings-entry')"));
  });
}
