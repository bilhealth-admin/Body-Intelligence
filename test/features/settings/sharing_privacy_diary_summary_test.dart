import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/settings/sharing_privacy_settings_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('diary sharing values have safe persisted-state normalization', () {
    expect(normalizeDiarySharingPreference(null), 'private');
    expect(normalizeDiarySharingPreference(''), 'private');
    expect(normalizeDiarySharingPreference('unexpected'), 'private');
    for (final value in const ['private', 'friends', 'public', 'locked']) {
      expect(normalizeDiarySharingPreference(value), value);
    }
  });

  test('diary sharing summaries resolve through all runtime locales', () {
    for (final key in const [
      'Private',
      'Friends only',
      'Public',
      'Locked with a key',
    ]) {
      for (final locale in RuntimeCopy.supported) {
        final copy = RuntimeCopy.resolve(key, locale);
        expect(copy, isNotNull, reason: '$key / $locale');
        expect(copy!.trim(), isNotEmpty, reason: '$key / $locale');
      }
    }
  });

  testWidgets(
    'Sharing & Privacy reacts to every stored diary state and still navigates',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final preferences = PreferencesRepository(database);
      await preferences.set('diary.sharing', 'private');

      final router = GoRouter(
        initialLocation: '/privacy',
        routes: [
          GoRoute(
            path: '/privacy',
            builder: (_, _) => const SharingPrivacySettingsPage(),
          ),
          GoRoute(
            path: '/settings/diary/sharing',
            builder: (_, _) => const Scaffold(
              body: Center(
                child: Text(
                  'Diary sharing destination',
                  key: Key('diary-sharing-destination'),
                ),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(database)],
          child: MaterialApp.router(
            locale: const Locale('en'),
            routerConfig: router,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      Finder diaryTile() =>
          find.byKey(const Key('sharing-privacy-diary-sharing'));

      void expectSummary(String copy) {
        expect(
          find.descendant(of: diaryTile(), matching: find.text(copy)),
          findsOneWidget,
        );
      }

      expectSummary('Private');
      for (final entry in const {
        'friends': 'Friends only',
        'public': 'Public',
        'locked': 'Locked with a key',
        'private': 'Private',
      }.entries) {
        await preferences.set('diary.sharing', entry.key);
        await tester.pumpAndSettle();
        expectSummary(entry.value);
      }

      await tester.tap(diaryTile());
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('diary-sharing-destination')),
        findsOneWidget,
      );

      router.pop();
      await tester.pumpAndSettle();
      expect(diaryTile(), findsOneWidget);
      expectSummary('Private');
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(Duration.zero);
      await tester.pump(Duration.zero);
    },
  );
}
