import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
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
import 'package:body_intelligence_log/features/onboarding/onboarding_runtime_copy.dart';
import 'package:body_intelligence_log/features/onboarding/services/onboarding_permission_gateways.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../visual_closure/visual_evidence_font.dart';

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
    ThemeData? theme,
    double? textScale,
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
          theme: theme,
          builder: (context, child) => textScale == null
              ? child!
              : MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!,
                ),
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
    ThemeData? theme,
    double? textScale,
  }) async {
    await drafts.save(draft);
    await mount(
      tester,
      locale: locale,
      remote: remote,
      health: health,
      theme: theme,
      textScale: textScale,
    );
  }

  Future<void> mountRouted(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('Sign in')),
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

  testWidgets('one kilogram option is visible and saved below 100 kilograms', (
    tester,
  ) async {
    await pump(tester, valid(step: 'pace'));
    final choice = find.text('1 kg / 7d');
    await tester.ensureVisible(choice);
    await tester.tap(choice);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect((await drafts.load())!.weeklyPaceKg, 1);
    expect((await drafts.load())!.stepId, 'waist');
  });

  testWidgets('iOS onboarding omits the optional health permission stage', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await pump(tester, valid(step: 'integrations'));
    expect(find.byKey(const Key('onboarding-health-permission')), findsNothing);
    expect(find.text('Apple Health'), findsNothing);
    expect(find.byKey(const Key('onboarding-step-title')), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('one kilogram is hidden when it would breach the calorie floor', (
    tester,
  ) async {
    await pump(
      tester,
      valid(step: 'pace').copyWith(
        currentWeightKg: 55,
        targetWeightKg: 50,
        activity: 'sedentary',
      ),
    );
    expect(find.text('1 kg / 7d'), findsNothing);
    expect(find.text('BIL could not calculate a safe plan.'), findsNothing);
    expect((await drafts.load())!.stepId, 'pace');
  });

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

  Future<void> pumpValidation(
    WidgetTester tester,
    OnboardingDraft draft,
    Locale locale,
    double scale, {
    Size size = const Size(320, 640),
  }) async {
    await tester.runAsync(loadVisualEvidenceFont);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    await tester.binding.setSurfaceSize(size);
    addTearDown(() async {
      tester.view.reset();
      await tester.binding.setSurfaceSize(null);
    });
    await pump(
      tester,
      draft,
      locale: locale,
      textScale: scale,
      theme: BilFlagshipTheme.light(isArabic: locale.languageCode == 'ar'),
    );
  }

  String validationCopy(String text, Locale locale) =>
      OnboardingRuntimeCopy.resolve(text, locale);

  Future<void> expectVisibleValidation(
    WidgetTester tester,
    String message,
    double scale,
  ) async {
    final text = find.text(message);
    final feedback = find.byKey(const Key('onboarding-validation-feedback'));
    expect(text, findsOneWidget);
    expect(feedback, findsOneWidget);
    expect(feedback.hitTestable(), findsOneWidget);
    final visible = tester.getRect(feedback);
    final paragraph = tester.getRect(text);
    expect(paragraph.left, greaterThanOrEqualTo(visible.left));
    expect(paragraph.right, lessThanOrEqualTo(visible.right));
    expect(paragraph.top, greaterThanOrEqualTo(visible.top));
    // At 320dp / 2.5x, the complete adult-age message is taller than all
    // remaining space above the footer. Its first line must be visible on
    // Submit, and its final line must be reachable without moving the form.
    Rect glyph(int offset) {
      final render = tester.renderObject<RenderParagraph>(text);
      final box = render
          .getBoxesForSelection(
            TextSelection(baseOffset: offset, extentOffset: offset + 1),
          )
          .first;
      return box.toRect().shift(render.localToGlobal(Offset.zero));
    }

    expect(glyph(0).bottom, lessThanOrEqualTo(visible.bottom));
    if (paragraph.bottom > visible.bottom) {
      final scroll = tester.widget<SingleChildScrollView>(feedback);
      expect(scroll.primary, isFalse);
      expect(scroll.controller!.position.maxScrollExtent, greaterThan(0));
      expect(
        find.ancestor(of: feedback, matching: find.byType(Scrollbar)),
        findsOneWidget,
      );
      await tester.drag(
        feedback,
        Offset(0, visible.bottom - paragraph.bottom - 24),
      );
      await tester.pumpAndSettle();
      final last = glyph(message.length - 1);
      expect(last.top, greaterThanOrEqualTo(visible.top));
      expect(last.bottom, lessThanOrEqualTo(visible.bottom));
    } else {
      expect(paragraph.bottom, lessThanOrEqualTo(visible.bottom));
    }
    expect(
      visible.bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const Key('onboarding-footer'))).top,
      ),
    );
    expect(
      find.byKey(const Key('onboarding-next')).hitTestable(),
      findsOneWidget,
    );
    expect(
      MediaQuery.textScalerOf(tester.element(text)).scale(16),
      closeTo(16 * scale, .01),
    );
  }

  for (final locale in const [Locale('en'), Locale('ar')]) {
    final scale = locale.languageCode == 'ar' ? 2.5 : 1.0;
    testWidgets(
      'validation feedback reveals required sex without scroll $locale',
      (tester) async {
        await pumpValidation(
          tester,
          valid(step: 'facts').copyWith(sex: null, countryRegion: ''),
          locale,
          scale,
        );
        expect(
          find.byKey(const Key('onboarding-validation-feedback')),
          findsNothing,
        );
        await tester.tap(find.byKey(const Key('onboarding-next')));
        await tester.pumpAndSettle();
        // No ensureVisible/drag/re-entry occurs between Submit and this assertion.
        await expectVisibleValidation(
          tester,
          validationCopy(
            'Choose the sex used by the calorie equation.',
            locale,
          ),
          scale,
        );
        final male = find.text(validationCopy('Male', locale));
        await tester.ensureVisible(male);
        await tester.tap(male);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('onboarding-validation-feedback')),
          findsNothing,
        );
        await tester.tap(find.byKey(const Key('onboarding-next')));
        await tester.pumpAndSettle();
        expect(
          find.text(validationCopy('Choose your units', locale)),
          findsOneWidget,
        );
        expect((await drafts.load())!.countryRegion, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'validation feedback reveals missing DOB at Arabic 2.5 then corrects',
    (tester) async {
      const locale = Locale('ar');
      await pumpValidation(
        tester,
        valid(step: 'facts').copyWith(birthDate: null, countryRegion: ''),
        locale,
        2.5,
      );
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      await expectVisibleValidation(
        tester,
        validationCopy(
          'BIL is available only to adults aged 18 or older.',
          locale,
        ),
        2.5,
      );
      final birth = find.byKey(const Key('onboarding-birth-date'));
      await tester.ensureVisible(birth);
      final localizations = MaterialLocalizations.of(tester.element(birth));
      expect(tester.takeException(), isNull, reason: 'before date picker');
      await tester.tap(birth);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'date picker at Arabic 2.5',
      );
      // The existing normal picker defaults to an eligible adult date.
      final confirm = find.text(localizations.okButtonLabel).last;
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('onboarding-validation-feedback')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      expect(
        find.text(validationCopy('Choose your units', locale)),
        findsOneWidget,
      );
      expect((await drafts.load())!.birthDate, isNotNull);
      expect((await drafts.load())!.countryRegion, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'validation feedback stays visible above keyboard at Arabic 2.5',
    (tester) async {
      const locale = Locale('ar');
      const size = Size(320, 800);
      await pumpValidation(
        tester,
        valid(step: 'height').copyWith(heightCm: 90),
        locale,
        2.5,
        size: size,
      );
      final field = find.byKey(const Key('onboarding-height'));
      await tester.ensureVisible(field);
      await tester.showKeyboard(field);
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      await expectVisibleValidation(
        tester,
        validationCopy('Review this information before continuing.', locale),
        2.5,
      );
      expect(
        tester.getRect(find.byKey(const Key('onboarding-footer'))).bottom,
        lessThanOrEqualTo(size.height - 240),
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, '170');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('onboarding-validation-feedback')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      expect(
        find.text(validationCopy('What is your current weight?', locale)),
        findsOneWidget,
      );
      expect((await drafts.load())!.heightCm, 170);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'optional country can be skipped and a selected country can be cleared',
    (tester) async {
      await pump(tester, valid(step: 'facts').copyWith(countryRegion: ''));
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      expect(find.text('Choose your units'), findsOneWidget);
      expect((await drafts.load())!.countryRegion, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());

      await pump(tester, valid(step: 'facts'));
      final clear = find.byKey(const Key('onboarding-country-clear'));
      await tester.ensureVisible(clear);
      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('onboarding-country')))
            .controller!
            .text,
        isEmpty,
      );
      expect((await drafts.load())!.countryRegion, isEmpty);
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      expect(find.text('Choose your units'), findsOneWidget);
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

  testWidgets('first-page Back preserves a legacy name and leaves onboarding', (
    tester,
  ) async {
    await drafts.save(valid(step: 'name').copyWith(preferredName: 'Ada'));
    await mountRouted(tester);

    expect(find.byKey(const Key('onboarding-name-field')), findsNothing);
    expect(find.text('What would you like to work on?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-back')));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    final saved = await drafts.load();
    expect(saved?.stepId, 'goals');
    expect(saved?.preferredName, 'Ada');
  });

  testWidgets(
    'legacy name step resumes at goals without showing a name field',
    (tester) async {
      await drafts.save(
        const OnboardingDraft(
          stepId: 'name',
          preferredName: 'Mohamed',
          goals: <OnboardingGoal>{},
        ),
      );
      await mount(tester);

      expect(find.byKey(const Key('onboarding-name-field')), findsNothing);
      expect(find.text('What would you like to work on?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();

      expect(find.text('Choose at least one goal.'), findsOneWidget);
    },
  );

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

    final acknowledgement = find.byKey(const Key('onboarding-estimates-ack'));
    await tester.ensureVisible(acknowledgement);
    await tester.pump();
    await tester.tap(acknowledgement);
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
      await tester.ensureVisible(find.text('Male'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Male'));
      await tester.pumpAndSettle();
      final male = (await drafts.load())!;
      expect(male.sex, 'male');
      expect(male.hipsCm, isNull);

      await tester.ensureVisible(find.text('Female'));
      await tester.pumpAndSettle();
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
    expect(find.byKey(const Key('onboarding-health-permission')), findsNothing);
    expect(find.text('Apple Health'), findsNothing);
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
    final enable = find.byKey(const Key('onboarding-cloud-ai-toggle'));
    await tester.ensureVisible(enable);
    await tester.pumpAndSettle();
    await tester.tap(enable);
    await tester.pumpAndSettle();
    final accept = find.byKey(const Key('onboarding-ai-consent-accept'));
    await tester.ensureVisible(accept);
    await tester.pumpAndSettle();
    expect(accept.hitTestable(), findsOneWidget);
    await tester.tap(accept);
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

  testWidgets('explicit cloud AI opt-out is visible and selected', (
    tester,
  ) async {
    await pump(
      tester,
      valid(
        step: 'ai',
      ).copyWith(remoteAiConsent: OnboardingRemoteAiConsent.granted),
      remote: const _RemoteAiGateway(
        readResult: OnboardingRemoteAiResult.granted,
        setResult: OnboardingRemoteAiResult.declined,
      ),
    );
    final decline = find.byKey(const Key('onboarding-cloud-ai-toggle'));
    await tester.ensureVisible(decline);
    final topBefore = tester.getRect(decline).top;
    expect(find.byKey(const Key('onboarding-enable-ai')), findsNothing);
    expect(find.byKey(const Key('onboarding-decline-ai')), findsNothing);
    await tester.tap(decline);
    await tester.pumpAndSettle();

    expect(find.text('Cloud AI is off.'), findsOneWidget);
    expect(
      (await drafts.load())!.remoteAiConsent,
      OnboardingRemoteAiConsent.declined,
    );
    expect(find.text('Cloud AI is off.'), findsOneWidget);
    expect(tester.getRect(decline).top, closeTo(topBefore, 0.1));
  });

  testWidgets('cloud AI opt-out stays local when consent RPC fails', (
    tester,
  ) async {
    await pump(
      tester,
      valid(
        step: 'ai',
      ).copyWith(remoteAiConsent: OnboardingRemoteAiConsent.granted),
      remote: const _RemoteAiGateway(
        readResult: OnboardingRemoteAiResult.granted,
        setResult: OnboardingRemoteAiResult.failed,
      ),
    );
    final decline = find.byKey(const Key('onboarding-cloud-ai-toggle'));
    await tester.ensureVisible(decline);
    await tester.tap(decline);
    await tester.pumpAndSettle();
    expect(
      (await drafts.load())!.remoteAiConsent,
      OnboardingRemoteAiConsent.declined,
    );
    expect(find.textContaining('AI remains off'), findsOneWidget);
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
  const _RemoteAiGateway({
    this.result = OnboardingRemoteAiResult.declined,
    this.readResult,
    this.setResult,
  });
  final OnboardingRemoteAiResult result;
  final OnboardingRemoteAiResult? readResult;
  final OnboardingRemoteAiResult? setResult;

  @override
  Future<OnboardingRemoteAiResult> read() async => readResult ?? result;

  @override
  Future<OnboardingRemoteAiResult> setGranted(bool granted) async =>
      setResult ?? result;
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
