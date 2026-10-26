import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/health_evidence/health_evidence_catalog.dart';
import 'package:body_intelligence_log/features/settings/health_information_sources_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets(
      'FDA source uses $language consistently in text and semantics',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              home: const HealthInformationSourcesPage(
                sourceIds: [HealthEvidenceIds.fdaDailyValues],
              ),
            ),
          );
          await tester.pumpAndSettle();
          final card = find.byKey(
            const ValueKey('health-source-${HealthEvidenceIds.fdaDailyValues}'),
          );
          await tester.scrollUntilVisible(
            card,
            150,
            scrollable: find.byType(Scrollable),
          );
          final text = tester
              .widgetList<Text>(
                find.descendant(of: card, matching: find.byType(Text)),
              )
              .map((widget) => widget.data ?? '')
              .join('\n');
          final label = tester.getSemantics(card).label;
          if (language == 'en') {
            expect(text, contains('Daily Values'));
            expect(
              text,
              contains('General label references, not personal RDA/AI.'),
            );
            expect(RegExp(r'[\u0600-\u06ff]').hasMatch(text + label), isFalse);
            expect(label, contains('Open original source: Daily Values'));
          } else {
            expect(text, contains('القيم اليومية المرجعية'));
            expect(
              text,
              contains('مراجع عامة للملصقات، وليست احتياجًا شخصيًا.'),
            );
            expect(
              label,
              contains('فتح المصدر الأصلي: القيم اليومية المرجعية'),
            );
          }
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
  testWidgets('featured citation stays readable and accessible at large text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
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
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const HealthInformationSourcesPage(
          sourceIds: [HealthEvidenceIds.pregnancyIronFolate],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final source = HealthEvidenceCatalog.byId(
      HealthEvidenceIds.pregnancyIronFolate,
    )!;
    final sourceCard = find.byKey(
      const ValueKey('health-source-${HealthEvidenceIds.pregnancyIronFolate}'),
    );
    await tester.scrollUntilVisible(
      sourceCard,
      220,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(sourceCard, findsOneWidget);
    expect(
      tester.getSemantics(sourceCard).label,
      contains('Open original source: ${source.title}'),
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
