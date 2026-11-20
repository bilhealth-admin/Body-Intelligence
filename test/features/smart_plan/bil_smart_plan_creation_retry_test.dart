import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/meal_planner/domain/meal_plan.dart';
import 'package:body_intelligence_log/features/nutrition/domain/dietary_preferences.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/smart_plan/data/bil_smart_plan_repository.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan_engine.dart';
import 'package:body_intelligence_log/features/smart_plan/presentation/bil_smart_plan_page.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_catalog.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_clock.dart';
import 'package:drift/native.dart';
import 'package:body_intelligence_log/shared/widgets/bil_compact_activity_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_coach.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/bil_action_receipt.dart';

part 'bil_smart_plan_creation_validation_cases.dart';

const _owner = 'synthetic-plan-retry-owner';
const _adult =
    'I am 18 or older and reviewed my allergies, dietary restrictions and training availability.';
final _now = DateTime(2026, 11, 17, 12);

// Faults are injected at real storage boundaries, not into the plan UI, catalog,
// entitlement presentation, generated result or repository success outcome.
class _FaultPreferences extends PreferencesRepository {
  _FaultPreferences(super.database);
  int failDietaryReads = 0;
  int dietaryReads = 0;
  int failPlanReads = 0;
  bool failNextCommittedReadback = false;
  int planCommits = 0;
  Completer<void>? holdNextPlanRead;
  Completer<void>? holdNextDietaryRead;

  bool _planKey(String key) =>
      key.startsWith('bil.smart-plan.owner.') ||
      key.startsWith('bil.smart-plan.draft.');

  @override
  Future<String?> get(String key) async {
    if (key == DietaryPreferences.storageKey) dietaryReads++;
    final dietaryRead = key == DietaryPreferences.storageKey
        ? holdNextDietaryRead
        : null;
    if (dietaryRead != null) {
      holdNextDietaryRead = null;
      await dietaryRead.future;
    }
    final held = _planKey(key) ? holdNextPlanRead : null;
    if (held != null) {
      holdNextPlanRead = null;
      await held.future;
    }
    if (key == DietaryPreferences.storageKey && failDietaryReads > 0) {
      failDietaryReads--;
      throw StateError('synthetic_temporary_dietary_storage_failure');
    }
    if (_planKey(key) && failPlanReads > 0) {
      failPlanReads--;
      throw StateError('synthetic_post_commit_readback_failure');
    }
    return super.get(key);
  }

  void _committed() {
    planCommits++;
    if (failNextCommittedReadback) {
      failNextCommittedReadback = false;
      failPlanReads = 1;
    }
  }

  @override
  Future<String> update(
    String key,
    String Function(String?) derive, {
    bool Function()? isCurrent,
  }) async {
    final result = await super.update(key, derive, isCurrent: isCurrent);
    if (_planKey(key)) _committed();
    return result;
  }

  @override
  Future<bool> mutateIfUnchanged({
    required Map<String, String?> expected,
    Map<String, String> set = const {},
    Iterable<String> remove = const [],
    bool Function()? isCurrent,
  }) async {
    final committed = await super.mutateIfUnchanged(
      expected: expected,
      set: set,
      remove: remove,
      isCurrent: isCurrent,
    );
    if (committed && set.keys.any(_planKey)) _committed();
    return committed;
  }
}

Future<void> _until(WidgetTester tester, bool Function() done) async {
  await tester.runAsync(() async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (!done() && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 16));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
  await tester.pump(const Duration(milliseconds: 16));
  expect(done(), isTrue, reason: 'The exact semantic phase must complete.');
}

Future<void> _select<T>(WidgetTester tester, String label) async {
  final control = find.byType(DropdownButtonFormField<T>);
  await tester.ensureVisible(control);
  await tester.tap(control);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(label).last);
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _selectField<T>(
  WidgetTester tester,
  String field,
  String label,
) async {
  final control = find.descendant(
    of: find.byKey(ValueKey('bil-smart-plan-field-$field')),
    matching: find.byType(DropdownButtonFormField<T>),
  );
  await tester.ensureVisible(control);
  await tester.tap(control);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(label).last);
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Finder _numberField(String field) => find.descendant(
  of: find.byKey(ValueKey('bil-smart-plan-field-$field')),
  matching: find.byType(DropdownButtonFormField<int>),
);

Future<void> _openAndFill(
  WidgetTester tester, {
  bool exactReported = false,
  bool replacement = false,
  bool alreadyOpen = false,
}) async {
  if (!alreadyOpen && replacement) {
    await tester.tap(find.byKey(const ValueKey('bil-smart-plan-options')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create another draft'));
  } else if (!alreadyOpen) {
    await tester.ensureVisible(
      find.byKey(const ValueKey('bil-smart-plan-create')),
    );
    await tester.tap(find.byKey(const ValueKey('bil-smart-plan-create')));
  }
  await tester.pumpAndSettle();
  await _select<BilPlanHorizon>(
    tester,
    exactReported ? 'One month' : 'Three months',
  );
  await _select<BilPlanFocus>(tester, 'Training and nutrition');
  await _select<BilPlanEnvironment>(tester, exactReported ? 'Gym' : 'Home');
  await _select<BilPlanExperience>(
    tester,
    exactReported ? 'Beginner' : 'Regular practice',
  );
  await _select<MealPlanDiet>(
    tester,
    exactReported ? 'Balanced recipes' : 'High-protein recipes',
  );
  await _selectField<int>(
    tester,
    'minutes',
    exactReported ? '75 min' : '50 min',
  );
  await _selectField<int>(tester, 'sessions', exactReported ? '3' : '2');
  if (!exactReported) {
    await _select<String>(tester, '01:00');
    final mat = find.widgetWithText(CheckboxListTile, 'Exercise mat');
    await tester.ensureVisible(mat);
    if (tester.widget<CheckboxListTile>(mat).value != true) {
      await tester.tap(mat);
    }
    await tester.pump();
  }
  await _selectField<bool>(tester, 'symptoms', 'No');
  await _selectField<bool>(tester, 'medical', 'No');
  final adult = find.widgetWithText(CheckboxListTile, _adult);
  await tester.ensureVisible(adult);
  if (tester.widget<CheckboxListTile>(adult).value != true) {
    await tester.tap(adult);
  }
  await tester.pump();
}

Future<void> _retry(WidgetTester tester) async {
  final retry = find.byKey(const ValueKey('bil-smart-plan-retry'));
  await tester.ensureVisible(retry);
  await tester.tap(retry);
  await tester.pump();
}

Future<void> _submit(
  WidgetTester tester, {
  _FaultPreferences? diagnostics,
}) async {
  final prepare = find.byKey(const ValueKey('bil-smart-plan-review-draft'));
  await tester.ensureVisible(prepare);
  expect(tester.widget<FilledButton>(prepare).onPressed, isNotNull);
  await tester.tap(prepare);
  try {
    await _until(
      tester,
      () => find
          .byKey(const ValueKey('bil-smart-plan-error'))
          .evaluate()
          .isNotEmpty,
    );
  } finally {
    if (find.byKey(const ValueKey('bil-smart-plan-error')).evaluate().isEmpty) {
      final menus = find
          .byKey(const ValueKey('bil-smart-plan-options'))
          .evaluate();
      final enabled = menus.isEmpty
          ? null
          : (menus.single.widget as PopupMenuButton<String>).enabled;
      debugPrint(
        'QA_PLAN_SUBMIT_TIMEOUT '
        'commits=${diagnostics?.planCommits} '
        'commitFaultArmed=${diagnostics?.failNextCommittedReadback} '
        'readFaults=${diagnostics?.failPlanReads} '
        'menuEnabled=$enabled '
        'tabs=${find.byKey(const ValueKey('bil-smart-plan-tabs')).evaluate().length} '
        'creation=${find.byKey(const ValueKey('bil-smart-plan-review-draft')).evaluate().length}',
      );
    }
  }
}

void _expectRecoveredChoices(WidgetTester tester) {
  expect(
    find.text('Create a reviewable plan'),
    findsOneWidget,
    reason:
        'Retry must reopen the failed creation form with the submitted choices.',
  );
  expect(
    find.byKey(const ValueKey('bil-smart-plan-review-draft')),
    findsOneWidget,
  );
  expect(
    find.byType(DropdownButtonFormField<BilPlanHorizon>),
    findsOneWidget,
    reason:
        'An empty or saved-plan page is not recovery of the submitted form.',
  );
  expect(
    tester
        .widget<DropdownButtonFormField<BilPlanHorizon>>(
          find.byType(DropdownButtonFormField<BilPlanHorizon>),
        )
        .initialValue,
    BilPlanHorizon.threeMonths,
  );
  expect(
    tester
        .widget<DropdownButtonFormField<BilPlanFocus>>(
          find.byType(DropdownButtonFormField<BilPlanFocus>),
        )
        .initialValue,
    BilPlanFocus.combined,
  );
  expect(
    tester
        .widget<DropdownButtonFormField<BilPlanEnvironment>>(
          find.byType(DropdownButtonFormField<BilPlanEnvironment>),
        )
        .initialValue,
    BilPlanEnvironment.home,
  );
  expect(
    tester
        .widget<DropdownButtonFormField<BilPlanExperience>>(
          find.byType(DropdownButtonFormField<BilPlanExperience>),
        )
        .initialValue,
    BilPlanExperience.regular,
  );
  expect(
    tester
        .widget<DropdownButtonFormField<MealPlanDiet>>(
          find.byType(DropdownButtonFormField<MealPlanDiet>),
        )
        .initialValue,
    MealPlanDiet.highProtein,
  );
  expect(
    tester
        .widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>),
        )
        .initialValue,
    '01:00',
  );
  expect(
    tester
        .widget<DropdownButtonFormField<int>>(_numberField('minutes'))
        .initialValue,
    50,
  );
  expect(
    tester
        .widget<DropdownButtonFormField<int>>(_numberField('sessions'))
        .initialValue,
    2,
  );
  expect(
    tester
        .widget<CheckboxListTile>(
          find.widgetWithText(CheckboxListTile, 'Exercise mat'),
        )
        .value,
    isTrue,
  );
  expect(
    tester
        .widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, _adult))
        .value,
    isTrue,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Seed real verified asset caches outside per-widget fake async zones.
    // A cached completed Future from a retired widget zone cannot drive later
    // real SQLite fixture setup. No catalog or result is replaced by a fake.
    const catalog = BilSmartPlanCatalog();
    await catalog.gymSessions(sessionMinutes: 75);
    await catalog.sourcedRecipes(dietary: const DietaryPreferences());
  });
  late AppDatabase db;
  var fixtureNow = _now;
  late _FaultPreferences preferences;
  late ProviderContainer container;
  BilSmartPlanRepository repository() => BilSmartPlanRepository(
    preferences: PreferencesRepository(db),
    currentOwnerId: () => _owner,
  );

  setUp(() async {
    fixtureNow = _now;
    db = AppDatabase.forTesting(NativeDatabase.memory(), localOwnerId: _owner);
    preferences = _FaultPreferences(db);
    await UserProfileRepository(db).save(
      gender: 'male',
      age: 25,
      height: 170,
      currentWeight: 70,
      targetWeight: 70,
      activityLevel: 'lightly_active',
      exercises: false,
    );
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        preferencesRepositoryProvider.overrideWithValue(preferences),
        verifiedEntitlementOwnerIdProvider.overrideWithValue(_owner),
        verifiedSubscriptionAccessProvider.overrideWithValue(
          AsyncData(
            SubscriptionState(
              plan: CommercePlan.premium,
              entitlements: const {},
              authority: EntitlementAuthority.verifiedServer,
              isPurchasable: false,
              canRestorePurchases: false,
            ),
          ),
        ),
        bilSmartPlanClockProvider.overrideWithValue(() => fixtureNow),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> mount(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    double width = 430,
    double textScale = 1,
    bool expectCatalogReview = false,
  }) async {
    tester.view.physicalSize = Size(width, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: BilFlagshipTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: const BilSmartPlanPage(),
        ),
      ),
    );
    await _until(
      tester,
      () => expectCatalogReview
          ? find
                .byKey(const ValueKey('bil-smart-plan-catalog-review'))
                .evaluate()
                .isNotEmpty
          : find
                    .byKey(const ValueKey('bil-smart-plan-create'))
                    .evaluate()
                    .isNotEmpty ||
                find
                    .byKey(const ValueKey('bil-smart-plan-tabs'))
                    .evaluate()
                    .isNotEmpty,
    );
  }

  Future<BilSmartPlan> seedApproved() async {
    final catalog = const BilSmartPlanCatalog();
    final workouts = await catalog.gymSessions(sessionMinutes: 75);

    final recipes = await catalog.sourcedRecipes(
      dietary: const DietaryPreferences(),
    );

    final plan = const BilSmartPlanEngine().generate(
      BilPlanCreationRequest(
        ownerId: _owner,
        planId: 'existing-approved-plan',
        startOn: _now,
        horizon: BilPlanHorizon.month,
        focus: BilPlanFocus.combined,
        workoutsPerWeek: 3,
        confirmedPreferences: true,
        adultConfirmed: true,
        ageYears: 25,
        workoutCatalog: workouts,
        recipeCatalog: recipes,
        setup: BilPlanSetup(
          environment: BilPlanEnvironment.gym,
          experience: BilPlanExperience.beginner,
          sessionMinutes: 75,
          equipment: {'gym'},
        ),
      ),
      _now,
    );
    await repository().save(plan, expectedRevision: 0);
    final active = plan.withStatus(BilPlanStatus.active, _now);
    await repository().save(active, expectedRevision: 1);

    return active;
  }

  for (final existing in [false, true]) {
    testWidgets(
      'failed creation retains every input on Retry existing=$existing',
      (tester) async {
        final before = existing ? await tester.runAsync(seedApproved) : null;
        await mount(tester);
        await _openAndFill(tester, replacement: existing);
        preferences.failDietaryReads = 1;
        await _submit(tester, diagnostics: preferences);
        expect(
          (await tester.runAsync(() => repository().readFor(_owner)))?.encode(),
          before?.encode(),
        );
        expect(preferences.planCommits, 0);
        await _retry(tester);
        await tester.pumpAndSettle();
        _expectRecoveredChoices(tester);
        expect(preferences.planCommits, 0);
        Navigator.of(
          tester.element(
            find.byKey(const ValueKey('bil-smart-plan-review-draft')),
          ),
        ).pop();
        await tester.pumpAndSettle();
        await _retry(tester);
        await tester.pumpAndSettle();
        _expectRecoveredChoices(tester);
        expect(
          (await tester.runAsync(() => repository().readFor(_owner)))?.encode(),
          before?.encode(),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'Gym75 one month reconciles committed write instead of duplicating existing=$existing',
      (tester) async {
        final before = existing ? await tester.runAsync(seedApproved) : null;
        await mount(tester);
        await _openAndFill(tester, exactReported: true, replacement: existing);
        preferences.failNextCommittedReadback = true;
        await _submit(tester, diagnostics: preferences);
        final committed = existing
            ? await tester.runAsync(() => repository().readDraft(_owner))
            : await tester.runAsync(() => repository().readFor(_owner));
        expect(committed, isNotNull);
        final exact = committed!.encode();
        expect(preferences.planCommits, 1);
        await _retry(tester);
        await _until(
          tester,
          () =>
              find
                  .byKey(const ValueKey('bil-smart-plan-error'))
                  .evaluate()
                  .isEmpty &&
              find
                  .byKey(const ValueKey('bil-smart-plan-tabs'))
                  .evaluate()
                  .isNotEmpty,
        );
        expect(
          find.byKey(const ValueKey('bil-smart-plan-review-draft')),
          findsNothing,
        );
        expect(preferences.planCommits, 1);
        expect(
          (existing
                  ? await tester.runAsync(() => repository().readDraft(_owner))
                  : await tester.runAsync(() => repository().readFor(_owner)))!
              .encode(),
          exact,
        );
        if (existing) {
          expect(
            (await tester.runAsync(
              () => repository().readFor(_owner),
            ))!.encode(),
            before!.encode(),
          );
          expect(
            find.text(
              'Your current plan stays active until you approve this draft.',
            ),
            findsOneWidget,
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final horizon in BilPlanHorizon.values) {
    for (final style in MealPlanDiet.values) {
      testWidgets('Gym75 creates approves and reopens $style for $horizon', (
        tester,
      ) async {
        fixtureNow = DateTime(2026, 11, 20, 23, 45);
        await mount(tester);
        await _openAndFill(tester, exactReported: true);
        await _select<BilPlanHorizon>(tester, switch (horizon) {
          BilPlanHorizon.week => 'One week',
          BilPlanHorizon.month => 'One month',
          BilPlanHorizon.threeMonths => 'Three months',
          BilPlanHorizon.sixMonths => 'Six months',
        });
        final submit = find.byKey(
          const ValueKey('bil-smart-plan-review-draft'),
        );
        await _select<MealPlanDiet>(tester, switch (style) {
          MealPlanDiet.balanced => 'Balanced recipes',
          MealPlanDiet.vegetarian => 'Vegetarian recipes',
          MealPlanDiet.highProtein => 'High-protein recipes',
        });
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        final approve = find.widgetWithText(
          FilledButton,
          'Approve and activate',
        );
        final error = find.byKey(const ValueKey('bil-smart-plan-error'));
        await _until(
          tester,
          () => approve.evaluate().isNotEmpty || error.evaluate().isNotEmpty,
        );
        expect(error, findsNothing);
        final draft = (await tester.runAsync(
          () => repository().readFor(_owner),
        ))!;
        expect(draft.status, BilPlanStatus.draft);
        expect(draft.horizon, horizon);
        expect(draft.startDate, "2026-11-20");
        expect(draft.days.expand((day) => day.meals), isNotEmpty);
        expect(draft.setup!.environment, BilPlanEnvironment.gym);
        expect(draft.setup!.sessionMinutes, 75);
        await tester.ensureVisible(approve);
        await tester.tap(approve);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
        await _until(
          tester,
          () => preferences.planCommits == 2 || error.evaluate().isNotEmpty,
        );
        expect(error, findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await mount(tester);
        expect(error, findsNothing);
        final active = (await tester.runAsync(
          () => repository().readFor(_owner),
        ))!;
        expect(active.id, draft.id);
        expect(active.revision, draft.revision + 1);
        expect(active.status, BilPlanStatus.active);
        expect(
          active.days,
          hasLength(BilPlanDate.durationDays(horizon, fixtureNow)),
        );
        expect(preferences.planCommits, 2);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets(
    'incomplete vegetarian menu keeps every choice until an explicit supported style is submitted',
    (tester) async {
      const dietary = DietaryPreferences(
        excludedIngredients: {
          'chickpeas',
          'beans',
          'lentils',
          'tofu',
          'peas',
          'tahini',
          'egg',
          'quinoa',
        },
      );
      await tester.runAsync(
        () => preferences.set(DietaryPreferences.storageKey, dietary.encode()),
      );
      await mount(tester);
      await _openAndFill(tester, exactReported: true);
      await _select<BilPlanHorizon>(tester, 'One week');
      await _select<MealPlanDiet>(tester, 'Vegetarian recipes');
      final prepare = find.byKey(const ValueKey('bil-smart-plan-review-draft'));
      final guidance = find.byKey(
        const ValueKey('bil-smart-plan-recipe-guidance'),
      );
      await tester.ensureVisible(prepare);
      await tester.tap(prepare);
      await _until(tester, () => guidance.evaluate().isNotEmpty);
      expect(
        find.descendant(
          of: guidance,
          matching: find.text('No matching recipes. Lunch · Dinner'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<MealPlanDiet>>(
              find.byType(DropdownButtonFormField<MealPlanDiet>),
            )
            .initialValue,
        MealPlanDiet.vegetarian,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<int>>(_numberField('minutes'))
            .initialValue,
        75,
      );
      expect(preferences.planCommits, 0);
      final alternative = find.descendant(
        of: guidance,
        matching: find.widgetWithText(TextButton, 'High-protein recipes'),
      );
      await tester.ensureVisible(alternative);
      await tester.tap(alternative);
      await tester.pump();
      expect(preferences.planCommits, 0);
      expect(guidance, findsNothing);
      await tester.ensureVisible(prepare);
      await tester.tap(prepare);
      await _until(
        tester,
        () => find
            .widgetWithText(FilledButton, 'Approve and activate')
            .evaluate()
            .isNotEmpty,
      );
      final draft = (await tester.runAsync(
        () => repository().readFor(_owner),
      ))!;
      expect(draft.horizon, BilPlanHorizon.week);
      for (final id
          in draft.days
              .expand((day) => day.meals)
              .map((meal) => meal.recipeId)
              .toSet()) {
        final detail = await tester.runAsync(
          () => const BilSmartPlanCatalog().recipeDetail(id, dietary),
        );
        expect(detail!.dietaryEvidence.highProtein, isTrue);
      }
      expect(
        await tester.runAsync(
          () => preferences.get(DietaryPreferences.storageKey),
        ),
        dietary.encode(),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Gym75 recipe guidance preserves saved restrictions when no style is complete',
    (tester) async {
      final dietary = const DietaryPreferences(
        requirements: {DietaryRequirement.kosher},
      ).encode();
      await tester.runAsync(
        () => preferences.set(DietaryPreferences.storageKey, dietary),
      );
      await mount(tester);
      await _openAndFill(tester, exactReported: true);
      final submit = find.byKey(const ValueKey('bil-smart-plan-review-draft'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      final guidance = find.byKey(
        const ValueKey('bil-smart-plan-recipe-guidance'),
      );
      await _until(tester, () => guidance.evaluate().isNotEmpty);
      expect(
        find.descendant(of: guidance, matching: find.text('Balanced recipes')),
        findsNothing,
      );
      expect(preferences.planCommits, 0);
      final training = find.descendant(
        of: guidance,
        matching: find.widgetWithText(TextButton, 'Training only'),
      );
      await tester.ensureVisible(training);
      await tester.tap(training);
      await tester.pump();
      expect(preferences.planCommits, 0);
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await _until(
        tester,
        () => find
            .widgetWithText(FilledButton, 'Approve and activate')
            .evaluate()
            .isNotEmpty,
      );
      final draft = (await tester.runAsync(
        () => repository().readFor(_owner),
      ))!;
      expect(draft.focus, BilPlanFocus.training);
      expect(draft.days.expand((day) => day.meals), isEmpty);
      expect(
        await tester.runAsync(
          () => preferences.get(DietaryPreferences.storageKey),
        ),
        dietary,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'held Gym75 preflight shows stable busy feedback and retires on dismissal',
    (tester) async {
      await mount(tester);
      await _openAndFill(tester, exactReported: true);
      final submit = find.byKey(const ValueKey('bil-smart-plan-review-draft'));
      final held = Completer<void>();
      preferences.holdNextDietaryRead = held;
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      final label = find.descendant(
        of: submit,
        matching: find.text('Prepare a draft'),
      );
      final indicator = find.descendant(
        of: submit,
        matching: find.byType(BilCompactActivityIndicator),
      );
      final beforeLabel = tester.getRect(label);
      final beforeButton = tester.getRect(submit);
      final press = tester.widget<FilledButton>(submit).onPressed!;
      final initialReads = preferences.dietaryReads;
      expect(indicator, findsNothing);
      await tester.tap(submit);
      await _until(tester, () => preferences.holdNextDietaryRead == null);
      expect(indicator, findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Checking recipes')), findsOneWidget);
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      press();
      await tester.tap(submit, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(preferences.dietaryReads, initialReads + 1);
      expect(tester.getRect(label), beforeLabel);
      expect(tester.getRect(submit), beforeButton);
      Navigator.of(tester.element(submit)).pop();
      await tester.pumpAndSettle();
      held.complete();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('bil-smart-plan-create')),
        findsOneWidget,
      );
      expect(preferences.planCommits, 0);
      expect(await tester.runAsync(() => repository().readFor(_owner)), isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'new stored milk and egg restrictions block activation and reopening a saved Gym75 draft',
    (tester) async {
      await mount(tester);
      await _openAndFill(tester, exactReported: true);
      await _select<BilPlanHorizon>(tester, 'One week');
      final prepare = find.byKey(const ValueKey('bil-smart-plan-review-draft'));
      await tester.ensureVisible(prepare);
      await tester.tap(prepare);
      final approve = find.widgetWithText(FilledButton, 'Approve and activate');
      await _until(tester, () => approve.evaluate().isNotEmpty);
      final before = (await tester.runAsync(
        () => repository().readFor(_owner),
      ))!;
      const changed = DietaryPreferences(
        allergens: {DietaryAllergen.milk, DietaryAllergen.egg},
      );
      await tester.runAsync(
        () => preferences.set(DietaryPreferences.storageKey, changed.encode()),
      );
      final currentDietary = await tester.runAsync(
        () => container.read(dietaryPreferencesRepositoryProvider).read(),
      );
      expect(currentDietary!.allergens, changed.allergens);
      await tester.runAsync(
        () => expectLater(
          const BilSmartPlanCatalog().validate(before, currentDietary),
          throwsStateError,
        ),
      );
      await tester.ensureVisible(approve);
      await tester.tap(approve);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await _until(
        tester,
        () => tester
            .widget<PopupMenuButton<String>>(
              find.byKey(const ValueKey('bil-smart-plan-options')),
            )
            .enabled,
      );
      expect(preferences.planCommits, 1);
      expect(
        (await tester.runAsync(() => repository().readFor(_owner)))!.encode(),
        before.encode(),
      );
      final page = find.byType(ListView).first;
      await tester.drag(page, const Offset(0, 1200));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('bil-smart-plan-error')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await mount(tester, expectCatalogReview: true);
      expect(
        find.byKey(const ValueKey('bil-smart-plan-catalog-review')),
        findsOneWidget,
      );
      expect(approve, findsNothing);
      expect(preferences.planCommits, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('unresolved committed readback never performs another write', (
    tester,
  ) async {
    await mount(tester);
    await _openAndFill(tester, exactReported: true);
    preferences.failNextCommittedReadback = true;
    await _submit(tester, diagnostics: preferences);
    expect(preferences.planCommits, 1);
    preferences.failPlanReads = 10;
    await _retry(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bil-smart-plan-error')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('bil-smart-plan-review-draft')),
      findsNothing,
    );
    expect(preferences.planCommits, 1);
    preferences.failPlanReads = 0;
    await _retry(tester);
    await _until(
      tester,
      () =>
          find.byKey(const ValueKey('bil-smart-plan-error')).evaluate().isEmpty,
    );
    expect(preferences.planCommits, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Gym75 month safety refusal explains review and preserves choices without age bypass',
    (tester) async {
      await tester.runAsync(
        () => UserProfileRepository(db).save(
          gender: 'male',
          age: 17,
          height: 170,
          currentWeight: 70,
          targetWeight: 70,
          activityLevel: 'lightly_active',
          exercises: false,
        ),
      );
      await mount(tester);
      await _openAndFill(tester, exactReported: true);
      await _submit(tester, diagnostics: preferences);
      expect(
        find.text(
          'This plan needs a safety review. Review your age, dietary restrictions and training availability before continuing.',
        ),
        findsOneWidget,
      );
      expect(preferences.planCommits, 0);
      expect(await tester.runAsync(() => repository().readFor(_owner)), isNull);
      await _retry(tester);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButtonFormField<BilPlanHorizon>>(
              find.byType(DropdownButtonFormField<BilPlanHorizon>),
            )
            .initialValue,
        BilPlanHorizon.month,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<BilPlanEnvironment>>(
              find.byType(DropdownButtonFormField<BilPlanEnvironment>),
            )
            .initialValue,
        BilPlanEnvironment.gym,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<int>>(_numberField('minutes'))
            .initialValue,
        75,
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, _adult),
            )
            .value,
        isTrue,
      );
      expect(
        (await tester.runAsync(
          () => UserProfileRepository(db).getProfile(),
        ))!.age,
        17,
      );
      expect(preferences.planCommits, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  Future<void> menuAction(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const ValueKey('bil-smart-plan-options')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(label).last);
    await tester.tap(find.text(label).last);
    await tester.pump(const Duration(milliseconds: 350));
    await _until(tester, () {
      final menu = find.byKey(const ValueKey('bil-smart-plan-options'));
      return menu.evaluate().isNotEmpty &&
          tester.widget<PopupMenuButton<String>>(menu).enabled;
    });
  }

  testWidgets(
    'successful explicit Refresh retires failed creation before unrelated load error Retry',
    (tester) async {
      final before = await tester.runAsync(seedApproved);
      await mount(tester);
      await _openAndFill(tester, replacement: true);
      preferences.failDietaryReads = 1;
      await _submit(tester, diagnostics: preferences);
      await menuAction(tester, 'Refresh');
      await _until(
        tester,
        () => find
            .byKey(const ValueKey('bil-smart-plan-error'))
            .evaluate()
            .isEmpty,
      );
      preferences.failDietaryReads = 1;
      await menuAction(tester, 'Refresh');
      await _until(
        tester,
        () => find
            .byKey(const ValueKey('bil-smart-plan-error'))
            .evaluate()
            .isNotEmpty,
      );
      await _retry(tester);
      await _until(
        tester,
        () => find
            .byKey(const ValueKey('bil-smart-plan-error'))
            .evaluate()
            .isEmpty,
      );
      expect(
        find.byKey(const ValueKey('bil-smart-plan-review-draft')),
        findsNothing,
      );
      expect(
        (await tester.runAsync(() => repository().readFor(_owner)))!.encode(),
        before!.encode(),
      );
      expect(preferences.planCommits, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'unrelated Pause failure Retry never reopens an earlier creation form',
    (tester) async {
      final before = await tester.runAsync(seedApproved);
      await mount(tester);
      await _openAndFill(tester, replacement: true);
      preferences.failDietaryReads = 1;
      await _submit(tester, diagnostics: preferences);
      preferences.failDietaryReads = 1;
      await menuAction(tester, 'Pause plan');
      expect(find.text('Confirm plan change'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await _until(
        tester,
        () =>
            find
                .byKey(const ValueKey('bil-smart-plan-error'))
                .evaluate()
                .isNotEmpty &&
            find.text('Confirm plan change').evaluate().isEmpty,
      );
      await _retry(tester);
      await _until(
        tester,
        () => find
            .byKey(const ValueKey('bil-smart-plan-error'))
            .evaluate()
            .isEmpty,
      );
      expect(
        find.byKey(const ValueKey('bil-smart-plan-review-draft')),
        findsNothing,
      );
      expect(
        (await tester.runAsync(() => repository().readFor(_owner)))!.encode(),
        before!.encode(),
      );
      expect(
        (await tester.runAsync(() => repository().readFor(_owner)))!.status,
        BilPlanStatus.active,
      );
      expect(preferences.planCommits, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets(
      '${locale.languageCode} paused plan confirms Resume and Cancel preserves it',
      (tester) async {
        final active = (await tester.runAsync(seedApproved))!;
        final paused = await tester.runAsync(
          () => repository().save(
            active.withStatus(BilPlanStatus.paused, _now),
            expectedRevision: active.revision,
          ),
        );
        preferences.planCommits = 0;
        await mount(tester, locale: locale);
        final resume = find.widgetWithText(
          FilledButton,
          locale.languageCode == 'ar' ? 'استئناف الخطة' : 'Resume plan',
        );
        await tester.ensureVisible(resume);
        await tester.tap(resume);
        await tester.pumpAndSettle();
        expect(
          find.text(
            locale.languageCode == 'ar'
                ? 'استئناف هذه الخطة المتوقفة مؤقتًا؟ تبقى الوجبات مقترحات فقط ولن يُسجّل أي شيء تلقائيًا.'
                : 'Resume this paused plan? Meals remain suggestions; nothing is logged automatically.',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Activate this draft? Meals remain suggestions; nothing is logged automatically.',
          ),
          findsNothing,
        );
        await tester.tap(
          find
              .widgetWithText(
                TextButton,
                locale.languageCode == 'ar' ? 'إلغاء' : 'Cancel',
              )
              .last,
        );
        await tester.pumpAndSettle();
        expect(
          (await tester.runAsync(() => repository().readFor(_owner)))!.encode(),
          paused!.encode(),
        );
        expect(preferences.planCommits, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  Future<void> mountTool(
    WidgetTester tester,
    List<BilActionReceipt?> receipts,
  ) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Center(
              child: FilledButton(
                key: const ValueKey('launch-tool-plan'),
                onPressed: () async {
                  final result = await context.push<BilActionReceipt>(
                    '/tool-plan',
                    extra: const BilSmartPlanToolRequest(
                      'create_smart_plan_draft',
                      {'horizon': 'month', 'focus': 'combined'},
                    ),
                  );
                  receipts.add(result);
                },
                child: const Text('Open native plan tool'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/tool-plan',
          builder: (_, state) => BilSmartPlanPage(
            toolRequest: state.extra! as BilSmartPlanToolRequest,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: BilFlagshipTheme.light(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('launch-tool-plan')));
    await _until(
      tester,
      () => find
          .byKey(const ValueKey('bil-smart-plan-review-draft'))
          .evaluate()
          .isNotEmpty,
    );
  }

  for (final existing in [false, true]) {
    testWidgets(
      'native toolRequest recovered commit returns exact receipt once existing=$existing',
      (tester) async {
        final before = existing ? await tester.runAsync(seedApproved) : null;
        final receipts = <BilActionReceipt?>[];
        await mountTool(tester, receipts);
        await _openAndFill(tester, exactReported: true, alreadyOpen: true);
        preferences.failNextCommittedReadback = true;
        await _submit(tester, diagnostics: preferences);
        final stored = existing
            ? await tester.runAsync(() => repository().readDraft(_owner))
            : await tester.runAsync(() => repository().readFor(_owner));
        expect(stored, isNotNull);
        expect(preferences.planCommits, 1);
        expect(receipts, isEmpty);
        // An unavailable recovery read cannot manufacture a tool receipt.
        preferences.failPlanReads = 1;
        await _retry(tester);
        await tester.pumpAndSettle();
        expect(receipts, isEmpty);
        expect(preferences.planCommits, 1);
        expect(
          find.byKey(const ValueKey('bil-smart-plan-error')),
          findsOneWidget,
        );
        await _retry(tester);
        await _until(tester, () => receipts.length == 1);
        expect(receipts.single, isNotNull);
        final receipt = receipts.single!;
        expect(receipt.verified, isTrue);
        expect(receipt.committed, isTrue);
        expect(receipt.toolId, 'create_smart_plan_draft');
        expect(receipt.entityType, 'smart_plan');
        expect(receipt.entityId, stored!.id);
        expect(receipt.actionId, stored.id);
        expect(receipt.after['revision'], stored.revision);
        expect(preferences.planCommits, 1);
        expect(
          (existing
                  ? await tester.runAsync(() => repository().readDraft(_owner))
                  : await tester.runAsync(() => repository().readFor(_owner)))!
              .encode(),
          stored.encode(),
        );
        if (existing) {
          expect(
            (await tester.runAsync(
              () => repository().readFor(_owner),
            ))!.encode(),
            before!.encode(),
          );
        }
        await tester.pump();
        expect(receipts.length, 1);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'native toolRequest A to B to A retires held recovery without stale receipt',
    (tester) async {
      final receipts = <BilActionReceipt?>[];
      await mountTool(tester, receipts);
      await _openAndFill(tester, exactReported: true, alreadyOpen: true);
      preferences.failNextCommittedReadback = true;
      await _submit(tester, diagnostics: preferences);
      expect(preferences.planCommits, 1);
      final held = Completer<void>();
      preferences.holdNextPlanRead = held;
      await _retry(tester);
      await tester.pump();
      expect(
        preferences.holdNextPlanRead,
        isNull,
        reason: 'Recovery entered the exact held read.',
      );
      container.updateOverrides([
        databaseProvider.overrideWithValue(db),
        preferencesRepositoryProvider.overrideWithValue(preferences),
        verifiedEntitlementOwnerIdProvider.overrideWithValue(
          'synthetic-owner-B',
        ),
        verifiedSubscriptionAccessProvider.overrideWithValue(
          const AsyncLoading(),
        ),
        bilSmartPlanClockProvider.overrideWithValue(() => _now),
      ]);
      await tester.pump();
      expect(
        container.read(verifiedEntitlementOwnerIdProvider),
        'synthetic-owner-B',
      );
      container.updateOverrides([
        databaseProvider.overrideWithValue(db),
        preferencesRepositoryProvider.overrideWithValue(preferences),
        verifiedEntitlementOwnerIdProvider.overrideWithValue(_owner),
        verifiedSubscriptionAccessProvider.overrideWithValue(
          AsyncData(
            SubscriptionState(
              plan: CommercePlan.premium,
              entitlements: const {},
              authority: EntitlementAuthority.verifiedServer,
              isPurchasable: false,
              canRestorePurchases: false,
            ),
          ),
        ),
        bilSmartPlanClockProvider.overrideWithValue(() => _now),
      ]);
      await tester.pump();
      held.complete();
      await _until(
        tester,
        () =>
            find
                .byKey(const ValueKey('bil-smart-plan-tabs'))
                .evaluate()
                .isNotEmpty &&
            find
                .byKey(const ValueKey('bil-smart-plan-error'))
                .evaluate()
                .isEmpty,
      );
      expect(receipts, isEmpty);
      expect(preferences.planCommits, 1);
      expect(
        await tester.runAsync(() => repository().readFor(_owner)),
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'A to B to A retires failed choices without leaking or saving them',
    (tester) async {
      await mount(tester);
      await _openAndFill(tester);
      preferences.failDietaryReads = 1;
      await _submit(tester, diagnostics: preferences);
      container.updateOverrides([
        databaseProvider.overrideWithValue(db),
        preferencesRepositoryProvider.overrideWithValue(preferences),
        verifiedEntitlementOwnerIdProvider.overrideWithValue(
          'synthetic-owner-B',
        ),
        verifiedSubscriptionAccessProvider.overrideWithValue(
          const AsyncLoading(),
        ),
        bilSmartPlanClockProvider.overrideWithValue(() => _now),
      ]);
      await tester.pump();
      expect(
        container.read(verifiedEntitlementOwnerIdProvider),
        'synthetic-owner-B',
      );
      container.updateOverrides([
        databaseProvider.overrideWithValue(db),
        preferencesRepositoryProvider.overrideWithValue(preferences),
        verifiedEntitlementOwnerIdProvider.overrideWithValue(_owner),
        verifiedSubscriptionAccessProvider.overrideWithValue(
          AsyncData(
            SubscriptionState(
              plan: CommercePlan.premium,
              entitlements: const {},
              authority: EntitlementAuthority.verifiedServer,
              isPurchasable: false,
              canRestorePurchases: false,
            ),
          ),
        ),
        bilSmartPlanClockProvider.overrideWithValue(() => _now),
      ]);
      await _until(
        tester,
        () => find
            .byKey(const ValueKey('bil-smart-plan-create'))
            .evaluate()
            .isNotEmpty,
      );
      await tester.tap(find.byKey(const ValueKey('bil-smart-plan-create')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButtonFormField<BilPlanHorizon>>(
              find.byType(DropdownButtonFormField<BilPlanHorizon>),
            )
            .initialValue,
        isNull,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<BilPlanExperience>>(
              find.byType(DropdownButtonFormField<BilPlanExperience>),
            )
            .initialValue,
        isNull,
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, _adult),
            )
            .value,
        isFalse,
      );
      expect(preferences.planCommits, 0);
      expect(await tester.runAsync(() => repository().readFor(_owner)), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  _registerPlanChoiceValidationTests(
    mount: mount,
    database: () => db,
    preferences: () => preferences,
    container: () => container,
    repository: repository,
  );
}
