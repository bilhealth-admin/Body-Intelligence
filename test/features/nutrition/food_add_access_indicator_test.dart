import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/paid_plan_catalog.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_label_badge.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/nutrition/food_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../visual_closure/visual_evidence_font.dart';
import '../../visual_closure/closure_surface_capture.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final state in ['free', 'premium', 'expired', 'checking', 'error']) {
    testWidgets(
      'Food Add honest badge and free custom action $state Arabic 320 2x keyboard',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.reset);
        WidgetController.hitTestWarningShouldBeFatal = true;
        addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final paid = state == 'premium' || state == 'expired';
        final now = DateTime.now().toUtc();
        final access = state == 'checking'
            ? const AsyncValue<SubscriptionState>.loading()
            : state == 'error'
            ? AsyncValue<SubscriptionState>.error(
                StateError('fixture unavailable'),
                StackTrace.current,
              )
            : AsyncValue.data(
                SubscriptionState(
                  plan: paid ? CommercePlan.premium : CommercePlan.free,
                  entitlements: paid
                      ? PaidPlanCatalog.composedEntitlementsFor(
                          CommercePlan.premium,
                        )
                      : FreePlan.entitlements,
                  authority: EntitlementAuthority.verifiedServer,
                  lifecycle: paid
                      ? SubscriptionLifecycle.active
                      : SubscriptionLifecycle.inactive,
                  verifiedAt: now,
                  currentPeriodEndsAt: paid
                      ? now.add(Duration(days: state == 'expired' ? -1 : 1))
                      : null,
                  isPurchasable: true,
                  canRestorePurchases: true,
                ),
              );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              foodsProvider.overrideWith((ref) => Stream.value(const [])),
              favoriteFoodsProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
              recentFoodsProvider.overrideWith((ref) => Stream.value(const [])),
              verifiedSubscriptionStateProvider.overrideWithValue(access),
            ],
            child: MaterialApp(
              locale: const Locale('ar'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              theme: visualEvidenceTheme(
                BilFlagshipTheme.light(isArabic: true),
                fontFamily: 'NotoArabicEvidence',
              ),
              builder: (context, child) => RepaintBoundary(
                key: const Key('food-add-indicator-capture'),
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(2),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
              ),
              home: const FoodPage(embedded: true, userOwnedOnly: true),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final add = find.byKey(const Key('food-primary-add-action'));
        await tester.ensureVisible(add);
        await tester.pumpAndSettle();
        expect(add.hitTestable(), findsOneWidget);
        await tester.tap(add);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.descendant(
            of: find.byKey(const Key('food-add-barcode-premium-group')),
            matching: find.byType(PremiumLabelBadge),
          ),
          state == 'free' || state == 'expired' ? findsOneWidget : findsNothing,
        );
        for (final key in [
          'food-add-scan-barcode',
          'food-add-manual-barcode',
          'food-add-meal-photo',
          'food-add-custom-food',
        ]) {
          final action = find.byKey(Key(key));
          expect(action, findsOneWidget);
          expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
        }
        final custom = find.byKey(const Key('food-add-custom-food'));
        await tester.ensureVisible(custom);
        await tester.pumpAndSettle();
        expect(custom.hitTestable(), findsOneWidget);
        expect(tester.getRect(custom).bottom, lessThanOrEqualTo(584));
        await captureClosureSurface(
          tester,
          find.byKey(const Key('food-add-indicator-capture')),
          'food-add-$state-ar-320-keyboard-2x',
        );
        await tester.tap(custom);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        final cancel = find.text('إلغاء').last;
        await tester.ensureVisible(cancel);
        await tester.pumpAndSettle();
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(await db.select(db.foods).get(), isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
