import 'package:body_intelligence_log/features/dashboard/domain/dashboard_decision_explanation.dart';
import 'package:body_intelligence_log/features/dashboard/presentation/dashboard_decision_explanation_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DashboardDecisionExplanation explanation() => DashboardDecisionExplanation(
    actionType: 'protein',
    title: 'Add protein',
    reason: 'Protein is the clearest local gap.',
    evidence: const ['70 g logged', '120 g target'],
    confidence: 'Useful',
    missingEvidence: const ['meal completeness'],
    engineVersion: 'dashboard-truth-adapter-v1',
    inputSources: const ['protein', 'proteinTarget'],
  );

  testWidgets('renders explanation, uncertainty, provenance, and safety', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardDecisionExplanationPage(explanation: explanation()),
      ),
    );

    expect(
      find.byKey(const Key('dashboard-decision-explanation-page')),
      findsOneWidget,
    );
    expect(find.text('Add protein'), findsOneWidget);
    expect(find.textContaining('70 g logged'), findsOneWidget);
    expect(find.textContaining('meal completeness'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('decision-explanation-provenance')),
      240,
    );
    expect(find.textContaining('dashboard-truth-adapter-v1'), findsOneWidget);
    expect(
      find.byKey(const Key('decision-explanation-safety-note')),
      findsOneWidget,
    );
  });

  testWidgets('renders an honest unavailable state without route payload', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DashboardDecisionExplanationPage(explanation: null),
      ),
    );

    expect(
      find.byKey(const Key('decision-explanation-unavailable')),
      findsOneWidget,
    );
    expect(find.textContaining('no longer available'), findsOneWidget);
  });

  test('model rejects empty identity and preserves immutable provenance', () {
    final value = explanation();
    expect(value.inputSources, ['protein', 'proteinTarget']);
    expect(() => value.inputSources.add('waterMl'), throwsUnsupportedError);
    expect(
      () => DashboardDecisionExplanation(
        actionType: '',
        title: 'Title',
        reason: 'Reason',
        evidence: const ['evidence'],
        confidence: 'Useful',
        missingEvidence: const [],
        engineVersion: 'v1',
        inputSources: const ['protein'],
      ),
      throwsArgumentError,
    );
  });
}
