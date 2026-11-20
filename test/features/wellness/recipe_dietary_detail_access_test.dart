import 'dart:async';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/nutrition/domain/dietary_preferences.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/wellness/presentation/recipe_library_page.dart';
import 'package:body_intelligence_log/features/wellness/repositories/recipe_release_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final recipes = RecipeReleaseRepository();
  late RecipeCatalogSummary breakfast;
  setUpAll(() async {
    breakfast = (await recipes.loadIndex()).singleWhere(
      (r) => r.id == 'shakshuka',
    );
    await recipes.loadDetail(breakfast);
    await recipes.loadCardFacts(breakfast.id);
  });
  testWidgets(
    'recipe deep link waits for dietary read and retires newly excluded content',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final changes = StreamController<DietaryPreferences>();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          dietaryPreferencesProvider.overrideWith((_) => changes.stream),
          verifiedEntitlementOwnerIdProvider.overrideWithValue(
            'synthetic-dietary-owner',
          ),
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
        ],
      );
      addTearDown(() async {
        container.dispose();
        await changes.close();
        await db.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: BilFlagshipTheme.light(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: RecipeLibraryPage(
              initialCatalog: [breakfast],
              repository: recipes,
              remoteImageDeliveryEnabled: false,
              initialRecipeId: breakfast.id,
            ),
          ),
        ),
      );
      Future<void> frames() async {
        await tester.runAsync(() async {
          for (var i = 0; i < 15; i++) {
            await tester.pump(const Duration(milliseconds: 40));
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.pump();
      }

      await frames();
      final gate = find.byKey(const ValueKey('recipe-detail-access-gate'));
      expect(gate, findsNothing);
      changes.add(const DietaryPreferences());
      await frames();
      expect(gate, findsOneWidget);
      final title = find.descendant(
        of: gate,
        matching: find.text(breakfast.title),
      );
      expect(title, findsWidgets);
      final button = find.descendant(
        of: gate,
        matching: find.widgetWithText(FilledButton, 'Review and save recipe'),
      );
      await tester.scrollUntilVisible(
        button,
        300,
        scrollable: find
            .descendant(of: gate, matching: find.byType(Scrollable))
            .last,
      );
      final review = tester.widget<FilledButton>(button).onPressed!;
      changes.add(const DietaryPreferences(allergens: {DietaryAllergen.egg}));
      await tester.runAsync(() async {
        for (
          var i = 0;
          i < 20 &&
              container
                      .read(dietaryPreferencesProvider)
                      .value
                      ?.allergens
                      .contains(DietaryAllergen.egg) !=
                  true;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      expect(
        container.read(dietaryPreferencesProvider).requireValue.allergens,
        contains(DietaryAllergen.egg),
      );
      review();
      await frames();
      expect(tester.takeException(), isNull);
      expect(title, findsNothing);
      expect(
        find.descendant(
          of: gate,
          matching: find.text('Recipe details are unavailable.'),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
