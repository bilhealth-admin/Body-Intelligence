import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:body_intelligence_log/features/wellness/presentation/bil_workout_routines_page.dart';
import 'package:body_intelligence_log/features/wellness/services/wellness_media_cache.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'verified routine supports details, truthful video state, logging, and saving',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1050));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final logged = <String>[];

      await tester.pumpWidget(
        _TestApp(
          child: BilWorkoutRoutinesPage(
            loader: (_) async => [_verifiedWorkout],
            onLogWorkout: (item) async => logged.add(item.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('My Routines'), findsOneWidget);
      expect(find.text('Foundation strength'), findsOneWidget);
      expect(find.text('25 min'), findsOneWidget);
      expect(find.text('Dumbbells • Mat'), findsOneWidget);
      expect(find.text('Licensed video'), findsNothing);
      expect(find.text('Verified'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('workout-card-strength-01')));
      await tester.pumpAndSettle();

      expect(find.text('No licensed video in this pack'), findsOneWidget);
      expect(find.text('Workout steps'), findsOneWidget);
      expect(find.text('Brace your core.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('details-save-routine')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('log-workout-cta')));
      await tester.pumpAndSettle();
      expect(logged, ['strength-01']);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Routines'));
      await tester.pumpAndSettle();

      expect(find.text('Foundation strength'), findsOneWidget);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getStringList('bil.saved_workout_routine_ids.v1'), [
        'strength-01',
      ]);
    },
  );

  testWidgets('custom routine saves two movements and survives rebuild', (
    tester,
  ) async {
    Future<void> pumpPage() => tester.pumpWidget(
      _TestApp(
        child: BilWorkoutRoutinesPage(
          loader: (_) async => [_verifiedWorkout, _secondVerifiedWorkout],
        ),
      ),
    );

    await pumpPage();
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Routines'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('build-custom-routine')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Routine name'),
      'Balanced foundations',
    );
    await tester.tap(
      find.widgetWithText(CheckboxListTile, 'Foundation strength'),
    );
    await tester.tap(
      find.widgetWithText(CheckboxListTile, 'Foundation mobility'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save').last);
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getStringList('bil.custom_workout_routines.v1');
    expect(stored, hasLength(1));
    final record = jsonDecode(stored!.single) as Map<String, dynamic>;
    expect(record['name'], 'Balanced foundations');
    expect(record['itemIds'], ['strength-01', 'mobility-01']);

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpPage();
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Routines'));
    await tester.pumpAndSettle();
    expect(find.text('Balanced foundations'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('failed custom routine write keeps builder input for retry', (
    tester,
  ) async {
    var writes = 0;
    await tester.pumpWidget(
      _TestApp(
        child: BilWorkoutRoutinesPage(
          loader: (_) async => [_verifiedWorkout],
          customRoutineWriter: (_) async {
            writes++;
            return false;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Routines'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('build-custom-routine')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Routine name'),
      'Keep this draft',
    );
    await tester.tap(
      find.widgetWithText(CheckboxListTile, 'Foundation strength'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save').last);
    await tester.pumpAndSettle();

    expect(writes, 1);
    expect(find.text('Keep this draft'), findsOneWidget);
    expect(find.text('Build routine'), findsWidgets);
    expect(
      find.text('The routine could not be saved. Try again.'),
      findsWidgets,
    );
  });

  testWidgets('malformed and duplicate stored custom routines fail closed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'bil.custom_workout_routines.v1': <String>[
        jsonEncode({
          'id': 'custom-valid',
          'name': 'Valid routine',
          'description': '',
          'itemIds': ['strength-01'],
        }),
        jsonEncode({
          'id': 'custom-valid',
          'name': 'Duplicate id',
          'description': '',
          'itemIds': ['strength-01'],
        }),
        jsonEncode({
          'id': '',
          'name': 'Blank id',
          'description': '',
          'itemIds': ['strength-01'],
        }),
        jsonEncode({
          'id': 'custom-duplicate-movement',
          'name': 'Duplicate movements',
          'description': '',
          'itemIds': ['strength-01', 'strength-01'],
        }),
      ],
    });
    await tester.pumpWidget(
      _TestApp(
        child: BilWorkoutRoutinesPage(loader: (_) async => [_verifiedWorkout]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Routines'));
    await tester.pumpAndSettle();
    expect(find.text('Valid routine'), findsOneWidget);
    expect(find.text('Duplicate id'), findsNothing);
    expect(find.text('Blank id'), findsNothing);
    expect(find.text('Duplicate movements'), findsNothing);
  });

  testWidgets('empty library offers honest non-playable metadata covers', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _TestApp(
        locale: const Locale('ar'),
        themeMode: ThemeMode.dark,
        child: BilWorkoutRoutinesPage(
          offline: true,
          loader: (_) async => const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('workout-metadata-preview-cardio')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('workout-metadata-preview-strength')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    expect(
      find.byKey(const ValueKey('workout-preview-manage-packs')),
      findsOneWidget,
    );
    expect(
      Directionality.of(
        tester.element(
          find.byKey(const ValueKey('workout-metadata-preview-cardio')),
        ),
      ),
      TextDirection.rtl,
    );
  });

  testWidgets('default logger preserves today and records trusted provenance', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DailyLogRepository(database);
    final today = DateTime.now();
    await repository.save(
      date: today,
      notes: 'keep this note',
      exerciseNotes: '{"kind":"manual","title":"Walk"}',
    );

    await tester.pumpWidget(
      _TestApp(
        database: database,
        child: BilWorkoutRoutinesPage(loader: (_) async => [_verifiedWorkout]),
      ),
    );
    await tester.pumpAndSettle();
    final workoutCard = find.byKey(const ValueKey('workout-card-strength-01'));
    await tester.ensureVisible(workoutCard);
    await tester.pumpAndSettle();
    await tester.tap(workoutCard);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('log-workout-cta')));
    await tester.pumpAndSettle();

    final saved = await repository.getForDay(today);
    expect(saved?.notes, 'keep this note');
    final lines = saved!.exerciseNotes!.split('\n');
    expect(lines, hasLength(2));
    final routine = jsonDecode(lines.last) as Map<String, dynamic>;
    expect(routine['kind'], 'trusted_workout_routine');
    expect(routine['id'], 'strength-01');
    expect(routine['title'], 'Foundation strength');
    expect(routine['durationMinutes'], 25);
    expect(routine['source'], 'https://bilhealth.com/workouts/strength-01');
    expect(routine['recordedAt'], isA<String>());
    expect(routine, isNot(contains('calories')));
  });

  testWidgets(
    'paid routine stays locked and never reveals instructions without verified access',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final mediaCache = _RecordingMediaCache();
      addTearDown(mediaCache.dispose);

      await tester.pumpWidget(
        _TestApp(
          child: BilWorkoutRoutinesPage(
            loader: (_) async => [_paidWorkout],
            mediaCache: mediaCache,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('locked-workout-badge')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('workout-card-pro-01')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('unlock-workout-cta')), findsOneWidget);
      expect(find.byKey(const ValueKey('log-workout-cta')), findsNothing);
      expect(find.text('PRIVATE INSTRUCTION MUST STAY HIDDEN'), findsNothing);
      expect(find.text('Unlock this verified routine'), findsOneWidget);
      expect(
        mediaCache.resolutions,
        0,
        reason: 'Locked paid media must not be resolved from cache or network.',
      );
    },
  );

  testWidgets(
    'open paid details relock immediately when verified access is revoked',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var entitlement = _verifiedPaidState(CommercePlan.pro);
      late BuildContext providerContext;
      final mediaCache = _RecordingMediaCache();
      addTearDown(mediaCache.dispose);

      await tester.pumpWidget(
        _TestApp(
          entitlementLoader: () async => entitlement,
          child: Builder(
            builder: (context) {
              providerContext = context;
              return BilWorkoutRoutinesPage(
                loader: (_) async => [_paidWorkout],
                mediaCache: mediaCache,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('locked-workout-badge')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('workout-card-pro-01')));
      await tester.pumpAndSettle();
      expect(find.text('PRIVATE INSTRUCTION MUST STAY HIDDEN'), findsOneWidget);
      expect(find.byKey(const ValueKey('log-workout-cta')), findsOneWidget);

      entitlement = FreePlan.createState();
      ProviderScope.containerOf(
        providerContext,
      ).invalidate(verifiedSubscriptionStateProvider);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('unlock-workout-cta')), findsOneWidget);
      expect(find.byKey(const ValueKey('log-workout-cta')), findsNothing);
      expect(find.text('PRIVATE INSTRUCTION MUST STAY HIDDEN'), findsNothing);
    },
  );

  testWidgets(
    'localized categories use distinct promotional covers with safe semantics',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final semantics = tester.ensureSemantics();
      final cases =
          <
            ({Locale locale, String category, String asset, String safetyLabel})
          >[
            (
              locale: const Locale('en'),
              category: 'Strength',
              asset: 'workout_strength_cover_v1.png',
              safetyLabel: 'not an exercise instruction',
            ),
            (
              locale: const Locale('es'),
              category: 'Cardio',
              asset: 'workout_cardio_cover_v1.png',
              safetyLabel: 'no es una instrucción de movimiento',
            ),
            (
              locale: const Locale('fr'),
              category: 'Mobilité',
              asset: 'workout_mobility_cover_v1.png',
              safetyLabel: 'ce n’est pas une instruction de mouvement',
            ),
            (
              locale: const Locale('tr'),
              category: 'Yüksek yoğunluk aralıklı',
              asset: 'workout_hiit_cover_v1.png',
              safetyLabel: 'hareket talimatı değildir',
            ),
            (
              locale: const Locale('ar'),
              category: 'كيتل بيل',
              asset: 'workout_kettlebell_cover_v1.png',
              safetyLabel: 'وليست تعليمات لأداء الحركة',
            ),
            (
              locale: const Locale('en'),
              category: 'Recovery',
              asset: 'workout_recovery_cover_v1.png',
              safetyLabel: 'not an exercise instruction',
            ),
          ];

      for (var index = 0; index < cases.length; index++) {
        final entry = cases[index];
        final item = _workoutForCategory('visual-$index', entry.category);
        await tester.pumpWidget(
          _TestApp(
            locale: entry.locale,
            child: BilWorkoutRoutinesPage(loader: (_) async => [item]),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName.endsWith(entry.asset),
          ),
          findsOneWidget,
          reason: 'Missing local fallback for ${entry.category}',
        );
        expect(
          find.bySemanticsLabel(RegExp(RegExp.escape(entry.safetyLabel))),
          findsOneWidget,
          reason: 'Unsafe or missing semantics for ${entry.category}',
        );
      }
      semantics.dispose();
    },
  );

  testWidgets(
    'presenter filter uses explicit metadata without claiming medical eligibility',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1050));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final male = _workoutForCategory(
        'male-preview',
        'Strength',
        title: 'Men presenter preview',
        audience: WellnessWorkoutAudience.men,
        presenter: WellnessWorkoutPresenter.adultMale,
        syntheticPreview: true,
      );
      final female = _workoutForCategory(
        'female-preview',
        'Strength',
        title: 'Women presenter preview',
        audience: WellnessWorkoutAudience.women,
        presenter: WellnessWorkoutPresenter.adultFemale,
        syntheticPreview: true,
      );

      await tester.pumpWidget(
        _TestApp(
          child: BilWorkoutRoutinesPage(loader: (_) async => [male, female]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Workout audience'), findsOneWidget);
      expect(find.textContaining('does not determine medical'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('workout-presenter-filter-men')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Men presenter preview'), findsOneWidget);
      expect(find.text('Women presenter preview'), findsNothing);
      expect(find.text('Adult male presenter'), findsOneWidget);
      expect(find.text('Generated preview'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('workout-presenter-filter-women')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Women presenter preview'), findsOneWidget);
      expect(find.text('Men presenter preview'), findsNothing);
      expect(find.text('Adult female presenter'), findsOneWidget);
    },
  );
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.child,
    this.locale = const Locale('en'),
    this.themeMode = ThemeMode.light,
    this.database,
    this.entitlementLoader,
  });

  final Widget child;
  final Locale locale;
  final ThemeMode themeMode;
  final AppDatabase? database;
  final Future<SubscriptionState> Function()? entitlementLoader;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      verifiedSubscriptionStateProvider.overrideWith(
        (ref) async => entitlementLoader == null
            ? FreePlan.createState()
            : await entitlementLoader!(),
      ),
      if (database != null) databaseProvider.overrideWithValue(database!),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF087AC1)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4DB7F5),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: themeMode,
      home: child,
    ),
  );
}

final _verifiedWorkout = WellnessContentItem(
  id: 'strength-01',
  type: WellnessContentType.workouts,
  locale: 'en',
  title: 'Foundation strength',
  description: 'A measured full-body routine for controlled repetitions.',
  publisher: 'BIL Health',
  sourceUrl: Uri.parse('https://bilhealth.com/workouts/strength-01'),
  licenseName: 'BIL licensed original',
  verified: true,
  durationMinutes: 25,
  difficulty: 'Beginner',
  category: 'Strength',
  equipment: const ['Dumbbells', 'Mat'],
  steps: const [
    'Brace your core.',
    'Move through a comfortable range.',
    'Stop if your form breaks down.',
  ],
  author: 'BIL exercise review team',
  attribution: 'Reviewed original routine',
  reviewedAt: DateTime.utc(2026, 8, 1),
  safetyReviewed: true,
);

final _secondVerifiedWorkout = WellnessContentItem(
  id: 'mobility-01',
  type: WellnessContentType.workouts,
  locale: 'en',
  title: 'Foundation mobility',
  description: 'A controlled mobility routine for a comfortable range.',
  publisher: 'BIL Health',
  sourceUrl: Uri.parse('https://bilhealth.com/workouts/mobility-01'),
  licenseName: 'BIL licensed original',
  verified: true,
  durationMinutes: 18,
  difficulty: 'Beginner',
  category: 'Recovery',
  equipment: const ['Mat'],
  steps: const ['Move through a comfortable range.'],
  author: 'BIL exercise review team',
  attribution: 'Reviewed original routine',
  reviewedAt: DateTime.utc(2026, 8, 1),
  safetyReviewed: true,
);

final _paidWorkout = WellnessContentItem(
  id: 'pro-01',
  type: WellnessContentType.workouts,
  locale: 'en',
  title: 'Advanced verified strength',
  description: 'A premium routine with server-controlled instructions.',
  publisher: 'BIL Health',
  sourceUrl: Uri.parse('https://bilhealth.com/workouts/pro-01'),
  licenseName: 'BIL licensed original',
  verified: true,
  durationMinutes: 30,
  difficulty: 'Advanced',
  category: 'Strength',
  equipment: const ['Dumbbells'],
  steps: const ['PRIVATE INSTRUCTION MUST STAY HIDDEN'],
  author: 'BIL exercise review team',
  attribution: 'Reviewed original routine',
  reviewedAt: DateTime.utc(2026, 8, 1),
  safetyReviewed: true,
  minimumAccess: WellnessContentAccess.pro,
  imageMedia: WellnessMediaAsset(
    url: Uri.parse('https://cdn.bilhealth.com/workouts/pro-01.webp'),
    mimeType: 'image/webp',
    sha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    sizeBytes: 2048,
  ),
);

SubscriptionState _verifiedPaidState(CommercePlan plan) => SubscriptionState(
  plan: plan,
  entitlements: const {},
  authority: EntitlementAuthority.verifiedServer,
  currentPeriodEndsAt: DateTime.utc(2099),
  isPurchasable: false,
  canRestorePurchases: true,
);

class _RecordingMediaCache extends WellnessMediaCache {
  int resolutions = 0;

  @override
  Future<WellnessMediaCacheResult> resolve(
    WellnessMediaAsset asset, {
    required bool online,
  }) async {
    resolutions++;
    return const WellnessMediaCacheResult.unavailableOffline();
  }
}

WellnessContentItem _workoutForCategory(
  String id,
  String category, {
  String? title,
  WellnessWorkoutAudience audience = WellnessWorkoutAudience.all,
  WellnessWorkoutPresenter presenter = WellnessWorkoutPresenter.neutral,
  bool syntheticPreview = false,
}) => WellnessContentItem(
  id: id,
  type: WellnessContentType.workouts,
  locale: 'en',
  title: title ?? '$category routine',
  description: 'A verified routine with a promotional category cover.',
  publisher: 'BIL Health',
  sourceUrl: Uri.parse('https://bilhealth.com/workouts/$id'),
  licenseName: 'BIL licensed original',
  verified: true,
  durationMinutes: 20,
  difficulty: 'Beginner',
  audience: audience,
  presenter: presenter,
  syntheticPerformer: syntheticPreview,
  videoMedia: syntheticPreview
      ? WellnessMediaAsset(
          url: Uri.parse('https://cdn.bilhealth.com/workouts/$id.mp4'),
          mimeType: 'video/mp4',
          sha256:
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          sizeBytes: 4096,
          mediaRole: WellnessMediaRole.preview,
        )
      : null,
  category: category,
  equipment: const [],
  steps: const ['Follow the verified movement instructions.'],
  author: 'BIL exercise review team',
  attribution: 'Reviewed original routine',
  reviewedAt: DateTime.utc(2026, 8, 1),
  safetyReviewed: true,
);
