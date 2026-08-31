import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
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

import '../../visual_closure/visual_evidence_font.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadVisualEvidenceFont);

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

  OnboardingDraft valid(String step) => OnboardingDraft(
    stepId: step,
    preferredName: 'Nora',
    goals: const {
      OnboardingGoal.loseWeight,
      OnboardingGoal.improveNutrition,
      OnboardingGoal.sleepRecovery,
    },
    activity: 'moderate',
    regularExercise: true,
    birthDate: DateTime(1990, 5, 17),
    sex: 'female',
    countryRegion: 'Egypt',
    localeTag: 'en',
    heightCm: 170,
    currentWeightKg: 80,
    targetWeightKg: 70,
    weeklyPaceKg: .5,
    waistCm: 82,
    neckCm: 34,
    hipsCm: 98,
    remoteAiConsent: OnboardingRemoteAiConsent.declined,
    aiFocuses: const {CoachContextFocus.nutrition, CoachContextFocus.habits},
  );

  Future<void> render(
    WidgetTester tester, {
    required OnboardingDraft draft,
    required Locale locale,
    required ThemeMode themeMode,
    required double textScale,
    TargetPlatform? platform,
    Size size = const Size(390, 844),
  }) async {
    if (platform != null) debugDefaultTargetPlatformOverride = platform;
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await drafts.save(draft);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('onboarding-golden-boundary'),
        child: ProviderScope(
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
            debugShowCheckedModeBanner: false,
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF315A3A),
              ),
              fontFamily: locale.languageCode == 'ar'
                  ? 'BILArabic'
                  : 'RobotoEvidence',
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF79B984),
                brightness: Brightness.dark,
              ),
              fontFamily: locale.languageCode == 'ar'
                  ? 'BILArabic'
                  : 'RobotoEvidence',
            ),
            themeMode: themeMode,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: const OnboardingPage(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    // Asset decoding happens on a real background isolate. Give it a short
    // real-time window before the deterministic frame pump so a first-use
    // photo cannot be captured as its placeholder while later cached photos
    // appear correctly.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  }

  testWidgets('English LTR small phone light visual', (tester) async {
    await render(
      tester,
      draft: valid('waist').copyWith(waistCm: null),
      locale: const Locale('en'),
      themeMode: ThemeMode.light,
      textScale: 1,
    );
    await expectLater(
      find.byKey(const Key('onboarding-golden-boundary')),
      matchesGoldenFile('goldens/onboarding_2026/en_ltr_small_light.png'),
    );
  });

  testWidgets('Arabic RTL small phone dark visual at 160 percent', (
    tester,
  ) async {
    await render(
      tester,
      draft: valid('waist').copyWith(waistCm: null),
      locale: const Locale('ar'),
      themeMode: ThemeMode.dark,
      textScale: 1.6,
    );
    await expectLater(
      find.byKey(const Key('onboarding-golden-boundary')),
      matchesGoldenFile('goldens/onboarding_2026/ar_rtl_small_dark_160.png'),
    );
  });

  testWidgets('female hip optional page visual', (tester) async {
    await render(
      tester,
      draft: valid('hips').copyWith(hipsCm: null),
      locale: const Locale('en'),
      themeMode: ThemeMode.light,
      textScale: 1.6,
    );
    await expectLater(
      find.byKey(const Key('onboarding-golden-boundary')),
      matchesGoldenFile('goldens/onboarding_2026/female_hip_light_160.png'),
    );
  });

  testWidgets('calculated plan visual in dark mode', (tester) async {
    await render(
      tester,
      draft: valid('plan'),
      locale: const Locale('en'),
      themeMode: ThemeMode.dark,
      textScale: 1.6,
    );
    await expectLater(
      find.byKey(const Key('onboarding-golden-boundary')),
      matchesGoldenFile('goldens/onboarding_2026/plan_dark_160.png'),
    );
  });

  testWidgets('Android final permission choices visual', (tester) async {
    await render(
      tester,
      draft: valid('integrations'),
      locale: const Locale('en'),
      themeMode: ThemeMode.light,
      textScale: 1.6,
      platform: TargetPlatform.android,
    );
    await expectLater(
      find.byKey(const Key('onboarding-golden-boundary')),
      matchesGoldenFile('goldens/onboarding_2026/permissions_light_160.png'),
    );
  });

  testWidgets('English facts on 320 wide phone at 200 percent', (tester) async {
    await render(
      tester,
      draft: valid('facts'),
      locale: const Locale('en'),
      themeMode: ThemeMode.light,
      textScale: 2,
      platform: TargetPlatform.iOS,
      size: const Size(320, 568),
    );
    await expectLater(
      find.byKey(const Key('onboarding-golden-boundary')),
      matchesGoldenFile(
        'goldens/onboarding_2026/facts_320x568_en_light_200.png',
      ),
    );
  });

  testWidgets('height and units photo keeps its focal measurement crop', (
    tester,
  ) async {
    await render(
      tester,
      draft: valid('height'),
      locale: const Locale('en'),
      themeMode: ThemeMode.light,
      textScale: 1,
      platform: TargetPlatform.iOS,
    );
    await expectLater(
      find.byKey(const Key('onboarding-golden-boundary')),
      matchesGoldenFile(
        'goldens/onboarding_2026/height_units_en_light_100.png',
      ),
    );
  });

  testWidgets('Arabic plan on 320 wide phone at 200 percent', (tester) async {
    await render(
      tester,
      draft: valid('plan'),
      locale: const Locale('ar'),
      themeMode: ThemeMode.dark,
      textScale: 2,
      platform: TargetPlatform.android,
      size: const Size(320, 568),
    );
    await expectLater(
      find.byKey(const Key('onboarding-golden-boundary')),
      matchesGoldenFile('goldens/onboarding_2026/plan_320x568_ar_dark_200.png'),
    );
  });

  testWidgets('Arabic AI choices on 430 wide phone', (tester) async {
    await render(
      tester,
      draft: valid('ai'),
      locale: const Locale('ar'),
      themeMode: ThemeMode.light,
      textScale: 1,
      platform: TargetPlatform.iOS,
      size: const Size(430, 932),
    );
    await expectLater(
      find.byKey(const Key('onboarding-golden-boundary')),
      matchesGoldenFile('goldens/onboarding_2026/ai_430x932_ar_light_100.png'),
    );
  });
}

final class _RemoteAiGateway implements OnboardingRemoteAiGateway {
  const _RemoteAiGateway();

  @override
  Future<OnboardingRemoteAiResult> read() async =>
      OnboardingRemoteAiResult.declined;

  @override
  Future<OnboardingRemoteAiResult> setGranted(bool granted) async =>
      OnboardingRemoteAiResult.declined;
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
