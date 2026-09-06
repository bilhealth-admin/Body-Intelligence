import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/services/runtime_permission_policy.dart';
import 'package:body_intelligence_log/app/theme/bil_semantic_icons.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/goal_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/dietary_preferences.dart';
import 'package:body_intelligence_log/features/nutrition/repositories/dietary_preferences_repository.dart';
import 'package:body_intelligence_log/features/profile/premium_profile_page.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/profile/services/profile_photo_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'profile changes autosave profile goal and preferences together',
    (tester) async {
      final database = await _seedDatabase();
      await _pumpProfile(tester, database);

      await tester.tap(find.byKey(const Key('profile-display-name-row')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Ava');
      await tester.tap(find.text('Apply'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(const Key('profile-settings-save')), findsNothing);
      expect(await PreferencesRepository(database).get('displayName'), 'Ava');
      final goal = await (database.select(
        database.goals,
      )..limit(1)).getSingleOrNull();
      expect(goal?.type, 'lose');
      expect(goal?.targetWeight, 85);
      final profile = await UserProfileRepository(database).getProfile();
      expect(profile?.currentWeight, 93.4);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await database.close();
    },
  );

  testWidgets('failed profile transaction rolls back and exposes retry error', (
    tester,
  ) async {
    final database = await _seedDatabase();
    await _pumpProfile(
      tester,
      database,
      preferences: _FailingPreferencesRepository(database),
    );

    await tester.tap(find.byKey(const Key('profile-display-name-row')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Ava');
    await tester.tap(find.text('Apply'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.text('Your health profile could not be saved. Try again.'),
      findsWidgets,
    );
    expect(
      await (database.select(database.goals)..limit(1)).getSingleOrNull(),
      isNull,
    );
    expect(await PreferencesRepository(database).get('displayName'), isNull);
    expect(find.byKey(const Key('profile-settings-save')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await database.close();
  });

  testWidgets(
    'dietary summary row shows saved choice and opens profile origin',
    (tester) async {
      final database = await _seedDatabase();
      await DietaryPreferencesRepository(PreferencesRepository(database)).save(
        const DietaryPreferences(
          pattern: DietaryPattern.vegan,
          approach: 'high_protein',
        ),
      );
      final router = GoRouter(
        initialLocation: '/profile-settings',
        routes: [
          GoRoute(
            path: '/profile-settings',
            builder: (_, _) => const PremiumProfilePage(),
          ),
          GoRoute(
            path: '/plan',
            builder: (_, state) => Scaffold(
              body: Text(
                'plan-origin:${state.uri.queryParameters['origin']}',
                key: const Key('plan-origin-probe'),
              ),
            ),
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

      final row = find.byKey(const Key('profile-dietary-system-row'));
      await tester.ensureVisible(row);
      expect(find.text('Dietary system'), findsOneWidget);
      expect(find.text('Vegan · High protein'), findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('plan-origin-probe')), findsOneWidget);
      expect(find.text('plan-origin:profile'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      router.dispose();
      await database.close();
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets(
    'profile labels stay complete on phone and RTL large text layouts',
    (tester) async {
      final database = await _seedDatabase();
      addTearDown(database.close);

      void expectReadableRow(Key key, String expectedLabel) {
        final row = find.byKey(key);
        final textFinder = find.descendant(
          of: row,
          matching: find.byType(Text),
        );
        final texts = tester.widgetList<Text>(textFinder).toList();
        final label = texts.singleWhere(
          (widget) => widget.data == expectedLabel,
        );
        final values = texts.where((widget) => widget.data != expectedLabel);

        expect(label.maxLines, isNull);
        expect(label.overflow, isNot(TextOverflow.ellipsis));
        expect(label.softWrap, isNot(false));
        expect(
          values,
          isNotEmpty,
          reason: 'The row value must remain visible.',
        );
        for (final value in values) {
          expect(value.data?.trim(), isNotEmpty);
          expect(value.maxLines, isNull);
          expect(value.overflow, isNot(TextOverflow.ellipsis));
          expect(value.softWrap, isNot(false));
        }
        expect(
          find.descendant(of: row, matching: find.byType(BilSemanticIconBadge)),
          findsOneWidget,
        );
      }

      await _pumpProfile(tester, database);
      expectReadableRow(const Key('profile-display-name-row'), 'Display name');
      final englishDietary = find.byKey(
        const Key('profile-dietary-system-row'),
      );
      await tester.scrollUntilVisible(
        englishDietary,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expectReadableRow(
        const Key('profile-dietary-system-row'),
        'Dietary system',
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await _pumpProfile(
        tester,
        database,
        locale: const Locale('ar'),
        textScaler: const TextScaler.linear(1.6),
        surfaceSize: const Size(320, 844),
      );
      final arabicDisplayName = find.byKey(
        const Key('profile-display-name-row'),
      );
      expect(
        Directionality.of(tester.element(arabicDisplayName)),
        TextDirection.rtl,
      );
      expectReadableRow(const Key('profile-display-name-row'), 'الاسم الظاهر');
      final arabicDietary = find.byKey(const Key('profile-dietary-system-row'));
      await tester.scrollUntilVisible(
        arabicDietary,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expectReadableRow(
        const Key('profile-dietary-system-row'),
        'النظام الغذائي',
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'goal timeline reacts live to a changed goal and remains after save',
    (tester) async {
      final database = await _seedDatabase();
      await _pumpProfile(tester, database);

      final timeline = find.byKey(const Key('profile-health-goal-row'));
      await tester.scrollUntilVisible(
        timeline,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      String timelineValue() => tester
          .widgetList<Text>(
            find.descendant(of: timeline, matching: find.byType(Text)),
          )
          .last
          .data!;
      final before = timelineValue();
      await tester.tap(timeline);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('estimated-time-to-goal-field')),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final goalRow = find.byKey(const Key('profile-goal-weight-row'));
      await tester.ensureVisible(goalRow);
      await tester.tap(goalRow);
      await tester.pumpAndSettle();
      final editor = find.byType(TextField).last;
      await tester.enterText(editor, '92');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(timeline);
      final live = timelineValue();
      expect(live, isNot(before));
      expect(
        (await UserProfileRepository(database).getProfile())?.targetWeight,
        92,
      );
      expect(timelineValue(), live);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await database.close();
    },
  );

  testWidgets('sex chooser is centered, arrow-free, and persists selection', (
    tester,
  ) async {
    final database = await _seedDatabase();
    await _pumpProfile(tester, database);

    final sexRow = find.byKey(const Key('profile-sex-row'));
    await tester.scrollUntilVisible(
      sexRow,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(sexRow);
    await tester.pumpAndSettle();

    final chooser = find.byType(BottomSheet);
    final options = find.descendant(
      of: chooser,
      matching: find.byType(ListTile),
    );
    expect(options, findsNWidgets(2));
    for (final tile in tester.widgetList<ListTile>(options)) {
      expect(tile.trailing, isNull);
      expect((tile.title as Text).textAlign, TextAlign.center);
    }

    await tester.tap(options.at(1));
    await tester.pumpAndSettle();
    expect(find.text('Female'), findsOneWidget);

    expect(
      (await UserProfileRepository(database).getProfile())?.gender,
      'female',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await database.close();
  });

  testWidgets('profile Add photo offers camera and the native photo library', (
    tester,
  ) async {
    final database = await _seedDatabase();
    final photoService = _TrackingProfilePhotoService(
      PreferencesRepository(database),
    );
    await _pumpProfile(tester, database, photoService: photoService);

    final photoRow = find.byKey(const Key('profile-photo-row'));
    await tester.ensureVisible(photoRow);
    expect(find.text('Add photo'), findsOneWidget);
    await tester.tap(photoRow);
    await tester.pumpAndSettle();

    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Choose from device'), findsOneWidget);
    expect(photoService.chooseAttempts, 0);
    await tester.tap(find.byKey(const Key('profile-photo-library-action')));
    await tester.pumpAndSettle();
    expect(photoService.chooseAttempts, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await database.close();
  });

  testWidgets('profile camera choice uses the in-app camera launcher', (
    tester,
  ) async {
    final database = await _seedDatabase();
    var cameraLaunchAttempts = 0;
    final photoService = _TrackingProfilePhotoService(
      PreferencesRepository(database),
    );
    await _pumpProfile(
      tester,
      database,
      photoService: photoService,
      cameraPolicy: const _GrantedProfileCameraPolicy(),
      cameraLauncher: (context, {required title, required captureLabel}) {
        cameraLaunchAttempts += 1;
        return Future.value(null);
      },
    );
    await tester.tap(find.byKey(const Key('profile-photo-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-photo-camera-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(cameraLaunchAttempts, 1);
    expect(photoService.chooseAttempts, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await database.close();
  });

  testWidgets('profile camera asks just-in-time before opening capture', (
    tester,
  ) async {
    final database = await _seedDatabase();
    final cameraPolicy = _RequestingProfileCameraPolicy();
    var cameraLaunchAttempts = 0;
    await _pumpProfile(
      tester,
      database,
      cameraPolicy: cameraPolicy,
      cameraLauncher: (context, {required title, required captureLabel}) {
        cameraLaunchAttempts += 1;
        return Future.value(null);
      },
    );

    await tester.tap(find.byKey(const Key('profile-photo-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-photo-camera-action')));
    await tester.pumpAndSettle();

    expect(find.text('Allow camera for this action?'), findsOneWidget);
    expect(cameraPolicy.requestAttempts, 0);
    expect(cameraLaunchAttempts, 0);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(cameraPolicy.requestAttempts, 1);
    expect(cameraLaunchAttempts, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await database.close();
  });

  testWidgets(
    'health-goal weight edit writes the authoritative measurement and preserves direction',
    (tester) async {
      final database = await _seedDatabase();
      addTearDown(database.close);
      final profiles = UserProfileRepository(database);
      final profile = (await profiles.getProfile())!;
      await WeightRepository(
        database,
      ).addWeight(93.4, date: DateTime(2026, 8, 20));
      await GoalRepository(
        database,
      ).save(profileUuid: profile.uuid, type: 'lose', targetWeight: 85);
      await _pumpProfile(tester, database);

      final currentWeightRow = find.byKey(
        const Key('profile-current-weight-row'),
      );
      await tester.scrollUntilVisible(
        currentWeightRow,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(currentWeightRow);
      await tester.pumpAndSettle();
      final currentWeightAction = find.descendant(
        of: currentWeightRow,
        matching: find.byType(InkWell),
      );
      expect(currentWeightAction.hitTestable(), findsOneWidget);
      await tester.tap(currentWeightAction);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '84');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect((await profiles.getProfile())?.currentWeight, 84);
      expect((await WeightRepository(database).getAll()).first.weight, 84);
      expect(
        (await (database.select(database.goals)..limit(1)).getSingle()).type,
        'lose',
      );
      expect(find.text('Already at goal'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}

Future<AppDatabase> _seedDatabase() async {
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
  return database;
}

Future<void> _pumpProfile(
  WidgetTester tester,
  AppDatabase database, {
  PreferencesRepository? preferences,
  ProfilePhotoService? photoService,
  BilRuntimePermissionPolicy? cameraPolicy,
  ProfileCameraLauncher? cameraLauncher,
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
  Size surfaceSize = const Size(390, 844),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        if (preferences != null)
          preferencesRepositoryProvider.overrideWithValue(preferences),
        if (photoService != null)
          profilePhotoServiceProvider.overrideWithValue(photoService),
        if (cameraPolicy != null)
          profileRuntimePermissionPolicyProvider.overrideWithValue(
            cameraPolicy,
          ),
        if (cameraLauncher != null)
          profileCameraLauncherProvider.overrideWithValue(cameraLauncher),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: const PremiumProfilePage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _GrantedProfileCameraPolicy extends BilRuntimePermissionPolicy {
  const _GrantedProfileCameraPolicy();

  @override
  Future<BilRuntimePermissionState> status(
    BilRuntimeCapability capability,
  ) async => BilRuntimePermissionState.granted;
}

final class _RequestingProfileCameraPolicy extends BilRuntimePermissionPolicy {
  int requestAttempts = 0;

  @override
  Future<BilRuntimePermissionState> status(
    BilRuntimeCapability capability,
  ) async => BilRuntimePermissionState.denied;

  @override
  Future<BilRuntimePermissionState> request(
    BilRuntimeCapability capability,
  ) async {
    requestAttempts += 1;
    return BilRuntimePermissionState.granted;
  }
}

final class _TrackingProfilePhotoService extends ProfilePhotoService {
  _TrackingProfilePhotoService(super.preferences);

  int chooseAttempts = 0;

  @override
  Future<ProfilePhotoSaveResult?> chooseAndSave({
    bool recoveredOnly = false,
  }) async {
    chooseAttempts += 1;
    return null;
  }
}

final class _FailingPreferencesRepository extends PreferencesRepository {
  _FailingPreferencesRepository(super.database);

  @override
  Future<void> setManyInCurrentTransaction(Map<String, String> values) {
    throw StateError('Injected preference failure');
  }
}
