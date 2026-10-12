import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/wellness/presentation/recipe_library_page.dart';
import 'package:body_intelligence_log/features/wellness/repositories/recipe_release_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets(
    'detail future survives resize/theme rebuild without loading flash or lost scroll',
    (tester) async {
      final repo = RecipeReleaseRepository();
      final index = (await tester.runAsync(repo.loadIndex))!;
      final recipe = index.first;
      await tester.runAsync(() => repo.loadDetail(recipe));
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          verifiedEntitlementOwnerIdProvider.overrideWithValue(
            'synthetic-owner',
          ),
          verifiedSubscriptionAccessProvider.overrideWithValue(
            AsyncData(
              SubscriptionState(
                plan: CommercePlan.premium,
                entitlements: const {CommerceEntitlement.advancedIntelligence},
                authority: EntitlementAuthority.verifiedServer,
                isPurchasable: false,
                canRestorePurchases: false,
              ),
            ),
          ),
        ],
      );
      final theme = ValueNotifier<Brightness>(Brightness.light);
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: ValueListenableBuilder<Brightness>(
              valueListenable: theme,
              builder: (_, brightness, _) => MaterialApp(
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                theme: ThemeData(brightness: brightness),
                home: RecipeLibraryPage(
                  initialCatalog: [recipe],
                  repository: repo,
                  initialRecipeId: recipe.id,
                  remoteImageDeliveryEnabled: false,
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 15; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        final builder = find.byWidgetPredicate(
          (w) => w is FutureBuilder<RecipeCatalogDetail>,
        );
        expect(builder, findsOneWidget);
        final future = tester
            .widget<FutureBuilder<RecipeCatalogDetail>>(builder)
            .future;
        await tester.runAsync(() => future!);
        await tester.pump();
        final list = find.descendant(
          of: find.byType(DraggableScrollableSheet),
          matching: find.byType(ListView),
        );
        expect(list, findsOneWidget);
        final scroll = tester.state<ScrollableState>(
          find.descendant(of: list, matching: find.byType(Scrollable)).first,
        );
        scroll.position.jumpTo(100);
        await tester.pump();
        theme.value = Brightness.dark;
        await tester.pump();
        expect(
          tester.widget<FutureBuilder<RecipeCatalogDetail>>(builder).future,
          same(future),
        );
        expect(
          find.descendant(
            of: builder,
            matching: find.byType(CircularProgressIndicator),
          ),
          findsNothing,
        );
        expect(scroll.position.pixels, 100);
        tester.view.physicalSize = const Size(430, 900);
        tester.view.devicePixelRatio = 1;
        await tester.pump();
        expect(
          tester.widget<FutureBuilder<RecipeCatalogDetail>>(builder).future,
          same(future),
        );
        expect(
          find.descendant(
            of: builder,
            matching: find.byType(CircularProgressIndicator),
          ),
          findsNothing,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(tester.takeException(), isNull);
      } finally {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        theme.dispose();
        container.dispose();
        await tester.runAsync(db.close);
      }
    },
  );
}
