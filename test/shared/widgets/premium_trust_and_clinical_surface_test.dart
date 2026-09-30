import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/shared/widgets/bil_clinical_note.dart';
import 'package:body_intelligence_log/shared/widgets/bil_premium_trust_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in <bool>[false, true]) {
    for (final rtl in <bool>[false, true]) {
      testWidgets('premium trust surfaces render at 200% text scale '
          '${dark ? 'dark' : 'light'} ${rtl ? 'RTL' : 'LTR'}', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: BilFlagshipTheme.light(isArabic: rtl),
            darkTheme: BilFlagshipTheme.dark(isArabic: rtl),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const BilPremiumTrustSurface(
                        icon: Icons.privacy_tip_rounded,
                        eyebrow: 'YOUR CHOICE',
                        title: 'Share selected context?',
                        body:
                            'Only the data needed for the feature is shared after explicit consent.',
                        points: [
                          BilPremiumTrustPoint(
                            icon: Icons.lock_rounded,
                            label: 'You can withdraw consent later.',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      BilPremiumConsentToggle(
                        controlKey: const Key('premium-consent-toggle'),
                        icon: Icons.auto_awesome_rounded,
                        title: 'Google Gemini consent',
                        subtitle:
                            'This switch controls future third-party AI requests.',
                        value: true,
                        onChanged: (_) {},
                      ),
                      const SizedBox(height: 16),
                      const BilClinicalNote(
                        title: 'Health information boundary',
                        text:
                            'This information supports wellness decisions and does not diagnose a medical condition.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Share selected context?'), findsOneWidget);
        expect(find.byKey(const Key('premium-consent-toggle')), findsOneWidget);
        expect(find.text('Health information boundary'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
