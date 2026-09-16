import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/wellness/presentation/recipe_library_page.dart';
import 'package:body_intelligence_log/features/wellness/repositories/recipe_release_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RecipeReleaseRepository repository;
  late RecipeCatalogSummary recipe;
  late RecipeCatalogCardFacts facts;
  setUpAll(() async {
    repository = RecipeReleaseRepository();
    final index = await repository.loadIndex();
    recipe = index.singleWhere((value) => value.id == 'shakshuka');
    await repository.loadDetail(recipe);
    facts = await repository.loadCardFacts(recipe.id);
  });

  for (final terminal in ['refund', 'expiry']) {
    testWidgets('an already-open recipe relocks on $terminal', (tester) async {
      var now = DateTime.utc(2026, 9, 16);
      final end = now.add(const Duration(seconds: 10));
      SubscriptionState state = _paid(end);
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          verifiedEntitlementClockProvider.overrideWithValue(() => now),
          verifiedSubscriptionStateProvider.overrideWith((_) async => state),
          storefrontTargetPlanProvider.overrideWith(
            (_) async => CommercePlan.premium,
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: RecipeLibraryPage(
              initialCatalog: [recipe],
              initialCardFacts: {recipe.id: facts},
              repository: repository,
              remoteImageDeliveryEnabled: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(recipe.resolveTitle('en').text).first);
      // Repository futures were created outside the widget's fake clock while
      // verifying the real asset shard. Let that async work finish before
      // waiting for sheet animations; pumping fake time cannot drive it.
      await tester.pump();
      await tester.runAsync(() => repository.loadDetail(recipe));
      await tester.pumpAndSettle();
      final sheet = find.byKey(const ValueKey('recipe-detail-access-gate'));
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(
          of: sheet,
          matching: find.text(recipe.resolveTitle('en').text),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.byType(ListView)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: sheet,
          matching: find.byKey(
            const ValueKey('premium-route-protected-content'),
          ),
        ),
        findsNothing,
      );
      if (terminal == 'refund') {
        state = _paid(end, lifecycle: SubscriptionLifecycle.refunded);
        container.invalidate(verifiedSubscriptionStateProvider);
        await container.read(verifiedSubscriptionStateProvider.future);
        await tester.pump();
        await tester.pump();
        await tester.runAsync(() => repository.loadDetail(recipe));
        await tester.pumpAndSettle();
      } else {
        now = end;
        await tester.pump(const Duration(seconds: 10));
        await tester.pump();
      }
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(
          of: sheet,
          matching: find.byKey(
            const ValueKey('premium-route-protected-content'),
          ),
        ),
        findsOneWidget,
      );
      final blockers = tester.widgetList<AbsorbPointer>(
        find.descendant(of: sheet, matching: find.byType(AbsorbPointer)),
      );
      expect(blockers.any((widget) => widget.absorbing), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}

SubscriptionState _paid(
  DateTime end, {
  SubscriptionLifecycle lifecycle = SubscriptionLifecycle.active,
}) => SubscriptionState(
  plan: CommercePlan.premium,
  entitlements: const {},
  authority: EntitlementAuthority.verifiedServer,
  lifecycle: lifecycle,
  currentPeriodEndsAt: end,
  isPurchasable: false,
  canRestorePurchases: true,
);
