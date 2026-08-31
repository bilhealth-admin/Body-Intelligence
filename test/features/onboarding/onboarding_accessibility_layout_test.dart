import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_preferences.dart';
import 'package:body_intelligence_log/features/onboarding/models/onboarding_draft.dart';
import 'package:body_intelligence_log/features/onboarding/onboarding_page.dart';
import 'package:body_intelligence_log/features/onboarding/onboarding_runtime_copy.dart';
import 'package:body_intelligence_log/features/onboarding/services/onboarding_permission_gateways.dart';
import 'package:body_intelligence_log/shared/widgets/bil_coach_identity.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

  OnboardingDraft valid({required String step, String sex = 'female'}) =>
      OnboardingDraft(
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
        sex: sex,
        countryRegion: 'Egypt',
        localeTag: 'en',
        heightCm: 170,
        currentWeightKg: 80,
        targetWeightKg: 70,
        weeklyPaceKg: .5,
        waistCm: 82,
        neckCm: 34,
        hipsCm: sex == 'female' ? 98 : null,
        remoteAiConsent: OnboardingRemoteAiConsent.declined,
        aiFocuses: const {
          CoachContextFocus.nutrition,
          CoachContextFocus.habits,
        },
        estimatesAcknowledged: true,
      );

  Future<void> render(
    WidgetTester tester, {
    required OnboardingDraft draft,
    required Size size,
    required Locale locale,
    required ThemeMode themeMode,
    required double textScale,
    required TargetPlatform platform,
    EdgeInsets padding = EdgeInsets.zero,
    EdgeInsets viewInsets = EdgeInsets.zero,
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await drafts.save(draft);
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
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF79B984),
              brightness: Brightness.dark,
            ),
          ),
          themeMode: themeMode,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: padding,
              viewPadding: padding,
              viewInsets: viewInsets,
              textScaler: TextScaler.linear(textScale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: const OnboardingPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    debugDefaultTargetPlatformOverride = null;
  }

  final matrix =
      <
        ({
          String name,
          String step,
          String sex,
          Size size,
          Locale locale,
          ThemeMode theme,
          double scale,
          TargetPlatform platform,
        })
      >[
        (
          name: '320 en light 200 facts iOS',
          step: 'facts',
          sex: 'female',
          size: const Size(320, 568),
          locale: const Locale('en'),
          theme: ThemeMode.light,
          scale: 2,
          platform: TargetPlatform.iOS,
        ),
        (
          name: '320 ar dark 200 plan Android',
          step: 'plan',
          sex: 'male',
          size: const Size(320, 568),
          locale: const Locale('ar'),
          theme: ThemeMode.dark,
          scale: 2,
          platform: TargetPlatform.android,
        ),
        (
          name: '390 en dark 160 integrations Android',
          step: 'integrations',
          sex: 'female',
          size: const Size(390, 844),
          locale: const Locale('en'),
          theme: ThemeMode.dark,
          scale: 1.6,
          platform: TargetPlatform.android,
        ),
        (
          name: '390 ar light 100 goals iOS',
          step: 'goals',
          sex: 'male',
          size: const Size(390, 844),
          locale: const Locale('ar'),
          theme: ThemeMode.light,
          scale: 1,
          platform: TargetPlatform.iOS,
        ),
        (
          name: '430 en light 100 AI iOS',
          step: 'ai',
          sex: 'female',
          size: const Size(430, 932),
          locale: const Locale('en'),
          theme: ThemeMode.light,
          scale: 1,
          platform: TargetPlatform.iOS,
        ),
        (
          name: '430 ar dark 160 hip Android',
          step: 'hips',
          sex: 'female',
          size: const Size(430, 932),
          locale: const Locale('ar'),
          theme: ThemeMode.dark,
          scale: 1.6,
          platform: TargetPlatform.android,
        ),
      ];

  for (final scenario in matrix) {
    testWidgets('${scenario.name} has no clipping or overflow', (tester) async {
      await render(
        tester,
        draft: valid(step: scenario.step, sex: scenario.sex),
        size: scenario.size,
        locale: scenario.locale,
        themeMode: scenario.theme,
        textScale: scenario.scale,
        platform: scenario.platform,
      );

      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(find.byKey(const Key('onboarding-step-title')), findsOneWidget);
      expect(find.byKey(const Key('onboarding-next')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  final cartesianSizes = <Size>[
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
  ];
  const cartesianScales = <double>[1, 1.6, 2];
  const cartesianLocales = <Locale>[Locale('en'), Locale('ar')];
  const cartesianThemes = <ThemeMode>[ThemeMode.light, ThemeMode.dark];
  const criticalSteps = <String>[
    'facts',
    'plan',
    'integrations',
    'ai',
    'review',
    'waist',
  ];
  var cartesianIndex = 0;
  for (final size in cartesianSizes) {
    for (final scale in cartesianScales) {
      for (final locale in cartesianLocales) {
        for (final theme in cartesianThemes) {
          final caseIndex = cartesianIndex++;
          final step = criticalSteps[caseIndex % criticalSteps.length];
          final platform = caseIndex.isEven
              ? TargetPlatform.iOS
              : TargetPlatform.android;
          testWidgets('cartesian ${size.width.toInt()}x${size.height.toInt()} '
              '${locale.languageCode} ${theme.name} ${scale}x $step', (
            tester,
          ) async {
            await render(
              tester,
              draft: valid(step: step),
              size: size,
              locale: locale,
              themeMode: theme,
              textScale: scale,
              platform: platform,
            );

            final footer = tester.getRect(
              find.byKey(const Key('onboarding-next')),
            );
            expect(footer.top, greaterThanOrEqualTo(0));
            expect(footer.bottom, lessThanOrEqualTo(size.height));
            expect(find.byType(SingleChildScrollView), findsOneWidget);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }
  assert(cartesianIndex == 36);

  const photoSteps = <String>[
    'name',
    'goals',
    'activity',
    'facts',
    'units',
    'height',
    'currentWeight',
    'targetWeight',
    'pace',
    'waist',
    'neck',
    'hips',
    'plan',
    'integrations',
    'ai',
    'review',
  ];
  const expectedPhotoAssets = <String, String>{
    'name':
        'assets/images/onboarding_2026/bil_onboarding_welcome_photo_v1.webp',
    'goals':
        'assets/images/onboarding_2026/bil_onboarding_goals_activity_photo_v1.webp',
    'activity':
        'assets/images/onboarding_2026/bil_onboarding_goals_activity_photo_v1.webp',
    'facts':
        'assets/images/onboarding_2026/bil_onboarding_body_facts_photo_v1.webp',
    'units':
        'assets/images/onboarding_2026/bil_onboarding_height_units_photo_v1.webp',
    'height':
        'assets/images/onboarding_2026/bil_onboarding_height_units_photo_v1.webp',
    'currentWeight':
        'assets/images/onboarding_2026/bil_onboarding_weight_photo_v1.webp',
    'targetWeight':
        'assets/images/onboarding_2026/bil_onboarding_weight_photo_v1.webp',
    'pace':
        'assets/images/onboarding_2026/bil_onboarding_goals_activity_photo_v1.webp',
    'waist': 'assets/images/onboarding_2026/bil_onboarding_waist_photo_v1.webp',
    'neck': 'assets/images/onboarding_2026/bil_onboarding_neck_photo_v1.webp',
    'hips': 'assets/images/onboarding_2026/bil_onboarding_hips_photo_v1.webp',
    'plan':
        'assets/images/onboarding_2026/bil_onboarding_meal_quick_add_photo_v1.webp',
    'integrations':
        'assets/images/onboarding_2026/bil_onboarding_connected_ai_photo_v1.webp',
    'ai': bilApprovedAiCoachAsset,
    'review':
        'assets/images/onboarding_2026/bil_onboarding_ready_photo_v1.webp',
  };
  var photoMatrixCount = 0;
  for (final step in photoSteps) {
    for (final size in cartesianSizes) {
      for (final locale in cartesianLocales) {
        for (final theme in cartesianThemes) {
          photoMatrixCount++;
          testWidgets(
            'photo matrix $step ${size.width.toInt()}x${size.height.toInt()} '
            '${locale.languageCode} ${theme.name} 2.0x',
            (tester) async {
              await render(
                tester,
                draft: valid(step: step),
                size: size,
                locale: locale,
                themeMode: theme,
                textScale: 2,
                platform: TargetPlatform.iOS,
              );

              final photo = find.byKey(Key('onboarding-photo-$step'));
              expect(photo, findsOneWidget);
              expect(tester.getSize(photo).height, 80);
              final image = tester.widget<Image>(
                find.descendant(of: photo, matching: find.byType(Image)).first,
              );
              expect(image.fit, BoxFit.contain);
              expect(
                (image.image as AssetImage).assetName,
                expectedPhotoAssets[step],
              );
              final excluded = tester.widget<ExcludeSemantics>(
                find
                    .descendant(
                      of: photo,
                      matching: find.byType(ExcludeSemantics),
                    )
                    .first,
              );
              expect(excluded.excluding, isTrue);
              expect(
                find.byKey(const Key('onboarding-wordmark')),
                findsOneWidget,
              );
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }
  assert(photoMatrixCount == 192);

  test('release onboarding matrix enumerates all 25 locales', () {
    expect(AppLocalizations.supportedLocales, hasLength(25));
  });

  for (
    var localeIndex = 0;
    localeIndex < AppLocalizations.supportedLocales.length;
    localeIndex++
  ) {
    final locale = AppLocalizations.supportedLocales[localeIndex];
    testWidgets(
      '25-locale full onboarding matrix ${locale.toLanguageTag()}',
      (tester) async {
        var rendered = 0;
        for (var stepIndex = 0; stepIndex < photoSteps.length; stepIndex++) {
          final step = photoSteps[stepIndex];
          for (var scaleIndex = 0; scaleIndex < 2; scaleIndex++) {
            final scale = scaleIndex == 0 ? 1.0 : 2.0;
            final dark = (localeIndex + stepIndex + scaleIndex).isOdd;
            await render(
              tester,
              draft: valid(
                step: step,
                sex: step == 'hips' || localeIndex.isOdd ? 'female' : 'male',
              ),
              size: const Size(390, 844),
              locale: locale,
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              textScale: scale,
              platform: (localeIndex + stepIndex).isEven
                  ? TargetPlatform.iOS
                  : TargetPlatform.android,
            );
            rendered++;

            expect(
              find.byKey(const Key('onboarding-step-title')),
              findsOneWidget,
              reason: '${locale.toLanguageTag()} $step ${scale}x title',
            );
            expect(
              find.byKey(Key('onboarding-photo-$step')),
              findsOneWidget,
              reason: '${locale.toLanguageTag()} $step ${scale}x photo',
            );
            final footer = tester.getRect(
              find.byKey(const Key('onboarding-next')),
            );
            expect(
              footer.top,
              greaterThanOrEqualTo(0),
              reason: '${locale.toLanguageTag()} $step ${scale}x footer top',
            );
            expect(
              footer.bottom,
              lessThanOrEqualTo(844),
              reason: '${locale.toLanguageTag()} $step ${scale}x footer bottom',
            );

            // Detect an actual runtime fallback, not invariant terms such as
            // BIL, AI Coach, Apple Health, units, or numeric values. A source
            // phrase is forbidden only when this locale has a distinct value.
            if (locale.languageCode != 'en') {
              final fallbackCandidates = OnboardingRuntimeCopy.englishKeys
                  .where(
                    (source) =>
                        OnboardingRuntimeCopy.resolve(source, locale) != source,
                  )
                  .toSet();
              final visibleText = tester
                  .widgetList<Text>(find.byType(Text))
                  .map((widget) => widget.data)
                  .whereType<String>();
              for (final value in visibleText) {
                expect(
                  fallbackCandidates.any(
                    (source) =>
                        value == source ||
                        (source.length >= 12 && value.contains(source)),
                  ),
                  isFalse,
                  reason:
                      '${locale.toLanguageTag()} $step ${scale}x English fallback: $value',
                );
              }
            }
            expect(
              tester.takeException(),
              isNull,
              reason: '${locale.toLanguageTag()} $step ${scale}x',
            );
          }
        }
        expect(rendered, 32);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }

  testWidgets('safe areas and a visible keyboard keep the footer reachable', (
    tester,
  ) async {
    await render(
      tester,
      draft: valid(step: 'name'),
      size: const Size(320, 568),
      locale: const Locale('en'),
      themeMode: ThemeMode.light,
      textScale: 2,
      platform: TargetPlatform.iOS,
      padding: const EdgeInsets.only(top: 24, bottom: 34),
      viewInsets: const EdgeInsets.only(bottom: 250),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byKey(const Key('onboarding-back')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-next')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('footer controls meet 44 point targets and semantics are exact', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await render(
      tester,
      draft: valid(step: 'waist'),
      size: const Size(320, 568),
      locale: const Locale('en'),
      themeMode: ThemeMode.light,
      textScale: 2,
      platform: TargetPlatform.iOS,
    );

    for (final key in const [
      Key('onboarding-back'),
      Key('onboarding-skip'),
      Key('onboarding-next'),
    ]) {
      final size = tester.getSize(find.byKey(key));
      expect(size.width, greaterThanOrEqualTo(44), reason: '$key width');
      expect(size.height, greaterThanOrEqualTo(44), reason: '$key height');
    }
    final progress = find.byKey(const Key('onboarding-progress-semantics'));
    expect(tester.getSemantics(progress).label, isNotEmpty);
    expect(tester.getSemantics(progress).value, '10 / 16');
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('keyboard focus moves from page input to Back then Continue', (
    tester,
  ) async {
    await render(
      tester,
      draft: valid(step: 'name'),
      size: const Size(390, 844),
      locale: const Locale('en'),
      themeMode: ThemeMode.light,
      textScale: 1,
      platform: TargetPlatform.iOS,
    );

    await tester.tap(find.byKey(const Key('onboarding-name-field')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    var focusedButton = FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<IconButton>();
    expect(focusedButton?.key, const Key('onboarding-back'));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focusedFilled = FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<FilledButton>();
    expect(focusedFilled?.key, const Key('onboarding-next'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'black canonical wordmark keeps a white identity surface in RTL',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await render(
        tester,
        draft: valid(step: 'facts'),
        size: const Size(320, 568),
        locale: const Locale('ar'),
        themeMode: ThemeMode.dark,
        textScale: 2,
        platform: TargetPlatform.iOS,
      );

      final wordmark = find.byKey(const Key('onboarding-wordmark'));
      expect(wordmark, findsOneWidget);
      expect(
        tester.getSemantics(wordmark).label,
        contains('Body Intelligence Log'),
      );
      expect(tester.getRect(wordmark).left, greaterThanOrEqualTo(0));
      expect(tester.getRect(wordmark).right, lessThanOrEqualTo(320));
      final brandText = tester.widget<Text>(
        find.descendant(
          of: wordmark,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.data?.toUpperCase() == 'BODY INTELLIGENCE LOG',
          ),
        ),
      );
      expect(brandText.style?.color, const Color(0xFF050505));
      final identity = tester.widget<DecoratedBox>(
        find.byKey(const Key('onboarding-identity-surface')),
      );
      expect(
        (identity.decoration as BoxDecoration).color,
        const Color(0xFFFEFEFF),
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('progress truthfully reports 15 male and 16 female pages', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await render(
      tester,
      draft: valid(step: 'review', sex: 'male'),
      size: const Size(390, 844),
      locale: const Locale('en'),
      themeMode: ThemeMode.light,
      textScale: 1,
      platform: TargetPlatform.android,
    );
    var progress = find.byKey(const Key('onboarding-progress-semantics'));
    expect(tester.getSemantics(progress).value, '15 / 15');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await render(
      tester,
      draft: valid(step: 'review'),
      size: const Size(390, 844),
      locale: const Locale('en'),
      themeMode: ThemeMode.light,
      textScale: 1,
      platform: TargetPlatform.iOS,
    );
    progress = find.byKey(const Key('onboarding-progress-semantics'));
    expect(tester.getSemantics(progress).value, '16 / 16');
    semantics.dispose();
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
