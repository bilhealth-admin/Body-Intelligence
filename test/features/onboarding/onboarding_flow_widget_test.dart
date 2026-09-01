import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_preferences.dart';
import 'package:body_intelligence_log/features/onboarding/models/onboarding_draft.dart';
import 'package:body_intelligence_log/features/onboarding/onboarding_page.dart';
import 'package:body_intelligence_log/features/onboarding/services/onboarding_permission_gateways.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late OnboardingDraftRepository drafts;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    drafts = OnboardingDraftRepository(PreferencesRepository(database));
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await database.close();
  });

  OnboardingDraft valid({
    String step = 'waist',
    String sex = 'female',
    MeasurementSystem system = MeasurementSystem.metric,
  }) => OnboardingDraft(
    stepId: step,
    preferredName: 'Nora',
    goals: const {OnboardingGoal.loseWeight, OnboardingGoal.improveNutrition},
    activity: 'moderate',
    regularExercise: true,
    birthDate: DateTime(1990, 5, 17),
    sex: sex,
    countryRegion: 'Egypt',
    localeTag: 'en',
    system: system,
    heightCm: 170,
    currentWeightKg: 80,
    targetWeightKg: 70,
    weeklyPaceKg: .5,
    remoteAiConsent: OnboardingRemoteAiConsent.declined,
    aiFocuses: const {CoachContextFocus.nutrition},
  );

  Future<void> mount(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    OnboardingRemoteAiGateway remote = const _RemoteAiGateway(),
    ConnectedHealthGateway health = const _HealthGateway(),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          onboardingRemoteAiGatewayProvider.overrideWithValue(remote),
          connectedHealthGatewayProvider.overrideWithValue(health),
          onboardingNotificationGatewayProvider.overrideWithValue(
            const _NotificationGateway(),
          ),
        ],
        child: MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const OnboardingPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
  }

  Future<void> pump(
    WidgetTester tester,
    OnboardingDraft draft, {
    Locale locale = const Locale('en'),
    OnboardingRemoteAiGateway remote = const _RemoteAiGateway(),
    ConnectedHealthGateway health = const _HealthGateway(),
  }) async {
    await drafts.save(draft);
    await mount(tester, locale: locale, remote: remote, health: health);
  }

  Future<void> mountRouted(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
        GoRoute(
          path: '/account-gateway',
          builder: (_, _) => const Scaffold(body: Text('Account gateway')),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (_, _) => const Scaffold(body: Text('Dashboard')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          onboardingRemoteAiGatewayProvider.overrideWithValue(
            const _RemoteAiGateway(),
          ),
          connectedHealthGatewayProvider.overrideWithValue(
            const _HealthGateway(),
          ),
          onboardingNotificationGatewayProvider.overrideWithValue(
            const _NotificationGateway(),
          ),
        ],
        child: MaterialApp.router(
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
  }

  testWidgets(
    'waist and neck are separate optional pages and female receives hip page',
    (tester) async {
      await pump(tester, valid(system: MeasurementSystem.imperial));

      expect(find.byKey(const Key('onboarding-waist')), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding-skip')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('onboarding-neck')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('onboarding-neck')), '14');
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('onboarding-hips')), findsOneWidget);
      expect((await drafts.load())!.neckCm, closeTo(35.56, .0001));

      await tester.tap(find.byKey(const Key('onboarding-skip')));
      await tester.pumpAndSettle();
      expect(find.text('Your starting plan'), findsOneWidget);
      expect(await UserProfileRepository(database).getProfile(), isNull);
    },
  );

  testWidgets('facts page offers a searchable country list', (tester) async {
    await pump(tester, valid(step: 'facts').copyWith(countryRegion: ''));

    final country = find.byKey(const Key('onboarding-country'));
    await tester.ensureVisible(country);
    await tester.pumpAndSettle();
    await tester.tap(country);
    await tester.pumpAndSettle();

    final searchField = find.byType(TextField).last;
    await tester.enterText(searchField, 'Egypt');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Egypt').last);
    await tester.pumpAndSettle();

    final countryField = tester.widget<TextField>(
      find.byKey(const Key('onboarding-country')),
    );
    expect(countryField.controller!.text, 'Egypt');
    expect((await drafts.load())!.countryRegion, 'Egypt');
  });

  testWidgets('target weight proceeds to weekly pace before pace validation', (
    tester,
  ) async {
    await pump(
      tester,
      valid(
        step: 'targetWeight',
      ).copyWith(targetWeightKg: null, weeklyPaceKg: null),
    );

    await tester.enterText(
      find.byKey(const Key('onboarding-target-weight')),
      '70',
    );
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    expect(find.text('Choose a weekly pace'), findsOneWidget);
    expect(
      find.text('Choose one of the safe weekly pace options shown.'),
      findsNothing,
    );
    expect((await drafts.load())!.stepId, 'pace');
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform persists real metric measurements page by page', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      await pump(tester, valid());
      await tester.enterText(find.byKey(const Key('onboarding-waist')), '82.5');
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('onboarding-neck')), findsOneWidget);
      expect((await drafts.load())!.waistCm, 82.5);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets(
    'unit toggle round trips metric to imperial to metric without canonical drift',
    (tester) async {
      const canonicalHeight = 170.0;
      const canonicalCurrentWeight = 80.0;
      const canonicalTargetWeight = 70.0;
      const canonicalWaist = 82.5;
      const canonicalNeck = 37.2;
      const canonicalHips = 96.4;
      await pump(
        tester,
        valid(step: 'units').copyWith(
          heightCm: canonicalHeight,
          currentWeightKg: canonicalCurrentWeight,
          targetWeightKg: canonicalTargetWeight,
          waistCm: canonicalWaist,
          neckCm: canonicalNeck,
          hipsCm: canonicalHips,
        ),
      );

      expect(find.byKey(const Key('onboarding-unit-toggle')), findsOneWidget);
      expect(find.text('Metric'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding-unit-toggle')));
      await tester.pumpAndSettle();

      var stored = await drafts.load();
      expect(stored!.system, MeasurementSystem.imperial);
      expect(stored.heightCm, canonicalHeight);
      expect(stored.currentWeightKg, canonicalCurrentWeight);
      expect(stored.targetWeightKg, canonicalTargetWeight);
      expect(stored.waistCm, canonicalWaist);
      expect(stored.neckCm, canonicalNeck);
      expect(stored.hipsCm, canonicalHips);

      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('onboarding-height')))
            .controller!
            .text,
        '66.93',
      );

      await tester.tap(find.byKey(const Key('onboarding-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding-unit-toggle')));
      await tester.pumpAndSettle();

      stored = await drafts.load();
      expect(stored!.system, MeasurementSystem.metric);
      expect(stored.heightCm, canonicalHeight);
      expect(stored.currentWeightKg, canonicalCurrentWeight);
      expect(stored.targetWeightKg, canonicalTargetWeight);
      expect(stored.waistCm, canonicalWaist);
      expect(stored.neckCm, canonicalNeck);
      expect(stored.hipsCm, canonicalHips);

      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('onboarding-height')))
            .controller!
            .text,
        '170',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('back and restart resume the exact draft step without writes', (
    tester,
  ) async {
    await pump(tester, valid(system: MeasurementSystem.imperial));
    await tester.enterText(find.byKey(const Key('onboarding-waist')), '32');
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('onboarding-neck')), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('onboarding-waist')), findsOneWidget);
    expect((await drafts.load())!.stepId, 'waist');
    expect((await drafts.load())!.waistCm, closeTo(81.28, .0001));
    expect(await UserProfileRepository(database).getProfile(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await mount(tester);
    expect(find.byKey(const Key('onboarding-waist')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('onboarding-waist')))
          .controller!
          .text,
      '32',
    );
    expect(await UserProfileRepository(database).getProfile(), isNull);
  });

  testWidgets('first-page Back saves typed data before leaving onboarding', (
    tester,
  ) async {
    await drafts.save(valid(step: 'name').copyWith(preferredName: ''));
    await mountRouted(tester);

    await tester.enterText(
      find.byKey(const Key('onboarding-name-field')),
      'Ada',
    );
    await tester.tap(find.byKey(const Key('onboarding-back')));
    await tester.pumpAndSettle();

    expect(find.text('Account gateway'), findsOneWidget);
    final saved = await drafts.load();
    expect(saved?.stepId, 'name');
    expect(saved?.preferredName, 'Ada');
  });

  testWidgets('Android system Back uses the same saved step transition', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await drafts.save(valid(step: 'waist'));
    await mountRouted(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Choose a weekly pace'), findsOneWidget);
    expect((await drafts.load())?.stepId, 'pace');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('rapid acknowledgement and Finish cannot resurrect the draft', (
    tester,
  ) async {
    final preferences = PreferencesRepository(database);
    await drafts.save(
      valid(step: 'review').copyWith(estimatesAcknowledged: false),
    );
    await mountRouted(tester);

    await tester.tap(find.byKey(const Key('onboarding-estimates-ack')));
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(await drafts.load(), isNull);
    expect(await preferences.get(OnboardingDraft.preferenceKey), isNull);
    expect(await preferences.get(OnboardingDraft.legacyPreferenceKey), isNull);
  });

  testWidgets(
    'changing female to male clears persisted hip and returning starts empty',
    (tester) async {
      await pump(tester, valid(step: 'facts').copyWith(hipsCm: 98));
      await tester.tap(find.text('Male'));
      await tester.pumpAndSettle();
      final male = (await drafts.load())!;
      expect(male.sex, 'male');
      expect(male.hipsCm, isNull);

      await tester.tap(find.text('Female'));
      await tester.pumpAndSettle();
      final femaleAgain = (await drafts.load())!;
      expect(femaleAgain.sex, 'female');
      expect(femaleAgain.hipsCm, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await drafts.save(femaleAgain.copyWith(stepId: 'hips'));
      await mount(tester);
      final hipField = tester.widget<TextField>(
        find.byKey(const Key('onboarding-hips')),
      );
      expect(hipField.controller!.text, isEmpty);
    },
  );

  testWidgets('measurement Skip removes stale waist, neck and hip values', (
    tester,
  ) async {
    var value = valid().copyWith(waistCm: 84, neckCm: 36, hipsCm: 99);
    for (final field in const ['waist', 'neck', 'hips']) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      value = value.copyWith(stepId: field);
      await pump(tester, value);
      await tester.tap(find.byKey(const Key('onboarding-skip')));
      await tester.pumpAndSettle();
      value = (await drafts.load())!;
      expect(switch (field) {
        'waist' => value.waistCm,
        'neck' => value.neckCm,
        _ => value.hipsCm,
      }, isNull);
    }
  });

  testWidgets('male path never asks for hip measurement', (tester) async {
    await pump(tester, valid(step: 'neck', sex: 'male'));
    expect(find.byKey(const Key('onboarding-neck')), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('onboarding-hips')), findsNothing);
    expect(find.text('Your starting plan'), findsOneWidget);
  });

  testWidgets('RTL, progress semantics and reduced motion remain usable', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await drafts.save(valid());
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            onboardingRemoteAiGatewayProvider.overrideWithValue(
              const _RemoteAiGateway(),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('ar'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const OnboardingPage(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      Directionality.of(tester.element(find.byType(OnboardingPage))),
      TextDirection.rtl,
    );
    final progress = find.byKey(const Key('onboarding-progress-semantics'));
    expect(progress, findsOneWidget);
    expect(tester.getSemantics(progress).value, contains('/'));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('platform page exposes only the real system health source', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await pump(tester, valid(step: 'integrations'));
    expect(find.text('Apple Health'), findsOneWidget);
    expect(find.textContaining('Health Connect'), findsNothing);
    expect(find.textContaining('blood pressure'), findsNothing);
    expect(find.textContaining('SpO2'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android integration page names Health Connect truthfully', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await pump(tester, valid(step: 'integrations'));
    expect(find.text('Health Connect'), findsOneWidget);
    expect(find.text('Apple Health'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('failed or signed-out AI consent never reports success', (
    tester,
  ) async {
    await pump(
      tester,
      valid(step: 'ai'),
      remote: const _RemoteAiGateway(
        result: OnboardingRemoteAiResult.authenticationRequired,
      ),
    );
    final enable = find.byKey(const Key('onboarding-enable-ai'));
    await tester.ensureVisible(enable);
    await tester.pumpAndSettle();
    await tester.tap(enable);
    await tester.pumpAndSettle();
    expect(find.textContaining('AI remains off'), findsOneWidget);
    expect(
      (await drafts.load())!.remoteAiConsent,
      OnboardingRemoteAiConsent.unknown,
    );
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pump();
    expect(
      find.text('Choose whether to enable cloud AI, or keep it off.'),
      findsOneWidget,
    );
  });

  testWidgets('signed-out restart preserves an explicit cloud AI opt-out', (
    tester,
  ) async {
    await pump(
      tester,
      valid(step: 'ai'),
      remote: const _RemoteAiGateway(
        result: OnboardingRemoteAiResult.authenticationRequired,
      ),
    );
    expect(
      (await drafts.load())!.remoteAiConsent,
      OnboardingRemoteAiConsent.declined,
    );
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Ready to start'), findsOneWidget);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('onboarding renders at phone width for $locale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pump(tester, valid(), locale: locale);
      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(OnboardingPage))),
        AppLocalizations.isRtl(locale) ? TextDirection.rtl : TextDirection.ltr,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

final class _RemoteAiGateway implements OnboardingRemoteAiGateway {
  const _RemoteAiGateway({this.result = OnboardingRemoteAiResult.declined});
  final OnboardingRemoteAiResult result;

  @override
  Future<OnboardingRemoteAiResult> read() async => result;

  @override
  Future<OnboardingRemoteAiResult> setGranted(bool granted) async => result;
}

final class _NotificationGateway implements OnboardingNotificationGateway {
  const _NotificationGateway();

  @override
  Future<bool> requestPermission() async => true;
}

final class _HealthGateway implements ConnectedHealthGateway {
  const _HealthGateway();

  @override
  Future<ConnectedHealthSnapshot> load() async =>
      const ConnectedHealthSnapshot.unavailable();

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
