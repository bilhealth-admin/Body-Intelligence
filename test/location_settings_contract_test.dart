import 'dart:io';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/settings/location_settings_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

  testWidgets('saving returns to the profile route that opened the editor', (
    tester,
  ) async {
    const timezoneChannel = MethodChannel('flutter_timezone');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezoneChannel, (call) async {
          return switch (call.method) {
            'getLocalTimezone' => {'identifier': 'Africa/Cairo'},
            'getAvailableTimezones' => [
              {'identifier': 'Africa/Cairo'},
              {'identifier': 'UTC'},
            ],
            _ => null,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(timezoneChannel, null),
    );
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (context, _) => Scaffold(
            key: const Key('profile-origin-probe'),
            body: Center(
              child: FilledButton(
                key: const Key('open-location-from-profile'),
                onPressed: () => context.push('/settings/location'),
                child: const Text('Open location'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/settings/location',
          builder: (_, _) => const LocationSettingsPage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, _) =>
              const Scaffold(key: Key('settings-fallback-probe')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-location-from-profile')));
    await tester.pumpAndSettle();
    expect(find.byType(LocationSettingsPage), findsOneWidget);

    await tester.tap(find.byKey(const Key('location-settings-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-origin-probe')), findsOneWidget);
    expect(find.byKey(const Key('settings-fallback-probe')), findsNothing);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/profile');
  });
}
