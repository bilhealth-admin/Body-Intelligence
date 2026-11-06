import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/dietary_preferences.dart';
import 'package:body_intelligence_log/features/nutrition/repositories/dietary_preferences_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/workspace/coach_overview_paid_label_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/workspace/coach_reference_workspace.dart';
import 'package:body_intelligence_log/features/profile/domain/goal_timeline_estimator.dart';
import 'package:body_intelligence_log/features/profile/goal_timeline_card.dart';
import 'package:body_intelligence_log/features/profile/plan_navigation_contract.dart';
import 'package:body_intelligence_log/features/profile/plan_page.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/settings/health_information_sources_page.dart';
import 'package:body_intelligence_log/shared/widgets/bil_mobile_list.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../visual_closure/visual_evidence_font.dart';

const _planIntroEnglish =
    'Review the recommendation, then adjust only what fits your plan.';
const _planIntroArabic = 'راجع التوصية، ثم عدّل فقط ما يناسب خطتك.';
const _planReferencesEnglish = 'References for these recommended targets';
const _planReferencesArabic = 'مراجع هذه الأهداف الموصى بها';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadVisualEvidenceFont);

  for (final language in ['ar', 'en']) {
    for (final scale in [1.0, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('Goals intro renders $language at $scale dark=$dark', (
          tester,
        ) async {
          final fixture = await _pumpPlan(
            tester,
            origin: PlanPageOrigin.coach,
            language: language,
            scale: scale,
            dark: dark,
          );
          try {
            final expected = language == 'ar'
                ? _planIntroArabic
                : _planIntroEnglish;
            final intro = find.byType(BilMobilePageIntro);
            expect(
              tester.widget<BilMobilePageIntro>(intro).description,
              expected,
            );
            final description = find.descendant(
              of: intro,
              matching: find.text(expected),
            );
            expect(description.hitTestable(), findsOneWidget);
            if (language == 'ar') {
              expect(find.text(_planIntroEnglish), findsNothing);
            }
            final paragraph = tester.renderObject<RenderParagraph>(description);
            expect(
              paragraph.textDirection,
              language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            );
            expect(paragraph.didExceedMaxLines, isFalse);
            final rect = tester.getRect(description);
            expect(rect.left, greaterThanOrEqualTo(20));
            expect(rect.right, lessThanOrEqualTo(scale == 2 ? 300 : 370));
            expect(rect.bottom, lessThanOrEqualTo(844));
            expect(
              await fixture.database
                  .select(fixture.database.planSettings)
                  .get(),
              isEmpty,
            );
            expect(tester.takeException(), isNull);
            await _capturePlan(
              tester,
              fixture.capture,
              'goals_intro_${language}_${scale}_${dark ? 'dark' : 'light'}',
            );
            final sources = find.byKey(
              const Key('recommended-targets-sources'),
            );
            await tester.scrollUntilVisible(
              sources,
              450,
              scrollable: find.byType(Scrollable).first,
              maxScrolls: 40,
            );
            await tester.pumpAndSettle();
            final caption = find.descendant(
              of: sources,
              matching: find.text(
                language == 'ar'
                    ? _planReferencesArabic
                    : _planReferencesEnglish,
              ),
            );
            expect(caption.hitTestable(), findsOneWidget);
            final captionParagraph = tester.renderObject<RenderParagraph>(
              caption,
            );
            expect(captionParagraph.didExceedMaxLines, isFalse);
            expect(
              captionParagraph.textDirection,
              language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            );
            final captionRect = tester.getRect(caption);
            expect(captionRect.left, greaterThanOrEqualTo(0));
            expect(
              captionRect.right,
              lessThanOrEqualTo(scale == 2 ? 320 : 390),
            );
            if (language == 'ar') {
              expect(find.text(_planReferencesEnglish), findsNothing);
            }
            expect(tester.takeException(), isNull);
            await _capturePlan(
              tester,
              fixture.capture,
              'goals_references_${language}_${scale}_${dark ? 'dark' : 'light'}',
            );
          } finally {
            await fixture.dispose(tester);
          }
        });
      }
    }

    testWidgets('Overview Goals draft survives sources and returns $language', (
      tester,
    ) async {
      final fixture = await _pumpPlan(
        tester,
        origin: PlanPageOrigin.coach,
        language: language,
        fromOverview: true,
      );
      try {
        final planTab = find.byKey(const Key('coach-workspace-tab-/plan'));
        await tester.ensureVisible(planTab);
        await tester.pumpAndSettle();
        final overviewScroll = find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        );
        final overviewOffset = tester
            .state<ScrollableState>(overviewScroll)
            .position
            .pixels;
        await tester.tap(planTab);
        await tester.pumpAndSettle();
        // Browser route information intentionally retains the base location
        // for imperative pushes. Observe the visible route's public state.
        expect(fixture.router.state.uri.path, '/plan');
        expect(fixture.router.canPop(), isTrue);
        expect(find.byType(BilMobilePageIntro), findsOneWidget);

        final strings = AppLocalizations(Locale(language));
        final calories = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == strings.text('Calories (kcal)'),
        );
        await tester.scrollUntilVisible(
          calories,
          450,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 40,
        );
        await tester.enterText(calories, '3400');
        tester.testTextInput.hide();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('plan-health-sources')));
        await tester.pumpAndSettle();
        expect(find.byType(HealthInformationSourcesPage), findsOneWidget);
        expect(
          fixture.router.state.uri.queryParameters['topic'],
          'nutrition-targets',
        );
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(calories).controller!.text, '3400');

        await tester.tap(find.byKey(const Key('secondary-page-back')));
        await tester.pumpAndSettle();
        expect(find.text(strings.text('Discard changes?')), findsOneWidget);
        await tester.tap(find.text(strings.text('Keep editing')));
        await tester.pumpAndSettle();
        expect(fixture.router.state.uri.path, '/plan');
        expect(tester.widget<TextField>(calories).controller!.text, '3400');

        await tester.tap(find.byKey(const Key('secondary-page-back')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(strings.text('Discard')));
        await tester.pumpAndSettle();
        expect(fixture.router.state.uri.path, '/intelligence-center');
        expect(
          find.byKey(const Key('coach-reference-workspace')),
          findsOneWidget,
        );
        expect(planTab.hitTestable(), findsOneWidget);
        expect(
          tester.state<ScrollableState>(overviewScroll).position.pixels,
          closeTo(overviewOffset, .01),
          reason:
              'Returning preserves the Overview scroll position used to open Goals.',
        );
        // Revealing the tab can scroll the greeting above the viewport. Bring
        // the retained header back into view before checking its actual paint.
        await tester.drag(find.byType(ListView), const Offset(0, 600));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('coach-workspace-greeting')).hitTestable(),
          findsOneWidget,
        );
        expect(find.byType(PlanPage), findsNothing);
        expect(
          await fixture.database.select(fixture.database.planSettings).get(),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await fixture.dispose(tester);
      }
    });
  }

  testWidgets(
    'plan lists every pattern and style then saves back only to profile',
    (tester) async {
      final fixture = await _pumpPlan(tester, origin: PlanPageOrigin.profile);

      for (final label in const [
        'Omnivore',
        'Pescatarian',
        'Vegetarian',
        'Vegan',
        'Balanced',
        'High protein',
        'Low carb',
        'Keto',
        'Mediterranean',
        'Plant-forward',
      ]) {
        expect(find.text(label), findsOneWidget, reason: 'Missing $label');
      }

      await _selectAndSave(
        tester,
        pattern: DietaryPattern.vegan,
        approach: 'high_protein',
      );

      expect(
        fixture.router.routeInformationProvider.value.uri.path,
        '/profile-settings',
      );
      expect(find.byKey(const Key('return-profile')), findsOneWidget);
      expect(find.text('saved:vegan/high_protein'), findsOneWidget);
      expect(
        find.byKey(const Key('estimated-time-to-goal-field')),
        findsOneWidget,
      );
      final restored = await DietaryPreferencesRepository(
        PreferencesRepository(fixture.database),
      ).read();
      expect(restored.pattern, DietaryPattern.vegan);
      expect(restored.approach, 'high_protein');

      await fixture.dispose(tester);
    },
  );

  testWidgets('dashboard-origin save returns only to dashboard', (
    tester,
  ) async {
    final fixture = await _pumpPlan(tester, origin: PlanPageOrigin.dashboard);

    await _selectAndSave(
      tester,
      pattern: DietaryPattern.pescatarian,
      approach: 'mediterranean',
    );

    expect(
      fixture.router.routeInformationProvider.value.uri.path,
      '/dashboard',
    );
    expect(find.byKey(const Key('return-dashboard')), findsOneWidget);
    expect(find.text('saved:pescatarian/mediterranean'), findsOneWidget);
    expect(find.byKey(const Key('return-profile')), findsNothing);

    await fixture.dispose(tester);
  });

  testWidgets('a real plan edit prompts before explicit-origin discard', (
    tester,
  ) async {
    final fixture = await _pumpPlan(tester, origin: PlanPageOrigin.dashboard);

    final vegan = find.byKey(const Key('dietary-pattern-vegan'));
    await tester.ensureVisible(vegan);
    await tester.tap(vegan);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('secondary-page-back')));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dietary-system-selector')), findsOneWidget);

    await tester.tap(find.byKey(const Key('secondary-page-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(
      fixture.router.routeInformationProvider.value.uri.path,
      '/dashboard',
    );

    await fixture.dispose(tester);
  });

  testWidgets('plan reflects the pathway activated by the diet engine', (
    tester,
  ) async {
    final fixture = await _pumpPlan(
      tester,
      origin: PlanPageOrigin.profile,
      activePathwayId: 'carb-cycling',
    );

    await tester.scrollUntilVisible(
      find.text('Selected pathway'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Selected pathway'), findsOneWidget);
    expect(find.text('Carb cycling'), findsOneWidget);

    await fixture.dispose(tester);
  });
}

Future<void> _selectAndSave(
  WidgetTester tester, {
  required DietaryPattern pattern,
  required String approach,
}) async {
  final patternFinder = find.byKey(Key('dietary-pattern-${pattern.name}'));
  await tester.ensureVisible(patternFinder);
  await tester.tap(patternFinder);
  await tester.pump();
  final approachFinder = find.byKey(Key('dietary-approach-$approach'));
  await tester.ensureVisible(approachFinder);
  await tester.tap(approachFinder);
  await tester.pump();
  final save = find.byKey(const Key('plan-save-action'));
  await tester.scrollUntilVisible(
    save,
    500,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(save);
  await tester.pumpAndSettle();
  await tester.tap(save);
  await tester.pumpAndSettle();
}

Future<_PlanFixture> _pumpPlan(
  WidgetTester tester, {
  required PlanPageOrigin origin,
  String? activePathwayId,
  String language = 'en',
  double scale = 1,
  bool dark = false,
  bool fromOverview = false,
}) async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  await UserProfileRepository(database).save(
    gender: 'female',
    age: 34,
    height: 168,
    currentWeight: 78,
    targetWeight: 70,
    activityLevel: 'moderate',
    exercises: true,
  );
  if (activePathwayId != null) {
    await PreferencesRepository(
      database,
    ).set('activeNutritionPathway', activePathwayId);
  }
  final initial = fromOverview
      ? '/intelligence-center'
      : '/plan?origin=${origin.queryValue}';
  final capture = GlobalKey();
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/intelligence-center',
        builder: (context, _) => CoachReferenceWorkspace(
          snapshot: null,
          now: DateTime(2026, 11, 6, 9, 41),
          onChat: () {},
          onRoute: (route) => context.push('$route?origin=coach'),
          onQuickAdd: () {},
          onPhoto: () {},
          onVoice: () {},
        ),
      ),
      GoRoute(
        path: '/plan',
        builder: (_, state) => PlanPage(
          origin: PlanPageOrigin.fromQuery(state.uri.queryParameters['origin']),
        ),
      ),
      GoRoute(
        path: '/health-information-sources',
        builder: (_, state) => HealthInformationSourcesPage(
          initialTopic: state.uri.queryParameters['topic'],
        ),
      ),
      GoRoute(
        path: '/profile-settings',
        builder: (_, _) => const _ReturnProbe(key: Key('return-profile')),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const _ReturnProbe(key: Key('return-dashboard')),
      ),
    ],
  );
  await tester.binding.setSurfaceSize(Size(scale == 2 ? 320 : 390, 844));
  final family = language == 'ar' ? 'NotoArabicEvidence' : 'RobotoEvidence';
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        coachOverviewPaidLabelProvider.overrideWithValue(null),
        coachOverviewCreditAccessProvider.overrideWithValue(false),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: visualEvidenceTheme(
          dark
              ? BilFlagshipTheme.dark(isArabic: language == 'ar')
              : BilFlagshipTheme.light(isArabic: language == 'ar'),
          fontFamily: family,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(
            key: capture,
            child: visualEvidenceTextSurface(child, fontFamily: family),
          ),
        ),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _PlanFixture(database: database, router: router, capture: capture);
}

Future<void> _capturePlan(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async {
  final output = Platform.environment['BIL_UI_BATCH_CAPTURE_DIR'];
  if (output == null) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(output).create(recursive: true);
      await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

class _ReturnProbe extends ConsumerWidget {
  const _ReturnProbe({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dietary = ref.watch(dietaryPreferencesProvider);
    final profile = ref.watch(userProfileProvider);
    return Scaffold(
      body: dietary.when(
        loading: () => const CircularProgressIndicator(),
        error: (_, _) => const Text('error'),
        data: (saved) => profile.when(
          loading: () => const CircularProgressIndicator(),
          error: (_, _) => const Text('error'),
          data: (body) => Column(
            children: [
              Text('saved:${saved.pattern.name}/${saved.approach}'),
              if (body != null)
                GoalTimelineCard(
                  estimate: GoalTimelineEstimator.estimate(
                    currentWeightKg: body.currentWeight,
                    targetWeightKg: body.targetWeight,
                    goalType: body.targetWeight < body.currentWeight
                        ? 'lose'
                        : body.targetWeight > body.currentWeight
                        ? 'gain'
                        : 'maintain',
                    asOf: DateTime(2026, 8, 24),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _PlanFixture {
  const _PlanFixture({
    required this.database,
    required this.router,
    required this.capture,
  });

  final AppDatabase database;
  final GoRouter router;
  final GlobalKey capture;

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    router.dispose();
    await database.close();
    await tester.binding.setSurfaceSize(null);
  }
}
