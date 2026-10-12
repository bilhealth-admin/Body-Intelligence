import '../../visual_closure/visual_evidence_font.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_collection_item_gate.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final arabic in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets(
        'collection action never covers public title ${arabic ? "ar" : "en"} ${dark ? "dark" : "light"} 320 2x',
        (tester) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          var upgrades = 0, previewActions = 0;
          final semantics = tester.ensureSemantics();
          try {
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  verifiedSubscriptionAccessProvider.overrideWithValue(
                    AsyncData(
                      SubscriptionState(
                        plan: CommercePlan.free,
                        entitlements: FreePlan.entitlements,
                        authority: EntitlementAuthority.verifiedServer,
                        isPurchasable: true,
                        canRestorePurchases: true,
                      ),
                    ),
                  ),
                ],
                child: MaterialApp(
                  locale: Locale(arabic ? 'ar' : 'en'),
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  theme: visualEvidenceTheme(
                    dark
                        ? BilFlagshipTheme.dark(isArabic: arabic)
                        : BilFlagshipTheme.light(isArabic: arabic),
                  ),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(2)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        height: 480,
                        child: PremiumCollectionItemGate(
                          locked: true,
                          tier: 'BIL Premium',
                          showLabel: false,
                          onUpgrade: () => upgrades++,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                arabic
                                    ? 'وصفة طويلة من المطبخ العراقي بالحبوب والخضار الطازجة'
                                    : 'Iraqi-inspired black beans with barley and fresh vegetables',
                                key: const Key('public-long-title'),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              TextButton(
                                key: const Key('preview-action'),
                                onPressed: () => previewActions++,
                                child: const Text('Public preview action'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final action = find.byKey(
              const ValueKey('premium-collection-upgrade'),
            );
            expect(
              tester
                  .getRect(action)
                  .overlaps(
                    tester.getRect(find.byKey(const Key('public-long-title'))),
                  ),
              isFalse,
            );
            expect(tester.getRect(action).height, greaterThanOrEqualTo(48));
            expect(tester.getRect(action).width, greaterThanOrEqualTo(48));
            await tester.tapAt(
              tester.getCenter(find.byKey(const Key('preview-action'))),
            );
            expect(previewActions, 0);
            await tester.tap(action);
            expect(upgrades, 1);
            expect(
              tester
                  .getSemantics(find.byKey(const Key('public-long-title')))
                  .label,
              contains(arabic ? 'وصفة' : 'Iraqi'),
            );
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
}
