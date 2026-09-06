import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/dashboard/dashboard_page.dart';
import 'package:body_intelligence_log/features/profile/services/profile_photo_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('remote-only dashboard avatar can be removed', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final photoService = _TrackingPhotoService(PreferencesRepository(database));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profilePhotoServiceProvider.overrideWithValue(photoService),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Builder(
                builder: (scaffoldContext) => TextButton(
                  key: const Key('open-profile-photo-menu'),
                  onPressed: () => const DashboardPage().manageProfilePhoto(
                    scaffoldContext,
                    ref,
                    null,
                    'https://example.test/avatar',
                    'en',
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-profile-photo-menu')));
    await tester.pumpAndSettle();

    expect(find.text('Change profile photo'), findsOneWidget);
    expect(find.text('Remove profile photo'), findsOneWidget);
    await tester.tap(find.text('Remove profile photo'));
    await tester.pumpAndSettle();

    expect(photoService.removeAttempts, 1);
  });
}

final class _TrackingPhotoService extends ProfilePhotoService {
  _TrackingPhotoService(super.preferences);

  int removeAttempts = 0;

  @override
  Future<void> remove() async {
    removeAttempts += 1;
  }
}
