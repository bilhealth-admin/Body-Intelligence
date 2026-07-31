import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('location settings owns country city timezone and device detection', () {
    final source = File(
      'lib/features/settings/location_settings_page.dart',
    ).readAsStringSync();

    expect(source, contains('showCountryPicker('));
    expect(source, contains("setOrRemove('countryCode', countryCode)"));
    expect(source, contains("setOrRemove('countryRegion', countryName)"));
    expect(source, contains("setOrRemove('cityName', cityController.text)"));
    expect(
      source,
      contains("setOrRemove('timezoneName', timezoneController.text)"),
    );
    expect(source, contains("'locationSource',"));
    expect(source, contains('PlatformDispatcher.instance.locale'));
    expect(source, contains("key: const Key('location-city-field')"));
    expect(source, contains("key: const Key('location-timezone-field')"));
    expect(source, contains("context.go('/settings')"));
  });

  test('country selection is complete and city entry has honest fallback', () {
    final source = File(
      'lib/features/settings/location_settings_page.dart',
    ).readAsStringSync();
    final catalog = File(
      'lib/features/settings/location_catalog.dart',
    ).readAsStringSync();

    expect(source, contains('every city is accepted'));
    expect(catalog, contains('Country selection itself remains complete'));
    expect(catalog, contains("BilCityOption(nameEn: 'Cairo'"));
    expect(catalog, contains("BilCityOption(nameEn: 'Amman'"));
  });
}
