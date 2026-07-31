import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/nutrition_progress_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('nutrition card shows consumed target and remaining accessibly', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 180,
            child: NutritionProgressCard(
              label: 'Protein',
              consumed: 80,
              target: 120,
              unit: 'g',
              icon: Icons.fitness_center,
              color: Colors.green,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('80 / 120 g'), findsOneWidget);
    expect(find.text('40 g remaining'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label ==
                'Protein: 80 g consumed, 120 g target, 40 g remaining',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
