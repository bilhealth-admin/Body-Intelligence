import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/nutrition/food_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../visual_closure/visual_evidence_font.dart';
import '../visual_closure/closure_surface_capture.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final kind in ['manual-barcode', 'custom-food']) {
    testWidgets(
      'actual $kind Arabic 320 keyboard 2x has reachable cancel and never writes',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final db = AppDatabase.forTesting(
          NativeDatabase.memory(),
          localOwnerId: 'A',
        );
        addTearDown(db.close);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              seedCatalogProvider.overrideWith((ref) async {}),
              verifiedEntitlementOwnerSeedProvider.overrideWithValue('A'),
              verifiedEntitlementOwnerProvider.overrideWith(
                (ref) => Stream.value('A'),
              ),
              verifiedSubscriptionStateProvider.overrideWithValue(
                AsyncData(
                  SubscriptionState(
                    plan: CommercePlan.premium,
                    entitlements: {CommerceEntitlement.advancedIntelligence},
                    authority: EntitlementAuthority.verifiedServer,
                    lifecycle: SubscriptionLifecycle.active,
                    currentPeriodEndsAt: DateTime(2030),
                    isPurchasable: false,
                    canRestorePurchases: false,
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('ar'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: [
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              theme: visualEvidenceTheme(
                BilFlagshipTheme.dark(isArabic: true),
                fontFamily: 'NotoArabicEvidence',
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: const FoodPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'catalog before modal');
        await tester.tap(find.byKey(const Key('food-primary-add-action')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'add sheet');
        final choice = find.byKey(
          Key(
            kind == 'manual-barcode'
                ? 'food-add-manual-barcode'
                : 'food-add-custom-food',
          ),
        );
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await tester.pumpAndSettle();
        for (
          var i = 0;
          i < 100 && find.byType(AlertDialog).evaluate().isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(find.byType(AlertDialog), findsOneWidget);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        final cancel = find.widgetWithText(TextButton, 'إلغاء');
        await tester.ensureVisible(cancel);
        await tester.pumpAndSettle();
        await captureClosureSurface(
          tester,
          find.byType(AlertDialog),
          '$kind-ar-320-keyboard-2x',
        );
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(await db.select(db.foods).get(), isEmpty);
        expect(await db.select(db.mealItems).get(), isEmpty);
        expect(tester.takeException(), isNull);
        // Dispose Riverpod's real Drift query streams before Flutter verifies
        // pending timers; package-test tearDown runs after that verification.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
        await tester.runAsync(db.close);
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  }
}
