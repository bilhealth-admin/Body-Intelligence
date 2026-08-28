import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/engine/nutrient_evidence_engine.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/nutrient_evidence_status_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('unavailable nutrient evidence is explicit in English', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NutrientEvidenceStatusText(
          state: NutrientEvidenceState.unavailable,
        ),
      ),
    );
    expect(find.textContaining('unavailable'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('partial nutrient evidence is localized and RTL', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: NutrientEvidenceStatusText(
            state: NutrientEvidenceState.partial,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final rendered = tester.widget<Text>(find.byType(Text)).data!;
    expect(
      RegExp(r'[\u0600-\u06FF]').hasMatch(rendered),
      isTrue,
      reason: 'Expected Arabic evidence copy, got: $rendered',
    );
    expect(
      Directionality.of(tester.element(find.byType(Text))),
      TextDirection.rtl,
    );
  });

  testWidgets(
    'informational partial evidence excludes unavailable foods without overclaiming',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NutrientEvidenceStatusText(
            state: NutrientEvidenceState.partial,
            informational: true,
          ),
        ),
      );
      expect(
        find.text(
          'Partial evidence; foods with unavailable values are excluded.',
        ),
        findsOneWidget,
      );
      expect(find.text('0'), findsNothing);
    },
  );
}
