import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_check_in_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Today check-in exposes wheel, typing, save, and skip', (
    tester,
  ) async {
    double? saved;
    var skipped = false;
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            child: DashboardCheckInCard(
              initialWeightKg: 80,
              system: MeasurementSystem.metric,
              onSave: (value) async => saved = value,
              onSkip: () async => skipped = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Did you weigh yourself today?'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(ListWheelScrollView), findsOneWidget);
    await tester.enterText(find.byType(TextField), '79.4');
    await tester.pump();
    await tester.tap(find.text('Save check-in'));
    await tester.pumpAndSettle();
    expect(saved, closeTo(79.4, 0.001));

    await tester.tap(find.text('Skip today'));
    await tester.pumpAndSettle();
    expect(skipped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Today check-in is fully localized in Arabic', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            child: DashboardCheckInCard(
              initialWeightKg: 80,
              system: MeasurementSystem.metric,
              onSave: (_) async {},
              onSkip: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('هل قست وزنك اليوم؟'), findsOneWidget);
    expect(find.text('حفظ القياس'), findsOneWidget);
    expect(find.text('تخطي اليوم'), findsOneWidget);
  });
}
