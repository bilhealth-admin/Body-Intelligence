import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/features/profile/profile_settings_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('hydration and scrolling remain pristine on back', (
    tester,
  ) async {
    final fixture = await _pumpEditor(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-settings-back')));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(fixture.router.routeInformationProvider.value.uri.path, '/settings');
    await fixture.dispose(tester);
  });

  testWidgets('an actual form edit still prompts before leaving', (
    tester,
  ) async {
    final fixture = await _pumpEditor(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Changed name');
    await tester.pump();
    await tester.tap(find.byKey(const Key('profile-settings-back')));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.text('You have unsaved changes.'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(
      fixture.router.routeInformationProvider.value.uri.path,
      '/advanced-body-measurements',
    );

    await tester.tap(find.byKey(const Key('profile-settings-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(fixture.router.routeInformationProvider.value.uri.path, '/settings');
    await fixture.dispose(tester);
  });
}

Future<_EditorFixture> _pumpEditor(WidgetTester tester) async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  await UserProfileRepository(database).save(
    gender: 'male',
    age: 35,
    height: 181,
    currentWeight: 93.4,
    targetWeight: 85,
    activityLevel: 'light',
    exercises: true,
  );
  final router = GoRouter(
    initialLocation: '/advanced-body-measurements',
    routes: [
      GoRoute(
        path: '/advanced-body-measurements',
        builder: (_, _) => const ProfileSettingsPage(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const Scaffold(body: Text('Settings')),
      ),
    ],
  );
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: MaterialApp.router(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _EditorFixture(database: database, router: router);
}

final class _EditorFixture {
  const _EditorFixture({required this.database, required this.router});

  final AppDatabase database;
  final GoRouter router;

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    router.dispose();
    await database.close();
    await tester.binding.setSurfaceSize(null);
  }
}
