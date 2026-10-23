import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/app/theme/bil_pearl_finish.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/workspace/coach_reference_workspace.dart';
import 'package:body_intelligence_log/features/smart_plan/presentation/bil_smart_plan_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    for (final rtl in [false, true]) {
      testWidgets(
        'real Coach Overview and Smart Plan share finish, clipping and ink in ${dark ? 'dark' : 'light'} ${rtl ? 'RTL' : 'LTR'}',
        (tester) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                verifiedSubscriptionAccessProvider.overrideWithValue(
                  AsyncData(
                    SubscriptionState(
                      plan: CommercePlan.free,
                      entitlements: {},
                      authority: EntitlementAuthority.verifiedServer,
                      isPurchasable: true,
                      canRestorePurchases: true,
                    ),
                  ),
                ),
              ],
              child: MaterialApp(
                theme: dark
                    ? BilFlagshipTheme.dark(isArabic: rtl)
                    : BilFlagshipTheme.light(isArabic: rtl),
                home: Directionality(
                  textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                  child: Scaffold(
                    body: Column(
                      children: [
                        const BilSmartPlanPanel(
                          key: ValueKey('plan-panel'),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Plan'),
                          ),
                        ),
                        Expanded(
                          child: CoachReferenceWorkspace(
                            snapshot: null,
                            now: DateTime(2026, 10, 23),
                            onChat: () {},
                            onRoute: (_) {},
                            onQuickAdd: () {},
                            onPhoto: () {},
                            onVoice: () {},
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final context = tester.element(find.byType(BilSmartPlanPanel));
          final plan = tester.widget<Container>(
            find
                .descendant(
                  of: find.byType(BilSmartPlanPanel),
                  matching: find.byType(Container),
                )
                .first,
          );
          final overviewPanels = tester
              .widgetList<Container>(
                find.descendant(
                  of: find.byType(CoachReferenceWorkspace),
                  matching: find.byType(Container),
                ),
              )
              .where(
                (item) => item.decoration == BilPearlFinish.panel(context),
              );
          expect(overviewPanels, isNotEmpty);
          expect(plan.decoration, overviewPanels.first.decoration);
          expect(plan.clipBehavior, overviewPanels.first.clipBehavior);
          final ink = tester.widget<Material>(
            find
                .descendant(
                  of: find.byType(BilSmartPlanPanel),
                  matching: find.byType(Material),
                )
                .first,
          );
          expect(ink.type, MaterialType.transparency);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
