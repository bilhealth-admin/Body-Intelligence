import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/settings/reference_preferences_pages.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('email choices are editable and persist locally', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final preferences = PreferencesRepository(database);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          preferencesRepositoryProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: ReferenceEmailSettingsPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    const labels = [
      'New feature announcements',
      'Healthy living tips',
      'Healthy recipes',
      'Workout recommendations',
      'Gear recommendations and offers',
      'Weekly digest',
      'People can find me by email address',
      'Someone sends me a message',
      'Someone sends me a friend request',
      'Someone invites me to a group',
      'Someone accepts my friend request',
      'Someone accepts my group invitation',
    ];
    for (final label in labels) {
      final tile = find.widgetWithText(SwitchListTile, label);
      await tester.scrollUntilVisible(tile, 320);
      expect(tester.widget<SwitchListTile>(tile).onChanged, isNotNull);
    }

    final weeklyDigestTile = find.widgetWithText(
      SwitchListTile,
      'Weekly digest',
    );
    await tester.ensureVisible(weeklyDigestTile);
    tester.widget<SwitchListTile>(weeklyDigestTile).onChanged!(true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(await preferences.get('email.weeklyDigest'), 'true');
  });
}
