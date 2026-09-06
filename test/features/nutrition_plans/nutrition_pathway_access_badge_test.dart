import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_semantic_icons.dart';
import 'package:body_intelligence_log/features/nutrition_plans/domain/pathways/carb_cycling.dart';
import 'package:body_intelligence_log/features/nutrition_plans/domain/pathways/smart_fat_loss.dart';
import 'package:body_intelligence_log/features/nutrition_plans/presentation/nutrition_pathways_page.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'pathway access badges are localized without repeated Premium text',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final freePlanId = carbCyclingPathway.id;
      final premiumPlanId = smartFatLossPathway.id;

      for (final localeAndPremiumLabel in const <(Locale, String)>[
        (Locale('en'), 'Premium'),
        (Locale('ar'), 'مميز'),
      ]) {
        final (locale, premiumLabel) = localeAndPremiumLabel;
        await tester.pumpWidget(
          ProviderScope(
            // Each locale is a fresh screen. The previous case deliberately
            // scrolls past the hero to inspect the compact access badge.
            key: ValueKey(locale.toLanguageTag()),
            overrides: [
              activeNutritionPathwayProvider.overrideWithValue(
                const AsyncData(null),
              ),
            ],
            child: MaterialApp(
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.6)),
                child: child ?? const SizedBox.shrink(),
              ),
              home: const NutritionPathwaysPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final premiumBadge = find.byKey(
          Key('nutrition-pathway-access-hero-$premiumPlanId'),
        );
        expect(premiumBadge, findsOneWidget);
        // Premium appears once at page level. Individual paid badges retain
        // localized screen-reader labels instead of repeating visible text.
        expect(find.text(premiumLabel), findsOneWidget);
        expect(
          find.descendant(of: premiumBadge, matching: find.text(premiumLabel)),
          findsNothing,
        );
        final premiumIconFinder = find.descendant(
          of: premiumBadge,
          matching: find.byType(Icon),
        );
        final premiumIcon = tester.widget<Icon>(premiumIconFinder);
        expect(premiumIcon.icon, BilSemanticIcons.subscription);
        expect(premiumIcon.icon, isNot(Icons.circle));
        expect(premiumIcon.semanticLabel, premiumLabel);
        // Flutter merges the icon into the card's tappable semantics node.
        // Keep the access label exactly once alongside the plan description.
        expect(
          tester
              .getSemantics(premiumIconFinder)
              .label
              .split('\n')
              .where((label) => label == premiumLabel),
          hasLength(1),
        );

        final freeBadge = find.byKey(
          Key('nutrition-pathway-access-hero-$freePlanId'),
        );
        expect(freeBadge, findsOneWidget);
        expect(
          find.descendant(
            of: freeBadge,
            matching: find.text(locale.languageCode == 'ar' ? 'مجاني' : 'Free'),
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<Icon>(
                find.descendant(of: freeBadge, matching: find.byType(Icon)),
              )
              .icon,
          Icons.lock_open_rounded,
        );

        final compactPremiumBadge = find.byKey(
          Key('nutrition-pathway-access-row-$premiumPlanId'),
        );
        await tester.scrollUntilVisible(
          compactPremiumBadge,
          260,
          scrollable: find.byType(Scrollable).first,
        );
        expect(compactPremiumBadge, findsOneWidget);
        expect(
          find.descendant(
            of: compactPremiumBadge,
            matching: find.text(premiumLabel),
          ),
          findsNothing,
        );
        final compactPremiumIcon = find.descendant(
          of: compactPremiumBadge,
          matching: find.byType(Icon),
        );
        expect(
          tester.widget<Icon>(compactPremiumIcon).icon,
          BilSemanticIcons.subscription,
        );
        expect(
          tester.widget<Icon>(compactPremiumIcon).semanticLabel,
          premiumLabel,
        );
        expect(
          tester
              .getSemantics(compactPremiumIcon)
              .label
              .split('\n')
              .where((label) => label == premiumLabel),
          hasLength(1),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: locale.toLanguageTag());
      }
    },
    semanticsEnabled: true,
  );
}
