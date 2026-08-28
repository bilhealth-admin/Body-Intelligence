import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_extended.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/dashboard/presentation/dashboard_preferences_page.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/native.dart';

void main() {
  testWidgets('dashboard customization renders every provider-backed section', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    tester.view.physicalSize = const Size(600, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/dashboard/preferences',
      routes: [
        GoRoute(
          path: '/dashboard/preferences',
          builder: (_, _) => const DashboardPreferencesPage(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          for (final section in DashboardSectionIds.all)
            dashboardSectionVisibleProvider(
              section,
            ).overrideWith((_) => Stream.value(true)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Macros'), findsOneWidget);
    expect(find.byKey(const Key('dashboard-preferences-done')), findsOneWidget);
    expect(DashboardSectionIds.all, hasLength(10));
    expect(DashboardSectionIds.all, isNot(contains('daily_intelligence')));
    for (final section in DashboardSectionIds.all) {
      final sectionFinder = find.byKey(Key('dashboard-section-$section'));
      expect(sectionFinder, findsOneWidget);
      expect(tester.widget<SwitchListTile>(sectionFinder).value, isTrue);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);
  });

  testWidgets('dashboard customization renders all 25 locales with RTL truth', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    tester.view.physicalSize = const Size(600, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            for (final section in DashboardSectionIds.all)
              dashboardSectionVisibleProvider(
                section,
              ).overrideWith((_) => Stream.value(true)),
          ],
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const DashboardPreferencesPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(DashboardPreferencesPage), findsOneWidget);
      final direction = Directionality.of(
        tester.element(find.byType(DashboardPreferencesPage)),
      );
      expect(
        direction,
        AppLocalizations.isRtl(locale) ? TextDirection.rtl : TextDirection.ltr,
        reason: 'direction for $locale',
      );
      expect(tester.takeException(), isNull, reason: 'render for $locale');
      if (!const {'ar', 'en', 'fr', 'es', 'tr'}.contains(locale.languageCode)) {
        final translated = RuntimeCopy.resolve(
          'Customize Today',
          BilLocalePolicy.canonicalTag(locale),
        );
        expect(
          translated,
          isNotNull,
          reason: 'localized dashboard copy for $locale',
        );
        expect(
          translated,
          isNot('Customize Today'),
          reason: 'no English fallback for $locale',
        );
        expect(find.text(translated!), findsOneWidget);
        for (final nutrient in const [
          'Protein',
          'Carbohydrates',
          'Fat',
          'Fiber',
          'Sodium',
          'Potassium',
        ]) {
          final nutrientCopy = RuntimeCopy.resolve(
            nutrient,
            BilLocalePolicy.canonicalTag(locale),
          );
          expect(nutrientCopy, isNotNull, reason: '$nutrient copy for $locale');
          expect(
            ExtendedRuntimeCopy.values[nutrient],
            contains(BilLocalePolicy.canonicalTag(locale)),
            reason: 'direct nutrient entry for $nutrient in $locale',
          );
          // These reviewed locale pairs use the identical scientific term;
          // every other locale must differ from the English source.
          const nutrientIdentityAllowlist = {
            'Protein|id',
            'Protein|ms',
            'Potassium|ms',
          };
          final nutrientIdentity =
              '$nutrient|${BilLocalePolicy.canonicalTag(locale)}';
          if (!nutrientIdentityAllowlist.contains(nutrientIdentity)) {
            expect(
              nutrientCopy,
              isNot(nutrient),
              reason: 'no English nutrient identity for $locale',
            );
          }
        }
        for (final premiumKey in const [
          'Choose the nutrients you want to track as dashboard cards. This is an independent Premium feature.',
          'View Premium plans',
          'Add nutrient goal cards, Premium active',
          'Add nutrient goal cards, locked Premium feature',
        ]) {
          final premiumCopy = RuntimeCopy.resolve(
            premiumKey,
            BilLocalePolicy.canonicalTag(locale),
          );
          expect(
            premiumCopy,
            isNotNull,
            reason: '$premiumKey copy for $locale',
          );
          expect(
            premiumCopy,
            isNot(premiumKey),
            reason: 'no English Premium fallback for $locale',
          );
          expect(
            ExtendedRuntimeCopy.values[premiumKey],
            contains(BilLocalePolicy.canonicalTag(locale)),
            reason: 'direct Premium entry for $premiumKey in $locale',
          );
        }
        for (final surfaceKey in const [
          'Choose what appears on Today. Your data stays saved and every card can be restored at any time.',
          'Choose the information that matters most to you',
          'Calorie focused',
          'Calories consumed, activity, and remaining energy.',
          'Macronutrients focused',
          'Carbs, protein, fat, and remaining calories.',
          'Heart and activity view',
          'Nutrition, activity, and connected health together.',
          'Low carb',
          'Macros, calories, quick logging, and evidence.',
          'Custom',
          'Choose each card below.',
          'Custom cards',
          'AI Coach',
          'Calories',
          'Macros',
          'Activity',
          'Quick log',
          'Discover',
          'Personal intelligence',
          'Progress',
          'Connected health',
          'Body Twin',
          'A private conversation with your health intelligence',
          'Goal, food, exercise, and remaining energy',
          'Macro and nutrient trends',
          'Food, water, and weight shortcuts',
          'Sleep, recipes, workouts, and community',
          'One Best Action, evidence, and Body Twin',
          'Explanations, confidence, and evidence',
          'Measured trends from your saved records',
          'Health sources and synchronization status',
          'Your explainable body model and its evidence',
          'Add nutrient goal cards',
          'Save cards',
          'Loading saved view',
          'Saved view could not be loaded.',
          'Retry subscription check',
          'Loading saved setting',
          'Saved setting could not be loaded. Tap to retry.',
          'Loading saved cards',
          'Cards could not be loaded. Tap to retry.',
          'Restore default view',
          'Done editing',
          'Today preferences could not be saved. Please try again.',
        ]) {
          final surfaceCopy = RuntimeCopy.resolve(
            surfaceKey,
            BilLocalePolicy.canonicalTag(locale),
          );
          expect(surfaceCopy, isNotNull, reason: '$surfaceKey for $locale');
          expect(
            ExtendedRuntimeCopy.values[surfaceKey],
            contains(BilLocalePolicy.canonicalTag(locale)),
            reason: 'direct dashboard entry for $surfaceKey in $locale',
          );
          const identityAllowlist = {'AI Coach', 'Macros', 'Body Twin'};
          if (!identityAllowlist.contains(surfaceKey)) {
            expect(
              surfaceCopy,
              isNot(surfaceKey),
              reason: 'no English dashboard identity for $locale',
            );
          }
        }
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);
  });

  testWidgets('preset manual edit and restore persist atomically', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = PreferencesRepository(database);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: DashboardPreferencesPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('dashboard-preset-calorie')));
    await tester.pump(const Duration(milliseconds: 150));
    expect(await repository.get('dashboard.preset'), 'calorie');
    expect(await repository.get('dashboard.section.calories'), 'true');
    expect(await repository.get('dashboard.section.macros'), 'false');

    final macros = find.byKey(const Key('dashboard-section-macros'));
    await tester.scrollUntilVisible(
      macros,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(macros);
    await tester.pump(const Duration(milliseconds: 150));
    expect(await repository.get('dashboard.preset'), 'custom');
    expect(await repository.get('dashboard.section.macros'), 'true');

    await repository.set('dashboard.nutrientGoalCards', 'fat,fiber');
    final restore = find.text('Restore default view');
    await tester.scrollUntilVisible(
      restore,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(restore);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1800));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('dashboard-preset-carousel')),
      const Offset(-1500, 0),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ListTile>(find.byKey(const Key('dashboard-preset-custom')))
          .trailing,
      isNull,
      reason: 'restored defaults are not a custom preset',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);
    expect(await repository.get('dashboard.preset'), isNull);
    expect(await repository.get('dashboard.section.macros'), isNull);
    expect(await repository.get('dashboard.nutrientGoalCards'), isNull);
    await database.close();
  });

  testWidgets('free nutrient-card crown opens preview then plans', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const DashboardPreferencesPage()),
        GoRoute(
          path: '/plans',
          builder: (_, _) => const Scaffold(body: Text('plans-target')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          verifiedSubscriptionStateProvider.overrideWithValue(
            AsyncData(FreePlan.createState()),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final trigger = find.byKey(const Key('dashboard-add-nutrient-goal-cards'));
    await tester.scrollUntilVisible(
      trigger,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    expect(find.text('Add nutrient goal cards'), findsWidgets);
    await tester.tap(find.text('View Premium plans'));
    await tester.pumpAndSettle();
    expect(find.text('plans-target'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    router.dispose();
    await database.close();
  });

  testWidgets('verified Premium nutrient cards persist as custom dashboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = PreferencesRepository(database);
    final premium = SubscriptionState(
      plan: CommercePlan.pro,
      entitlements: const {CommerceEntitlement.advancedIntelligence},
      authority: EntitlementAuthority.verifiedServer,
      isPurchasable: true,
      canRestorePurchases: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          verifiedSubscriptionStateProvider.overrideWithValue(
            AsyncData(premium),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: DashboardPreferencesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final trigger = find.byKey(const Key('dashboard-add-nutrient-goal-cards'));
    await tester.scrollUntilVisible(
      trigger,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('dashboard-nutrient-goal-protein')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('dashboard-nutrient-goal-carbohydrates')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('dashboard-nutrient-goal-fat')));
    await tester.tap(find.byKey(const Key('dashboard-nutrient-goal-fiber')));
    await tester.tap(find.text('Save cards'));
    await tester.pumpAndSettle();
    expect(await repository.get('dashboard.nutrientGoalCards'), 'fat,fiber');
    expect(await repository.get('dashboard.preset'), 'custom');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await database.close();
  });

  testWidgets('Premium nutrient chooser locks every exit during commit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final pending = Completer<void>();
    final repository = _TestPreferencesRepository(
      database,
      pendingWrite: pending,
    );
    final premium = SubscriptionState(
      plan: CommercePlan.pro,
      entitlements: const {CommerceEntitlement.advancedIntelligence},
      authority: EntitlementAuthority.verifiedServer,
      isPurchasable: true,
      canRestorePurchases: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(repository),
          verifiedSubscriptionStateProvider.overrideWithValue(
            AsyncData(premium),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: DashboardPreferencesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final trigger = find.byKey(const Key('dashboard-add-nutrient-goal-cards'));
    await tester.scrollUntilVisible(
      trigger,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dashboard-nutrient-goal-fat')));
    await tester.tap(find.text('Save cards'));
    await tester.pump();
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const Key('dashboard-nutrient-goal-fat')),
          )
          .onChanged,
      isNull,
    );
    expect(
      tester
          .widgetList<PopScope>(find.byType(PopScope))
          .any((scope) => !scope.canPop),
      isTrue,
    );
    pending.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Save cards'), findsNothing);
  });

  testWidgets('section loading never renders a default switch value', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          verifiedSubscriptionStateProvider.overrideWithValue(
            AsyncData(FreePlan.createState()),
          ),
          dashboardSectionVisibleProvider(
            DashboardSectionIds.calories,
          ).overrideWith(
            (_) => Stream.fromFuture(
              Future<bool>.delayed(const Duration(seconds: 1), () => false),
            ),
          ),
          for (final section in DashboardSectionIds.all)
            if (section != DashboardSectionIds.calories)
              dashboardSectionVisibleProvider(
                section,
              ).overrideWith((_) => Stream.value(true)),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: DashboardPreferencesPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('dashboard-section-calories')), findsNothing);
    expect(find.bySemanticsLabel('Loading saved setting'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('dashboard-section-calories')),
          )
          .value,
      isFalse,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('async failures are explicit and retryable', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = _TestPreferencesRepository(database, failWatch: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(repository),
          verifiedSubscriptionStateProvider.overrideWithValue(
            AsyncValue.error(StateError('offline'), StackTrace.empty),
          ),
          for (final section in DashboardSectionIds.all)
            dashboardSectionVisibleProvider(section).overrideWith(
              (_) => Stream<bool>.error(StateError('read failed')),
            ),
          dashboardNutrientGoalCardsProvider.overrideWith(
            (_) => Stream<Set<String>>.error(StateError('read failed')),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: DashboardPreferencesPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(find.text('Saved view could not be loaded.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('dashboard-section-calories-error')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const Key('dashboard-section-calories-error')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('dashboard-add-nutrient-goal-cards')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.text('Cards could not be loaded. Tap to retry.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);
  });

  testWidgets('subscription verification error offers retry', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          verifiedSubscriptionStateProvider.overrideWithValue(
            AsyncValue.error(StateError('offline'), StackTrace.empty),
          ),
          for (final section in DashboardSectionIds.all)
            dashboardSectionVisibleProvider(
              section,
            ).overrideWith((_) => Stream.value(true)),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: DashboardPreferencesPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byIcon(Icons.refresh_rounded), findsWidgets);
    expect(find.byTooltip('Retry subscription check'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);
  });

  testWidgets('busy save blocks every exit and duplicate submission', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final pending = Completer<void>();
    final repository = _TestPreferencesRepository(
      database,
      pendingWrite: pending,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(repository),
          for (final section in DashboardSectionIds.all)
            dashboardSectionVisibleProvider(
              section,
            ).overrideWith((_) => Stream.value(true)),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: DashboardPreferencesPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('dashboard-preset-carousel')),
      const Offset(-1500, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dashboard-preset-custom')));
    await tester.pump();
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('dashboard-preferences-done')),
          )
          .onPressed,
      isNull,
    );
    expect(repository.writeCount, 1);
    pending.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

class _TestPreferencesRepository extends PreferencesRepository {
  _TestPreferencesRepository(
    super.database, {
    this.failWatch = false,
    this.pendingWrite,
  });

  final bool failWatch;
  final Completer<void>? pendingWrite;
  int writeCount = 0;

  @override
  Stream<String?> watch(String key) => failWatch
      ? Stream<String?>.error(StateError('read failed'))
      : Stream<String?>.value(null);

  @override
  Future<void> set(String key, String value) {
    writeCount++;
    return pendingWrite?.future ?? Future<void>.value();
  }

  @override
  Future<void> setMany(Map<String, String> values) {
    writeCount++;
    return pendingWrite?.future ?? Future<void>.value();
  }
}
