import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/onboarding/bil_flagship_onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    final tag = BilLocalePolicy.canonicalTag(locale);
    testWidgets('$tag body setup stays usable at 160% text', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final draft = BilOnboardingDraft()
        ..birthDate = DateTime(1996, 1, 1)
        ..sex = BilSex.male
        ..units = BilUnits.metric
        ..goal = BilGoal.buildMuscle
        ..activity = BilActivity.veryHigh
        ..sexConfirmed = true
        ..goalConfirmed = true
        ..activityConfirmed = true
        ..weight = 90
        ..height = 175
        ..waist = 92
        ..neck = 41;

      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: BilFlagshipTheme.light(
            isArabic: BilLocalePolicy.isRtlTag(tag),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child ?? const SizedBox.shrink(),
          ),
          home: BilFlagshipOnboarding(
            showWelcome: false,
            initialDraft: draft,
            calculatePlan: (_) async => const BilInitialPlan(
              calories: 2200,
              protein: 160,
              carbs: 240,
              fat: 70,
              weeklyPace: 0.25,
            ),
            onComplete: (_, _) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$tag setup top');

      final scrollable = find.byType(SingleChildScrollView).first;
      await tester.drag(scrollable, const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$tag setup bottom');
    });
  }
}
