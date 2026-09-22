import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/health_evidence/health_evidence_catalog.dart';
import 'package:body_intelligence_log/features/settings/health_information_sources_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
