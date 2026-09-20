import 'package:body_intelligence_log/features/connected_health/steps_settings_page.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_extended.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('step settings has direct copy for every extended locale', () {
    const keys = <String>{
      'Steps',
      'Choose a source',
      'Phone motion and health source',
      'Uses a source only after you authorize it on this device.',
      'Connected watch',
      'A connected watch source is available.',
      'No connected watch source is available.',
      'Add a device',
      'Open connected-health sources and permissions.',
      'Do not track steps',
      'Step goal',
      'Daily step goal',
      'Not set',
      'Cancel',
      'Save',
      'Retry',
      'Step settings could not be loaded.',
      'Could not save step settings. Try again.',
      'Enter a whole-number goal from 1000 to 100000.',
      'Loading step settings',
      'Checking connected sources…',
      'Connected sources could not be checked.',
      'Retry connected sources',
    };
    for (final key in keys) {
      final values = ExtendedRuntimeCopy.values[key];
      expect(values, isNotNull, reason: key);
      for (final locale in ExtendedRuntimeCopy.supported) {
        final translated = values![locale]?.trim();
        expect(translated, isNotNull, reason: '$key|$locale');
        expect(translated, isNotEmpty, reason: '$key|$locale');
        expect(translated, isNot(key), reason: '$key|$locale');
      }
    }
  });

  test(
    'stored step goal is nullable and rejects corrupt or clamped values',
    () {
      expect(parseStoredStepGoal(null), isNull);
      expect(parseStoredStepGoal(''), isNull);
      expect(parseStoredStepGoal('NaN'), isNull);
      expect(parseStoredStepGoal('1'), isNull);
      expect(parseStoredStepGoal('1000000'), isNull);
      expect(parseStoredStepGoal('1000'), 1000);
      expect(parseStoredStepGoal('100000'), 100000);
    },
  );

  test('stored step source fails closed', () {
    expect(parseStoredStepSource(null), isNull);
    expect(parseStoredStepSource('watch'), 'watch');
    expect(parseStoredStepSource('device'), 'device');
    expect(parseStoredStepSource('none'), 'none');
    expect(parseStoredStepSource('Apple Watch'), isNull);
  });

  test('typed step store rejects invalid writes', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = PreferencesRepository(database);
    final store = StepsPreferencesStore(repository);
    expect(() => store.saveGoal(999), throwsArgumentError);
    expect(() => store.saveGoal(100001), throwsArgumentError);
    expect(() => store.saveSource('Apple Watch'), throwsArgumentError);
    expect(await repository.get('steps.dailyGoal'), isNull);
    expect(await repository.get('steps.source'), isNull);
    await database.close();
  });

  testWidgets('missing values stay unset and saved goal survives rebuild', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = PreferencesRepository(database);
    await _pump(tester, repository);

    expect(find.text('—'), findsOneWidget);
    expect(find.text('10000'), findsNothing);
    await tester.tap(find.byKey(const Key('daily-step-goal')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '7200');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(await repository.get('steps.dailyGoal'), '7200');

    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(tester, repository);
    expect(find.text('7200'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await database.close();
  });

  testWidgets('failed goal write retains editor and draft', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = _FailingPreferences(database);
    await _pump(tester, repository);
    await tester.tap(find.byKey(const Key('daily-step-goal')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '6500');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text('Could not save step settings. Try again.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '6500',
    );
    expect(await repository.get('steps.dailyGoal'), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await database.close();
  });

  testWidgets('source persists and connected-health error has a retry', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = PreferencesRepository(database);
    final gateway = _RetryHealthGateway();
    await _pump(tester, repository, gateway: gateway);
    expect(
      find.text('Connected sources could not be checked.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry connected sources'));
    await tester.pumpAndSettle();
    expect(
      find.text('No connected watch source is available.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Do not track steps'));
    await tester.pumpAndSettle();
    expect(await repository.get('steps.source'), 'none');
    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(tester, repository, gateway: gateway);
    expect(
      tester
          .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
          .groupValue,
      'none',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await database.close();
  });
}

Future<void> _pump(
  WidgetTester tester,
  PreferencesRepository repository, {
  ConnectedHealthGateway? gateway,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(repository),
        if (gateway != null)
          connectedHealthGatewayProvider.overrideWithValue(gateway),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const StepsSettingsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _RetryHealthGateway implements ConnectedHealthGateway {
  var loads = 0;
  @override
  Future<ConnectedHealthSnapshot> load() async {
    loads += 1;
    if (loads == 1) throw StateError('injected');
    return const ConnectedHealthSnapshot.unavailable();
  }

  @override
  Future<void> openSystemSettings() async {}
  @override
  Future<ConnectedHealthSnapshot> requestPermissions() => load();
  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() => load();
  @override
  Future<ConnectedHealthSnapshot> revokePermissions() => load();
  @override
  Future<ConnectedHealthSnapshot> synchronize() => load();
}

final class _FailingPreferences extends PreferencesRepository {
  _FailingPreferences(super.database);

  @override
  Future<void> set(String key, String value) async {
    if (key == 'steps.dailyGoal') throw StateError('injected');
    return super.set(key, value);
  }
}
