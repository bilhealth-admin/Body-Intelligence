import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'automatic location mode is explicit, persisted, and privacy honest',
    () {
      final source = File(
        'lib/features/settings/location_settings_page.dart',
      ).readAsStringSync();

      expect(source, contains("key: const Key('automatic-location-switch')"));
      expect(source, contains("'automaticLocation'"));
      expect(source, contains("automaticLocation ? 'device' : 'manual'"));
      expect(source, contains('It does not use GPS or upload your location.'));
      expect(source, contains('if (!automaticLocation) ...['));
    },
  );

  test('manual mode retains country city and timezone controls', () {
    final source = File(
      'lib/features/settings/location_settings_page.dart',
    ).readAsStringSync();

    expect(source, contains('showCountryPicker('));
    expect(source, contains("key: const Key('location-city-field')"));
    expect(source, contains("key: const Key('location-timezone-field')"));
    expect(source, contains('every city is accepted'));
  });
}
