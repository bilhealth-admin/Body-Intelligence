import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_diets.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/features/nutrition_plans/data/diet_plan_repository.dart';
import 'package:body_intelligence_log/features/nutrition_plans/domain/diet_macro_plan.dart';
import 'package:body_intelligence_log/features/nutrition_plans/domain/nutrition_pathway_catalog.dart';
import 'package:body_intelligence_log/features/nutrition_plans/domain/nutrition_pathway_localizer.dart';
import 'package:body_intelligence_log/features/nutrition_plans/presentation/diet_plan_editor_page.dart';
import 'package:body_intelligence_log/features/nutrition_plans/presentation/nutrition_pathways_page.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _scrollUntilBuilt(
  WidgetTester tester,
  Finder target, {
  int maxSwipes = 12,
  double swipeDistance = 240,
}) async {
  final scrollable = find.byType(Scrollable).first;
  expect(scrollable, findsOneWidget);
  for (var attempt = 0; attempt < maxSwipes; attempt++) {
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      return;
    }
    await tester.drag(scrollable, Offset(0, -swipeDistance));
    await tester.pumpAndSettle();
  }
  expect(target, findsOneWidget);
}

void main() {
  test('diet copy and all pathways resolve across 25 locales', () {
    expect(AppLocalizations.supportedLocales, hasLength(25));
    for (final locale in AppLocalizations.supportedLocales) {
      final tag = BilLocalePolicy.canonicalTag(locale);
      for (final source in DietRuntimeCopy.values.keys) {
        final value = RuntimeCopy.resolve(source, tag);
        expect(value, isNotNull, reason: '$tag · $source');
        expect(value!.trim(), isNotEmpty, reason: '$tag · $source');
        expect(value, isNot(contains('\uFFFD')), reason: '$tag · $source');
      }
      for (final pathway in nutritionPathways) {
        final values = <String>[
          nutritionPathwayTitle(pathway, tag),
          nutritionPathwaySubtitle(pathway, tag),
          ...nutritionPathwayTags(pathway, tag),
          ...nutritionPathwayApproach(pathway, tag),
          ...nutritionPathwayTracking(pathway, tag),
        ];
        expect(
          values,
          everyElement(isNot(isEmpty)),
          reason: '$tag · ${pathway.id}',
        );
        expect(
          values,
          everyElement(isNot(contains('\uFFFD'))),
          reason: '$tag · ${pathway.id}',
        );
      }
    }
  });

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = BilLocalePolicy.canonicalTag(locale);
    testWidgets('$tag diet catalog and editors render at 160% text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      Future<void> pump(Widget page) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dietPlanRepositoryProvider.overrideWithValue(
                _InMemoryDietPlanRepository(),
              ),
              activeNutritionPathwayProvider.overrideWithValue(
                const AsyncData(null),
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
              theme: BilFlagshipTheme.light(
                isArabic: BilLocalePolicy.isRtlTag(tag),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.6)),
                child: child ?? const SizedBox.shrink(),
              ),
              home: page,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final exception = tester.takeException();
        if (exception is FlutterError) debugPrint(exception.toStringDeep());
        expect(exception, isNull, reason: tag);
      }

      await pump(NutritionPathwaysPage(key: ValueKey('$tag-catalog')));
      expect(find.byType(NutritionPathwaysPage), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('nutrition-pathway-row-carb-cycling')),
        420,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const Key('nutrition-pathway-row-carb-cycling')),
        findsOneWidget,
        reason: '$tag pathway rows',
      );
      expect(tester.takeException(), isNull, reason: '$tag catalog');

      await pump(
        DietPlanEditorPage(
          key: ValueKey('$tag-carb-editor'),
          pathwayId: 'carb-cycling',
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('diet-calories-field')),
        260,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('diet-calories-field')), findsOneWidget);
      await _scrollUntilBuilt(
        tester,
        find.byKey(const Key('diet-macro-editing-notice')),
      );
      expect(
        find.byKey(const Key('diet-macro-editing-notice')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('diet-carbs-7')),
        520,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('diet-protein-7')), findsOneWidget);
      expect(find.byKey(const Key('diet-fat-7')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$tag carb editor');

      await pump(
        DietPlanEditorPage(
          key: ValueKey('$tag-pregnancy-editor'),
          pathwayId: 'pregnancy',
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('pregnancy-base-calories')),
        260,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('pregnancy-base-calories')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('diet-carbs-7')),
        520,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$tag pregnancy editor');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(Duration.zero);
      await tester.idle();
    });
  }

  testWidgets('an applied pathway remains editable and exposes reset', (
    tester,
  ) async {
    final repository = _InMemoryDietPlanRepository()
      .._activePathway = 'carb-cycling';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dietPlanRepositoryProvider.overrideWithValue(repository),
          activeNutritionPathwayProvider.overrideWithValue(
            const AsyncData('carb-cycling'),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const DietPlanEditorPage(pathwayId: 'carb-cycling'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('diet-calories-field')),
      260,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('diet-calories-field')))
          .enabled,
      isTrue,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const Key('diet-plan-reset-recommended')),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('diet-plan-activate')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'reset replaces stale pathway fields and active plans remain editable',
    (tester) async {
      final repository = _InMemoryDietPlanRepository()
        .._activePathway = 'carb-cycling';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dietPlanRepositoryProvider.overrideWithValue(repository),
            activeNutritionPathwayProvider.overrideWithValue(
              const AsyncData('carb-cycling'),
            ),
            userProfileProvider.overrideWithValue(
              AsyncData(
                UserProfileData(
                  id: 1,
                  uuid: 'diet-reset-profile',
                  age: 35,
                  gender: 'male',
                  height: 178,
                  currentWeight: 82,
                  targetWeight: 76,
                  activityLevel: 'moderate',
                  exercises: true,
                  createdAt: DateTime(2026, 8, 23),
                  updatedAt: DateTime(2026, 8, 23),
                  revision: 1,
                  syncStatus: 'local',
                ),
              ),
            ),
            activeGoalProvider.overrideWithValue(const AsyncData(null)),
            latestWeightProvider.overrideWithValue(const AsyncData(null)),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: DietPlanEditorPage(pathwayId: 'carb-cycling'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('diet-calories-field')),
        260,
        scrollable: find.byType(Scrollable).first,
      );

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('diet-calories-field')))
            .enabled,
        isTrue,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('diet-carbs-1')),
        260,
        scrollable: find.byType(Scrollable).first,
      );
      final staleMonday = tester
          .widget<TextField>(find.byKey(const Key('diet-carbs-1')))
          .controller!
          .text;
      expect(staleMonday, '20');

      await tester.tap(find.byKey(const Key('diet-plan-reset-recommended')));
      await tester.pumpAndSettle();

      expect(repository._resetTarget, isNotNull);
      expect(repository._activePathway, isNull);
      expect(
        tester.widget<TextField>(find.byKey(const Key('diet-carbs-1'))).enabled,
        isTrue,
      );
      final resetMonday = tester
          .widget<TextField>(find.byKey(const Key('diet-carbs-1')))
          .controller!
          .text;
      expect(resetMonday, isNot(staleMonday));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('diet-plan-activate')))
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(const Key('diet-plan-activate')));
      await tester.pumpAndSettle();

      expect(repository._activePathway, 'carb-cycling');
      expect(
        tester.widget<TextField>(find.byKey(const Key('diet-carbs-1'))).enabled,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(Duration.zero);
      await tester.idle();
    },
  );

  testWidgets('fixed calories rebalance editable carbs protein and fat', (
    tester,
  ) async {
    final repository = _InMemoryDietPlanRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dietPlanRepositoryProvider.overrideWithValue(repository),
          activeNutritionPathwayProvider.overrideWithValue(
            const AsyncData(null),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: DietPlanEditorPage(pathwayId: 'carb-cycling'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('diet-calories-field')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const Key('diet-calories-field')),
      '1000',
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('diet-protein-1')),
      360,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byKey(const Key('diet-protein-1')), '100');
    await tester.pump();

    double value(String key) => double.parse(
      tester.widget<TextField>(find.byKey(Key(key))).controller!.text,
    );
    final carbs = value('diet-carbs-1');
    final protein = value('diet-protein-1');
    final fat = value('diet-fat-1');
    expect(protein, 100);
    expect(4 * carbs + 4 * protein + 9 * fat, closeTo(1000, .01));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('diet-plan-activate')))
          .onPressed,
      isNotNull,
    );
  });
}

class _InMemoryDietPlanRepository implements DietPlanRepository {
  final _drafts = <String, DietDraft>{};
  String? _activePathway;
  NutritionGoalTarget? _resetTarget;

  @override
  Never get preferences => throw UnsupportedError('Not used by widget test');

  @override
  Never get schedule => throw UnsupportedError('Not used by widget test');

  @override
  Future<DietDraft> read(String pathwayId) async =>
      _drafts[pathwayId] ??
      (dietPresets[pathwayId] ?? dietPresets['mediterranean']!).toDraft();

  @override
  Future<void> saveDraft(DietDraft draft) async {
    _drafts[draft.pathwayId] = draft;
  }

  @override
  Future<void> activate(
    DietDraft draft, {
    required NutritionPathwayActivationAuthorization authorization,
  }) async {
    await saveDraft(draft);
    _activePathway = draft.pathwayId;
  }

  @override
  Future<String?> readActivePathway() async => _activePathway;

  @override
  Future<void> resetToRecommended(NutritionGoalTarget target) async {
    _resetTarget = target;
    _activePathway = null;
  }
}
