import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/body_measurement_repository.dart';
import 'package:body_intelligence_log/data/repositories/goal_repository.dart';
import 'package:body_intelligence_log/data/repositories/plan_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_preferences.dart';
import 'package:body_intelligence_log/features/onboarding/domain/onboarding_completion_service.dart';
import 'package:body_intelligence_log/features/onboarding/domain/onboarding_goal_bindings.dart';
import 'package:body_intelligence_log/features/onboarding/models/onboarding_draft.dart';
import 'package:body_intelligence_log/features/onboarding/onboarding_page.dart';
import 'package:body_intelligence_log/features/onboarding/services/onboarding_permission_gateways.dart';
import 'package:body_intelligence_log/features/nutrition/repositories/dietary_preferences_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late PreferencesRepository preferences;
  late OnboardingDraftRepository drafts;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    preferences = PreferencesRepository(database);
    drafts = OnboardingDraftRepository(preferences);
  });

  tearDown(() => database.close());

  OnboardingDraft canonicalDraft({
    String stepId = 'review',
    double currentWeight = 80,
  }) => OnboardingDraft(
    stepId: stepId,
    preferredName: 'Canonical',
    goals: const {OnboardingGoal.loseWeight, OnboardingGoal.improveNutrition},
    activity: 'moderate',
    regularExercise: true,
    birthDate: DateTime(1990, 5, 17),
    sex: 'female',
    countryRegion: 'Egypt',
    localeTag: 'en',
    heightCm: 170,
    currentWeightKg: currentWeight,
    targetWeightKg: 70,
    weeklyPaceKg: .5,
    waistCm: 82,
    neckCm: 34,
    hipsCm: 98,
    remoteAiConsent: OnboardingRemoteAiConsent.declined,
    aiFocuses: const {CoachContextFocus.nutrition},
    estimatesAcknowledged: true,
  );

  Future<void> seedCanonicalData() async {
    final profile = UserProfileRepository(database);
    await profile.save(
      gender: 'female',
      age: 36,
      height: 170,
      currentWeight: 80,
      targetWeight: 70,
      activityLevel: 'moderate',
      exercises: true,
      waist: 82,
      neck: 34,
    );
    await WeightRepository(database).addWeight(
      80,
      date: DateTime(2026, 9, 19),
      measurementContext: 'unspecified',
    );
    await BodyMeasurementRepository(database).saveForDay(
      date: DateTime(2026, 9, 19),
      waistCm: 82,
      neckCm: 34,
      hipsCm: 98,
    );
    await preferences.set('displayName', 'Canonical');
    await preferences.set('countryRegion', 'Egypt');
    await preferences.set('locale', 'en');
    await preferences.set('units', 'metric');
    await preferences.set('profileDateOfBirth', '1990-05-17T00:00:00.000');
    await preferences.set(
      OnboardingGoalBindings.storageKey,
      OnboardingGoalBindings.encode(canonicalDraft().goals),
    );
    await preferences.set(
      CoachContextPreferences.storageKey,
      CoachContextPreferences(focuses: canonicalDraft().aiFocuses).encode(),
    );
    await preferences.set('onboarding.remoteAiConsent', 'declined');
    await preferences.set('onboarding.permission.health', 'granted');
    await preferences.set('onboarding.permission.notifications', 'denied');
  }

  Future<void> mountReview(WidgetTester tester) async {
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
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const OnboardingPage(reviewMode: true),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> mountAiConsent(
    WidgetTester tester,
    _BlockingRemoteAiGateway remote,
  ) async {
    await drafts.save(
      canonicalDraft(
        stepId: 'ai',
      ).copyWith(aiFocuses: const {CoachContextFocus.nutrition}),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          onboardingRemoteAiGatewayProvider.overrideWithValue(remote),
          connectedHealthGatewayProvider.overrideWithValue(
            const _HealthGateway(),
          ),
          onboardingNotificationGatewayProvider.overrideWithValue(
            const _NotificationGateway(),
          ),
        ],
        child: MaterialApp(
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
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> revealAiButton(WidgetTester tester, Key key) async {
    await tester.scrollUntilVisible(
      find.byKey(key),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
  }

  void expectStableContinue(WidgetTester tester) {
    final next = find.byKey(const Key('onboarding-next'));
    expect(next, findsOneWidget);
    final button = tester.widget<FilledButton>(next);
    expect(button.onPressed, isNull);
    expect(
      button.style?.backgroundColor?.resolve(const <WidgetState>{
        WidgetState.disabled,
      }),
      const Color(0xFF1D4ED8),
    );
    expect(
      find.descendant(
        of: next,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: next, matching: find.text('Continue')),
      findsOneWidget,
    );
  }

  testWidgets(
    'Cloud AI enable keeps Continue stable while consent is pending',
    (tester) async {
      final remote = _BlockingRemoteAiGateway();
      await mountAiConsent(tester, remote);

      await revealAiButton(tester, const Key('onboarding-cloud-ai-toggle'));
      await tester.tap(find.byKey(const Key('onboarding-cloud-ai-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding-ai-consent-accept')));
      await tester.pump();

      expect(remote.setGrantedCalls, 1);
      expectStableContinue(tester);

      remote.complete(OnboardingRemoteAiResult.granted);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Cloud AI disable keeps Continue stable while consent is pending',
    (tester) async {
      final remote = _BlockingRemoteAiGateway(initiallyGranted: true);
      await mountAiConsent(tester, remote);

      await revealAiButton(tester, const Key('onboarding-cloud-ai-toggle'));
      await tester.tap(find.byKey(const Key('onboarding-cloud-ai-toggle')));
      await tester.pump();

      expect(remote.setGrantedCalls, 1);
      expectStableContinue(tester);

      remote.complete(OnboardingRemoteAiResult.declined);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'rapid Cloud AI taps send one request and never replace Continue',
    (tester) async {
      final remote = _BlockingRemoteAiGateway();
      await mountAiConsent(tester, remote);

      await revealAiButton(tester, const Key('onboarding-cloud-ai-toggle'));
      await tester.tap(find.byKey(const Key('onboarding-cloud-ai-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding-ai-consent-accept')));
      await tester.tap(
        find.byKey(const Key('onboarding-cloud-ai-toggle')),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(remote.setGrantedCalls, 1);
      expectStableContinue(tester);

      remote.complete(OnboardingRemoteAiResult.granted);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('explicit Review uses canonical data over a stale draft', (
    tester,
  ) async {
    await seedCanonicalData();
    await drafts.save(canonicalDraft().copyWith(preferredName: 'Stale draft'));

    await mountReview(tester);

    final name = tester.widget<TextField>(
      find.byKey(const Key('onboarding-name-field')),
    );
    expect(name.controller!.text, 'Canonical');
    expect((await drafts.load())!.preferredName, 'Stale draft');
  });

  testWidgets('leaving Review without finishing does not write its draft', (
    tester,
  ) async {
    await seedCanonicalData();
    await drafts.save(canonicalDraft().copyWith(preferredName: 'Stale draft'));
    final router = GoRouter(
      initialLocation: '/onboarding?mode=review',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (_, state) => OnboardingPage(
            reviewMode: state.uri.queryParameters['mode'] == 'review',
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, _) => const Scaffold(body: Text('Settings')),
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
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('onboarding-back')));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect((await drafts.load())!.preferredName, 'Stale draft');
    expect(
      (await UserProfileRepository(database).getProfile())!.currentWeight,
      80,
    );
  });

  test(
    'Review finish is idempotent for unchanged weight and measurements',
    () async {
      final service = OnboardingCompletionService(
        database: database,
        profiles: UserProfileRepository(database),
        weights: WeightRepository(database),
        goals: GoalRepository(database),
        measurements: BodyMeasurementRepository(database),
        plans: PlanRepository(database),
        preferences: preferences,
        dietaryPreferences: DietaryPreferencesRepository(preferences),
        drafts: drafts,
      );
      final first = canonicalDraft();
      await service.commit(draft: first, now: DateTime(2026, 9, 19));
      await service.commit(
        draft: first,
        now: DateTime(2026, 9, 20),
        reviewMode: true,
      );

      expect(await WeightRepository(database).getAll(), hasLength(1));
      expect(
        await database.select(database.bodyMeasurementEntries).get(),
        hasLength(1),
      );
      expect(await database.select(database.goals).get(), hasLength(1));
    },
  );

  test('Review finish persists an intentional current-weight edit', () async {
    final service = OnboardingCompletionService(
      database: database,
      profiles: UserProfileRepository(database),
      weights: WeightRepository(database),
      goals: GoalRepository(database),
      measurements: BodyMeasurementRepository(database),
      plans: PlanRepository(database),
      preferences: preferences,
      dietaryPreferences: DietaryPreferencesRepository(preferences),
      drafts: drafts,
    );
    await service.commit(draft: canonicalDraft(), now: DateTime(2026, 9, 19));
    await service.commit(
      draft: canonicalDraft(currentWeight: 79),
      now: DateTime(2026, 9, 20),
      reviewMode: true,
    );

    expect(
      (await UserProfileRepository(database).getProfile())!.currentWeight,
      79,
    );
    expect(await WeightRepository(database).getAll(), hasLength(2));
  });
}

final class _RemoteAiGateway implements OnboardingRemoteAiGateway {
  const _RemoteAiGateway();

  @override
  Future<OnboardingRemoteAiResult> read() async =>
      OnboardingRemoteAiResult.declined;

  @override
  Future<OnboardingRemoteAiResult> setGranted(bool granted) async => granted
      ? OnboardingRemoteAiResult.granted
      : OnboardingRemoteAiResult.declined;
}

final class _BlockingRemoteAiGateway implements OnboardingRemoteAiGateway {
  _BlockingRemoteAiGateway({this.initiallyGranted = false});

  final bool initiallyGranted;
  final Completer<OnboardingRemoteAiResult> _completion = Completer();
  int setGrantedCalls = 0;

  @override
  Future<OnboardingRemoteAiResult> read() async => initiallyGranted
      ? OnboardingRemoteAiResult.granted
      : OnboardingRemoteAiResult.declined;

  @override
  Future<OnboardingRemoteAiResult> setGranted(bool granted) {
    setGrantedCalls += 1;
    return _completion.future;
  }

  void complete(OnboardingRemoteAiResult result) {
    if (!_completion.isCompleted) _completion.complete(result);
  }
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
  Future<ConnectedHealthSnapshot> synchronize() => load();

  @override
  Future<ConnectedHealthSnapshot> requestPermissions() => load();

  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() => load();

  @override
  Future<ConnectedHealthSnapshot> revokePermissions() => load();

  @override
  Future<void> openSystemSettings() async {}
}
