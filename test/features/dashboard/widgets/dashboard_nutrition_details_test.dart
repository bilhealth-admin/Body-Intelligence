import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/engine/nutrient_evidence_engine.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_nutrition_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  testWidgets('preserves detail panel heading and child order', (tester) async {
    await tester.pumpWidget(
      host(
        const DashboardDetailPanel(
          icon: Icons.task_alt_outlined,
          title: 'One best action',
          children: [Text('Accept'), Text('Done')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.task_alt_outlined), findsOneWidget);
    expect(find.text('One best action'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('preserves target total, progress, and partial evidence', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const DashboardTargetRow(
          label: 'Protein',
          evidence: NutrientEvidenceReport(
            state: NutrientEvidenceState.partial,
            total: 60,
          ),
          target: 100,
          unit: 'g',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Protein · 60 / 100 g'), findsOneWidget);
    expect(
      find.text(
        'Partial evidence: total includes only foods with known values.',
      ),
      findsOneWidget,
    );
    expect(find.text('40 g remaining'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .6,
    );
  });

  testWidgets('preserves unavailable evidence instead of inventing a total', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const DashboardTargetRow(
          label: 'Fiber',
          evidence: NutrientEvidenceReport(
            state: NutrientEvidenceState.unavailable,
            total: null,
          ),
          target: 30,
          unit: 'g',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fiber'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(
      find.text('Value unavailable in the logged food evidence.'),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('preserves informational-only and partial evidence copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const Column(
          children: [
            DashboardInformationalNutrientRow(
              label: 'Sodium',
              evidence: NutrientEvidenceReport(
                state: NutrientEvidenceState.complete,
                total: 1200,
              ),
              unit: 'mg',
            ),
            DashboardInformationalNutrientRow(
              label: 'Potassium',
              evidence: NutrientEvidenceReport(
                state: NutrientEvidenceState.partial,
                total: 800,
              ),
              unit: 'mg',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1200 mg'), findsOneWidget);
    expect(find.text('No target; informational only'), findsOneWidget);
    expect(find.text('800 mg'), findsOneWidget);
    expect(
      find.text(
        'Partial evidence; foods with unavailable values are excluded.',
      ),
      findsOneWidget,
    );
  });
}
