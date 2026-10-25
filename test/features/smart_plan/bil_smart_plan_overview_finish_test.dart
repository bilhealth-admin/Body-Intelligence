import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/app/theme/bil_pearl_finish.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/workspace/coach_reference_workspace.dart';
import 'package:body_intelligence_log/features/smart_plan/presentation/bil_smart_plan_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../visual_closure/visual_evidence_font.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'photographic background stays visible with the same focal crop in RTL and LTR dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        Future<List<int>> render({
          required bool rtl,
          required bool artwork,
        }) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? BilFlagshipTheme.dark() : BilFlagshipTheme.light(),
              home: Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: Scaffold(
                  body: Center(
                    child: RepaintBoundary(
                      key: const ValueKey('artwork-pixels'),
                      child: BilSmartPlanPanel(
                        artwork: artwork
                            ? BilSmartPlanArt.forWorkout('gym-push')
                            : null,
                        child: const SizedBox(width: 358, height: 540),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await settleVisualAssetImages(tester);
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('artwork-pixels')),
          );
          return (await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              );
              return bytes!.buffer.asUint8List().toList();
            } finally {
              image.dispose();
            }
          }))!;
        }

        final englishBackground = await render(rtl: false, artwork: true);
        final arabicBackground = await render(rtl: true, artwork: true);
        final plainPanel = await render(rtl: true, artwork: false);
        expect(
          arabicBackground,
          englishBackground,
          reason:
              'RTL must not replace the photographic subject with an empty crop.',
        );
        expect(
          arabicBackground,
          isNot(plainPanel),
          reason: 'Matching blank panels are not evidence of visible artwork.',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
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
