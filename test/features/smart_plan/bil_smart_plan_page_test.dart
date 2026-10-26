import '../../support/bil_waiting_indicators.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_coach.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/shared/widgets/bil_pearl_material.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_catalog.dart';
import 'package:body_intelligence_log/features/nutrition/domain/dietary_preferences.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/smart_plan/data/bil_smart_plan_repository.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan_engine.dart';
import 'package:body_intelligence_log/features/smart_plan/presentation/bil_smart_plan_page.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../visual_closure/visual_evidence_font.dart';
import 'dart:io';

// The complete candidate suite forces this to 1. Only the separate legacy
// code-only partition suppresses PNG operations; all behavior still runs.
bool get _capturePlanGoldens =>
    Platform.environment['BIL_CAPTURE_SMART_PLAN_GOLDENS'] != '0';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadVisualEvidenceFont);
  final now = DateTime(2026, 10, 22, 12);
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'owner-123',
    );
    await BilSmartPlanRepository(
      preferences: PreferencesRepository(db),
      currentOwnerId: () => 'owner-123',
    ).save(
      const BilSmartPlanEngine().generate(
        BilPlanCreationRequest(
          ownerId: 'owner-123',
          planId: 'plan-123',
          startOn: now,
          horizon: BilPlanHorizon.month,
          focus: BilPlanFocus.combined,
          workoutsPerWeek: 3,
          confirmedPreferences: true,
          adultConfirmed: true,
          workoutCatalog: await const BilSmartPlanCatalog().gymSessions(
            sessionMinutes: 35,
          ),
          recipeCatalog: const BilSmartPlanCatalog().recipes(
            dietary: const DietaryPreferences(),
          ),
        ),
        now,
      ),
      expectedRevision: 0,
    );
  });
  tearDown(() => db.close());
  Future<void> pump(
    WidgetTester tester,
    String locale,
    double width,
    double scale, {
    bool privacyOnly = false,
    bool premium = true,
    BilSmartPlanToolRequest? toolRequest,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = locale == 'ar' ? 'NotoArabicEvidence' : 'RobotoEvidence';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          verifiedEntitlementOwnerIdProvider.overrideWithValue('owner-123'),
          verifiedSubscriptionAccessProvider.overrideWithValue(
            AsyncData(
              SubscriptionState(
                plan: premium ? CommercePlan.premium : CommercePlan.free,
                entitlements: const {},
                authority: EntitlementAuthority.verifiedServer,
                isPurchasable: false,
                canRestorePurchases: false,
                currentPeriodEndsAt: DateTime(2026, 12, 1),
              ),
            ),
          ),
          bilSmartPlanClockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: BilLocalePolicy.localeFromTag(locale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          theme: visualEvidenceTheme(
            BilFlagshipTheme.light(isArabic: locale == 'ar'),
            fontFamily: font,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: visualEvidenceTextSurface(child, fontFamily: font),
          ),
          home: BilSmartPlanPage(
            privacyOnly: privacyOnly,
            toolRequest: toolRequest,
          ),
        ),
      ),
    );
    // Asset bundle reads use actual I/O; service tests and this UI exercise the
    // real released catalog rather than replacing it with a synthetic success.
    await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump();
        if ((privacyOnly &&
                find
                    .byKey(const ValueKey('bil-smart-plan-data-management'))
                    .evaluate()
                    .isNotEmpty &&
                bilWaitingIndicators().evaluate().isEmpty) ||
            find
                .byKey(const ValueKey('bil-smart-plan-tabs'))
                .evaluate()
                .isNotEmpty ||
            find
                .byKey(const ValueKey('bil-smart-plan-create'))
                .evaluate()
                .isNotEmpty ||
            find
                .byKey(const ValueKey('bil-smart-plan-error'))
                .evaluate()
                .isNotEmpty ||
            find
                .byKey(const ValueKey('bil-smart-plan-catalog-review'))
                .evaluate()
                .isNotEmpty) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(bilWaitingIndicators(), findsNothing);
  }

  for (final language in ['en', 'ar']) {
    testWidgets(
      'replacement $language reuses exact saved setup without reusing safety confirmation',
      (tester) async {
        final saved = PreferencesRepository(db);
        final repository = BilSmartPlanRepository(
          preferences: saved,
          currentOwnerId: () => 'owner-123',
        );
        final plan = (await tester.runAsync(() async {
          final plan = const BilSmartPlanEngine()
              .generate(
                BilPlanCreationRequest(
                  ownerId: 'owner-123',
                  planId: 'plan-reuse',
                  startOn: now,
                  horizon: BilPlanHorizon.threeMonths,
                  focus: BilPlanFocus.training,
                  workoutsPerWeek: 4,
                  confirmedPreferences: true,
                  adultConfirmed: true,
                  setup: BilPlanSetup(
                    environment: BilPlanEnvironment.gym,
                    experience: BilPlanExperience.regular,
                    sessionMinutes: 120,
                    equipment: const ['gym'],
                    preferredTime: '19:30',
                  ),
                  workoutCatalog: await const BilSmartPlanCatalog().gymSessions(
                    sessionMinutes: 120,
                  ),
                  recipeCatalog: const [],
                ),
                now,
              )
              .withStatus(BilPlanStatus.active, now);
          await saved.set(repository.storageKey('owner-123'), plan.encode());
          return plan;
        }))!;
        await pump(tester, language, 390, 1);
        await tester.tap(find.byKey(const ValueKey('bil-smart-plan-options')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(
            language == 'ar' ? 'إنشاء مسودة أخرى' : 'Create another draft',
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pumpAndSettle();
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
          BilPlanFocus.training,
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
              .widget<DropdownButtonFormField<String>>(
                find.byType(DropdownButtonFormField<String>),
              )
              .initialValue,
          '19:30',
        );
        expect(tester.widgetList<Slider>(find.byType(Slider)).first.value, 120);
        expect(
          tester
              .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
              .value,
          isFalse,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('bil-smart-plan-review-draft')),
              )
              .onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
        Navigator.of(
          tester.element(
            find.byKey(const ValueKey('bil-smart-plan-review-draft')),
          ),
        ).pop();
        await tester.pumpAndSettle();
        expect(
          (await tester.runAsync(
            () => repository.readFor('owner-123'),
          ))!.encode(),
          plan.encode(),
        );
        expect(
          await tester.runAsync(() => repository.readDraft('owner-123')),
          isNull,
        );
      },
    );
  }

  for (final locale in ['fr', 'de', 'fa', 'pt-BR', 'zh-Hant']) {
    testWidgets(
      'Smart Plan $locale translates the real plan surface at large text',
      (tester) async {
        await pump(tester, locale, 320, 2);
        expect(
          find.text(RuntimeCopy.resolve('My Plan', locale)!),
          findsOneWidget,
        );
        expect(find.text('My Plan'), findsNothing);
        expect(
          Directionality.of(tester.element(find.byType(BilSmartPlanPage))),
          BilLocalePolicy.directionFor(BilLocalePolicy.localeFromTag(locale)),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'creation uses shared modal, app fields and explicit approval at large text',
    (tester) async {
      final repo = BilSmartPlanRepository(
        preferences: PreferencesRepository(db),
        currentOwnerId: () => 'owner-123',
      );
      await repo.removeWithConfirmation(
        owner: 'owner-123',
        expectedId: 'plan-123',
        expectedRevision: 1,
      );
      await pump(tester, 'ar', 320, 2);
      await tester.ensureVisible(
        find.byKey(const ValueKey('bil-smart-plan-create')),
      );
      await tester.tap(find.byKey(const ValueKey('bil-smart-plan-create')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byType(DropdownButtonFormField<BilPlanHorizon>),
        findsOneWidget,
      );
      final prepare = find.byKey(const ValueKey('bil-smart-plan-review-draft'));
      await tester.ensureVisible(prepare);
      expect(tester.widget<FilledButton>(prepare).onPressed, isNull);
      expect(await repo.readFor('owner-123'), isNull);
      Navigator.of(tester.element(prepare)).pop();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'real local journey creates a draft, activates, records actual duration and undoes only that record',
    (tester) async {
      final repo = BilSmartPlanRepository(
        preferences: PreferencesRepository(db),
        currentOwnerId: () => 'owner-123',
      );
      await repo.removeWithConfirmation(
        owner: 'owner-123',
        expectedId: 'plan-123',
        expectedRevision: 1,
      );
      await pump(tester, 'en', 390, 1);
      await tester.tap(find.byKey(const ValueKey('bil-smart-plan-create')));
      await tester.pumpAndSettle();
      final experience = find.byType(
        DropdownButtonFormField<BilPlanExperience>,
      );
      await tester.ensureVisible(experience);
      await tester.tap(experience);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beginner').last);
      await tester.pumpAndSettle();
      final adult = find.byType(CheckboxListTile).first;
      await tester.ensureVisible(adult);
      await tester.tap(adult);
      await tester.pump();
      final prepare = find.byKey(const ValueKey('bil-smart-plan-review-draft'));
      await tester.ensureVisible(prepare);
      await tester.tap(prepare);
      Future<void> settleSaved() async {
        await tester.runAsync(() async {
          final end = DateTime.now().add(const Duration(seconds: 10));
          while (DateTime.now().isBefore(end)) {
            await tester.pump(const Duration(milliseconds: 20));
            if (find
                    .byKey(const ValueKey('bil-smart-plan-tabs'))
                    .evaluate()
                    .isNotEmpty &&
                tester
                    .widget<PopupMenuButton<String>>(
                      find.byKey(const ValueKey('bil-smart-plan-options')),
                    )
                    .enabled &&
                find.byType(BilPearlMaterialAlertDialog).evaluate().isEmpty) {
              break;
            }
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.pumpAndSettle();
      }

      await settleSaved();
      debugPrint('Smart Plan journey: persisted step verified');
      expect(
        (await tester.runAsync(() => repo.readFor('owner-123')))!.status,
        BilPlanStatus.draft,
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Approve and activate'),
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Approve and activate'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await settleSaved();
      debugPrint('Smart Plan journey: persisted step verified');
      expect(
        (await tester.runAsync(() => repo.readFor('owner-123')))!.status,
        BilPlanStatus.active,
      );
      final finish = find.byKey(
        const ValueKey('bil-smart-plan-complete-workout'),
      );
      await tester.ensureVisible(finish);
      await tester.tap(finish);
      await tester.pumpAndSettle();
      // Confirming an empty duration stays in the same app confirmation surface.
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pump();
      expect(find.text('Enter 5–120 minutes.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '27');
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await settleSaved();
      debugPrint('Smart Plan journey: persisted step verified');
      expect(
        (await tester.runAsync(
          () => repo.readFor('owner-123'),
        ))!.onDate(now)!.workout!.completed,
        isTrue,
      );
      final daily = DailyLogRepository(db);
      expect(
        (await tester.runAsync(() => daily.getForDay(now)))!.exerciseNotes,
        contains('27'),
      );
      expect(await tester.runAsync(() => db.select(db.meals).get()), isEmpty);
      await tester.ensureVisible(finish);
      await tester.tap(finish);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await settleSaved();
      debugPrint('Smart Plan journey: persisted step verified');
      expect(
        (await tester.runAsync(
          () => repo.readFor('owner-123'),
        ))!.onDate(now)!.workout!.completed,
        isFalse,
      );
      expect(
        (await tester.runAsync(() => daily.getForDay(now)))!.exerciseNotes ??
            '',
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'cloud controls remain reachable after the local plan is deleted',
    (tester) async {
      final repository = BilSmartPlanRepository(
        preferences: PreferencesRepository(db),
        currentOwnerId: () => 'owner-123',
      );
      await repository.removeWithConfirmation(
        owner: 'owner-123',
        expectedId: 'plan-123',
        expectedRevision: 1,
      );
      await pump(tester, 'en', 390, 1);
      await tester.tap(find.byKey(const ValueKey('bil-smart-plan-options')));
      await tester.pumpAndSettle();
      const enabled = bool.fromEnvironment('BIL_SMART_PLAN_CLOUD_ENABLED');
      expect(find.text('Sync plan'), enabled ? findsOneWidget : findsNothing);
      expect(find.text('Stop backup'), enabled ? findsOneWidget : findsNothing);
      expect(find.text('Delete plan'), findsNothing);
      if (enabled) {
        await tester.tap(find.text('Sync plan'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Supabase will store your plan'),
          findsOneWidget,
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(
          await tester.runAsync(() => repository.readFor('owner-123')),
          isNull,
        );
        expect(
          await tester.runAsync(
            () =>
                repository.preferences.get(repository.deletionKey('owner-123')),
          ),
          isNotNull,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  Future<void> waitForSurface(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      final until = DateTime.now().add(const Duration(seconds: 15));
      while (finder.evaluate().isEmpty && DateTime.now().isBefore(until)) {
        await tester.pump(const Duration(milliseconds: 20));
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    expect(finder, findsWidgets);
    await tester.pumpAndSettle();
  }

  Future<BilSmartPlanRepository> activePlan() async {
    final repo = BilSmartPlanRepository(
      preferences: PreferencesRepository(db),
      currentOwnerId: () => 'owner-123',
    );
    final old = (await repo.readFor('owner-123'))!;
    await repo.save(
      old.withStatus(BilPlanStatus.active, now),
      expectedRevision: old.revision,
    );
    return repo;
  }

  testWidgets(
    'extended context is separately disclosed, decline writes nothing and revocation clears both scopes',
    (tester) async {
      await pump(tester, 'en', 390, 1);
      Future<void> openDetails() async {
        await tester.tap(find.byKey(const ValueKey('bil-smart-plan-options')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Coach context details'));
        await tester.pumpAndSettle();
      }

      await openDetails();
      expect(find.textContaining('seven-day training window'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      final prefs = PreferencesRepository(db);
      expect(
        await tester.runAsync(() => prefs.get('smartPlan.shareWithCoach.v2')),
        isNull,
      );
      await openDetails();
      await tester.tap(
        find.byKey(const ValueKey('bil-smart-plan-extended-context-confirm')),
      );
      await waitForSurface(
        tester,
        find.byKey(const ValueKey('bil-smart-plan-tabs')),
      );
      expect(
        await tester.runAsync(() => prefs.get('smartPlan.shareWithCoach.v1')),
        'true',
      );
      expect(
        await tester.runAsync(() => prefs.get('smartPlan.shareWithCoach.v2')),
        'true',
      );
      await tester.tap(find.byKey(const ValueKey('bil-smart-plan-options')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coach plan memory'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Stop sharing'));
      await waitForSurface(
        tester,
        find.byKey(const ValueKey('bil-smart-plan-tabs')),
      );
      expect(
        await tester.runAsync(() => prefs.get('smartPlan.shareWithCoach.v1')),
        'false',
      );
      expect(
        await tester.runAsync(() => prefs.get('smartPlan.shareWithCoach.v2')),
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'native day preview reads the requested civil date and cannot silently show today instead',
    (tester) async {
      await activePlan();
      await pump(
        tester,
        'en',
        390,
        1,
        toolRequest: const BilSmartPlanToolRequest('preview_smart_plan_day', {
          'planId': 'plan-123',
          'revision': 2,
          'date': '2026-10-23',
        }),
      );
      expect(find.text('Selected day'), findsNWidgets(2));
      expect(find.text('2026-10-23'), findsOneWidget);
      expect(find.text('Recovery / no workout scheduled'), findsOneWidget);
      expect(
        await tester.runAsync(() => db.select(db.dailyLogs).get()),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'real meal replacement previews first and only confirms a saved plan revision, never a food log',
    (tester) async {
      final repo = await activePlan();
      final before = (await repo.readFor('owner-123'))!;
      await pump(tester, 'en', 390, 1);
      final mealIcon = find.byIcon(Icons.restaurant_menu_rounded).first;
      await tester.ensureVisible(mealIcon);
      await tester.pumpAndSettle();
      await tester.tap(mealIcon);
      final replacement = find.byKey(
        const ValueKey('bil-smart-plan-meal-replacement'),
      );
      await waitForSurface(tester, replacement);
      final field = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: replacement,
          matching: find.byType(DropdownButton<String>),
        ),
      );
      final selected = field.items!.first.value!;
      await tester.ensureVisible(replacement);
      await tester.tap(replacement);
      await tester.pumpAndSettle();
      final option = field.items!.first.child;
      await tester.tap(find.text((option as Text).data!).last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Preview replacement'));
      await tester.tap(find.text('Preview replacement'));
      await tester.pumpAndSettle();
      expect(
        (await tester.runAsync(() => repo.readFor('owner-123')))!.encode(),
        before.encode(),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      // Completion includes real SQLite I/O. Wait for the actual busy gate to
      // reopen; pumping only fake time can strand a still-pending disk write.
      await waitForSurface(
        tester,
        find.byWidgetPredicate(
          (widget) => widget is PopupMenuButton<String> && widget.enabled,
        ),
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, 1100));
      await waitForSurface(
        tester,
        find.byKey(const ValueKey('bil-smart-plan-tabs')),
      );
      final saved = (await tester.runAsync(() => repo.readFor('owner-123')))!;
      expect(saved.revision, before.revision + 1);
      expect(saved.days.first.meals.first.recipeId, selected);
      expect(saved.changes.first.reason, BilPlanChangeReason.mealSwap);
      expect(await tester.runAsync(() => db.select(db.meals).get()), isEmpty);
      expect(
        await tester.runAsync(() => db.select(db.dailyLogs).get()),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Free can manage plan privacy without obtaining paid plan actions',
    (tester) async {
      await pump(tester, 'en', 390, 1, privacyOnly: true, premium: false);
      expect(find.text('Export plan'), findsOneWidget);
      expect(find.text('Delete plan'), findsOneWidget);
      expect(find.text('Create plan'), findsNothing);
      expect(
        find.byKey(const ValueKey('bil-smart-plan-options')),
        findsNothing,
      );
      expect(find.text('Sync plan'), findsNothing);
      await tester.tap(find.text('Delete plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      final repository = BilSmartPlanRepository(
        preferences: PreferencesRepository(db),
        currentOwnerId: () => 'owner-123',
      );
      expect(
        await tester.runAsync(() => repository.readFor('owner-123')),
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  Future<BilSmartPlan> waitForRevision(
    WidgetTester tester,
    BilSmartPlanRepository repo,
    int revision,
  ) async {
    BilSmartPlan? saved;
    await tester.runAsync(() async {
      final until = DateTime.now().add(const Duration(seconds: 15));
      do {
        await tester.pump(const Duration(milliseconds: 20));
        final options = find.byKey(const ValueKey('bil-smart-plan-options'));
        final idle =
            options.evaluate().isNotEmpty &&
            tester.widget<PopupMenuButton<String>>(options).enabled;
        if (idle) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      } while (DateTime.now().isBefore(until));
      saved = await repo.readFor('owner-123');
    });
    expect(saved?.revision, revision);
    expect(
      tester
          .widget<PopupMenuButton<String>>(
            find.byKey(const ValueKey('bil-smart-plan-options')),
          )
          .enabled,
      isTrue,
    );
    await tester.pumpAndSettle();
    return saved!;
  }

  for (final locale in ['en', 'ar']) {
    testWidgets(
      'pending $locale draft reviews separately then archives only after approval',
      (tester) async {
        final prepared = await tester.runAsync(() async {
          final repo = await activePlan();
          final before = (await repo.readFor('owner-123'))!;
          final replacement = const BilSmartPlanEngine().generate(
            BilPlanCreationRequest(
              ownerId: 'owner-123',
              planId: 'replacement-plan',
              startOn: now,
              horizon: BilPlanHorizon.week,
              focus: BilPlanFocus.training,
              workoutsPerWeek: 3,
              confirmedPreferences: true,
              adultConfirmed: true,
              workoutCatalog: await const BilSmartPlanCatalog().gymSessions(
                sessionMinutes: 30,
              ),
              recipeCatalog: const [],
            ),
            now,
          );
          await repo.stageDraft(replacement, approved: before);
          return (repo, before);
        });
        final (repo, before) = prepared!;
        await pump(tester, locale, 390, 1);
        await tester.tap(find.byKey(const ValueKey('bil-smart-plan-options')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(
            locale == 'ar' ? 'مراجعة المسودة المعلقة' : 'Review pending draft',
          ),
        );
        await waitForSurface(
          tester,
          find.text(
            locale == 'ar'
                ? 'تبقى خطتك الحالية نشطة حتى توافق على هذه المسودة.'
                : 'Your current plan stays active until you approve this draft.',
          ),
        );
        expect(
          (await tester.runAsync(() => repo.readFor('owner-123')))!.encode(),
          before.encode(),
        );
        if (_capturePlanGoldens) {
          await settleVisualAssetImages(tester);
          await expectLater(
            find.byType(BilSmartPlanPage),
            matchesGoldenFile('goldens/smart_plan_pending_$locale.png'),
          );
        }
        final approve = find.widgetWithText(
          FilledButton,
          locale == 'ar' ? 'اعتماد وتفعيل' : 'Approve and activate',
        );
        await tester.ensureVisible(approve);
        await tester.tap(approve);
        await tester.pumpAndSettle();
        expect(
          (await tester.runAsync(() => repo.readFor('owner-123')))!.encode(),
          before.encode(),
        );
        await tester.tap(
          find.widgetWithText(
            FilledButton,
            locale == 'ar' ? 'تأكيد' : 'Confirm',
          ),
        );
        await waitForRevision(tester, repo, 2);
        final saved = (await tester.runAsync(() => repo.readFor('owner-123')))!;
        expect(saved.id, 'replacement-plan');
        expect(saved.status, BilPlanStatus.active);
        expect(
          (await tester.runAsync(
            () => repo.readArchives('owner-123'),
          ))!.single.encode(),
          before.encode(),
        );
        expect(
          await tester.runAsync(() => db.select(db.dailyLogs).get()),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final locale in ['en', 'ar']) {
    testWidgets(
      'real $locale alternative session reviews source movements and saves only after confirmation',
      (tester) async {
        final repo = await activePlan();
        final before = (await repo.readFor('owner-123'))!;
        await pump(tester, locale, 320, 2);
        final open = find.byKey(
          const ValueKey('bil-smart-plan-replace-session'),
        );
        await tester.scrollUntilVisible(
          open,
          170,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(open, findsOneWidget);
        await tester.tap(open);
        final field = find.byKey(
          const ValueKey('bil-smart-plan-alternative-session'),
        );
        await waitForSurface(tester, field);
        expect(find.byType(BilPearlMaterialAlertDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(
          (await tester.runAsync(() => repo.readFor('owner-123')))!.encode(),
          before.encode(),
        );
        final confirm = find.widgetWithText(
          FilledButton,
          locale == 'ar' ? 'تأكيد' : 'Confirm',
        );
        await tester.ensureVisible(confirm);
        await tester.pumpAndSettle();
        await tester.tap(confirm);
        final saved = await waitForRevision(tester, repo, before.revision + 1);
        expect(
          saved.days.first.workout!.templateId,
          isNot(before.days.first.workout!.templateId),
        );
        expect(saved.days.first.workout!.completed, isFalse);
        expect(saved.previousVersion()!.encode(), before.encode());
        expect(saved.changes.first.reason, BilPlanChangeReason.equipment);
        expect(
          await tester.runAsync(() => db.select(db.dailyLogs).get()),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      'real $locale meal date swap keeps diary empty and records a reversible revision',
      (tester) async {
        final repo = await activePlan();
        final initial = (await repo.readFor('owner-123'))!;
        final choices = (await tester.runAsync(
          () => const BilSmartPlanCatalog().sourcedRecipes(
            dietary: const DietaryPreferences(),
          ),
        ))!;
        final source = choices.firstWhere(
          (r) =>
              r.slot == BilPlanMealSlot.breakfast &&
              r.id != initial.days.first.meals.first.recipeId,
        );
        final before = initial.replaceMeal(
          date: now.add(const Duration(days: 1)),
          slot: BilPlanMealSlot.breakfast,
          recipeId: source.id,
          now: now,
        );
        await repo.save(before, expectedRevision: initial.revision);
        await pump(tester, locale, 320, 2);
        final targetSlot = before.days.first.meals.first.slot.name;
        // A stable row key lets scrollUntilVisible build the offscreen tile.
        // A .first finder throws before the 320px/200% scroll can start.
        final meal = find.byKey(ValueKey('bil-smart-plan-meal-$targetSlot'));
        await tester.scrollUntilVisible(
          meal,
          170,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(meal, findsOneWidget);
        await tester.tap(meal);
        final schedule = find.byKey(
          const ValueKey('bil-smart-plan-meal-schedule'),
        );
        await waitForSurface(tester, schedule);
        await tester.ensureVisible(schedule);
        await tester.pumpAndSettle();
        await tester.tap(schedule);
        await tester.pumpAndSettle();
        expect(find.byType(BilPearlMaterialAlertDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(
          (await tester.runAsync(() => repo.readFor('owner-123')))!.encode(),
          before.encode(),
        );
        final confirm = find.widgetWithText(
          FilledButton,
          locale == 'ar' ? 'تأكيد' : 'Confirm',
        );
        await tester.ensureVisible(confirm);
        await tester.pumpAndSettle();
        await tester.tap(confirm);
        final saved = await waitForRevision(tester, repo, before.revision + 1);
        expect(
          saved.days.first.meals.first.recipeId,
          isNot(before.days.first.meals.first.recipeId),
        );
        expect(saved.previousVersion()!.encode(), before.encode());
        expect(await tester.runAsync(() => db.select(db.meals).get()), isEmpty);
        expect(
          await tester.runAsync(() => db.select(db.dailyLogs).get()),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final locale in ['en', 'ar']) {
    for (final size in [(320.0, 2.0), (375.0, 1.3), (414.0, 1.0)]) {
      testWidgets(
        'Smart Plan $locale ${size.$1}px scale ${size.$2} has no overflow or extra bottom navigation',
        (tester) async {
          await pump(tester, locale, size.$1, size.$2);
          expect(tester.takeException(), isNull);
          expect(find.byType(NavigationBar), findsNothing);
          expect(find.byType(BottomNavigationBar), findsNothing);
          expect(
            find.byKey(const ValueKey('bil-smart-plan-tabs')),
            findsOneWidget,
          );
          expect(
            Directionality.of(tester.element(find.byType(BilSmartPlanPage))),
            locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
    testWidgets(
      'Smart Plan $locale uses existing consent surface and decline persists nothing',
      (tester) async {
        await pump(tester, locale, 390, 1);
        await tester.tap(find.byKey(const ValueKey('bil-smart-plan-options')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(
            locale == 'ar' ? 'ذاكرة الخطة للمدرب' : 'Coach plan memory',
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('bil-smart-plan-memory-allow')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await settleVisualAssetImages(tester);
        if (_capturePlanGoldens) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/smart_plan_${locale}_memory.png'),
          );
        }
        await tester.ensureVisible(
          find.byKey(const ValueKey('bil-smart-plan-memory-decline')),
        );
        await tester.tap(
          find.byKey(const ValueKey('bil-smart-plan-memory-decline')),
        );
        await tester.pumpAndSettle();
        expect(
          await PreferencesRepository(db).get('smartPlan.shareWithCoach.v1'),
          isNull,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      'Smart Plan $locale reuses the report flow with plan-specific consent and no implicit submission',
      (tester) async {
        await pump(tester, locale, 390, 1);
        await tester.tap(find.byKey(const ValueKey('bil-smart-plan-options')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(locale == 'ar' ? 'الإبلاغ عن الخطة' : 'Report plan'),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            locale == 'ar' ? 'الإبلاغ عن هذه الخطة' : 'Report this plan',
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('ai-coach-confirm-report')),
              )
              .onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
        if (_capturePlanGoldens) {
          await settleVisualAssetImages(tester);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/smart_plan_${locale}_report.png'),
          );
        }
        await tester.ensureVisible(
          find.byKey(const Key('ai-coach-cancel-report')),
        );
        await tester.tap(find.byKey(const Key('ai-coach-cancel-report')));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      'Smart Plan $locale deletion uses shared confirmation and cancel keeps data',
      (tester) async {
        await pump(tester, locale, 320, 2);
        await tester.tap(find.byKey(const ValueKey('bil-smart-plan-options')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(locale == 'ar' ? 'حذف الخطة' : 'Delete plan'),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BilPearlMaterialAlertDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.widgetWithText(TextButton, locale == 'ar' ? 'إلغاء' : 'Cancel'),
        );
        await tester.tap(
          find.widgetWithText(TextButton, locale == 'ar' ? 'إلغاء' : 'Cancel'),
        );
        await tester.pumpAndSettle();
        expect(
          await BilSmartPlanRepository(
            preferences: PreferencesRepository(db),
            currentOwnerId: () => 'owner-123',
          ).readFor('owner-123'),
          isNotNull,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets('Smart Plan $locale glass layout Golden', (tester) async {
      await pump(tester, locale, 390, 1);
      // Wait for the actual bundled artwork before auditing rendered pixels.
      await settleVisualAssetImages(tester);
      final semantics = tester.ensureSemantics();
      try {
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      } finally {
        semantics.dispose();
      }
      if (_capturePlanGoldens) {
        await expectLater(
          find.byType(BilSmartPlanPage),
          matchesGoldenFile('goldens/smart_plan_${locale}_390.png'),
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
