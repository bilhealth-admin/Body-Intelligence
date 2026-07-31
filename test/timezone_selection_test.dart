import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/settings/location_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_timezone');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return switch (call.method) {
            'getLocalTimezone' => {'identifier': 'Africa/Cairo'},
            'getAvailableTimezones' => [
              {'identifier': 'Africa/Cairo'},
              {'identifier': 'Asia/Amman'},
              {'identifier': 'Europe/London'},
            ],
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('uses device IANA default and searchable canonical choices', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(
            PreferencesRepository(database),
          ),
        ],
        child: const MaterialApp(home: LocationSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('automatic-location-switch')));
    await tester.pumpAndSettle();
    final timezoneField = tester.widget<TextField>(
      find.byKey(const Key('location-timezone-field')),
    );
    expect(timezoneField.readOnly, isTrue);
    expect(timezoneField.controller?.text, 'Africa/Cairo');
    await tester.tap(find.byKey(const Key('location-timezone-field')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('timezone-search-field')),
      'Amman',
    );
    await tester.pump();
    expect(find.text('Asia/Amman'), findsOneWidget);
    await tester.tap(find.text('Asia/Amman'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('location-timezone-field')))
          .controller
          ?.text,
      'Asia/Amman',
    );
  });
}
