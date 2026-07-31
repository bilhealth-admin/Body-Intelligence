import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_water_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Today water card adds quick and custom persisted amounts', (
    tester,
  ) async {
    final amounts = <int>[];
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
        home: Scaffold(
          body: DashboardWaterCard(
            consumedMl: 600,
            targetMl: 2000,
            onAdd: (amount) async => amounts.add(amount),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('600 / 2000 ml'), findsOneWidget);
    expect(find.text('1400 ml remaining'), findsOneWidget);
    await tester.tap(find.text('+250 ml'));
    await tester.pumpAndSettle();
    expect(amounts, [250]);

    await tester.tap(find.text('Custom amount'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '333');
    await tester.tap(find.text('Add water'));
    await tester.pumpAndSettle();
    expect(amounts, [250, 333]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom water rejects unsafe amounts in Arabic', (tester) async {
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
          body: DashboardWaterCard(
            consumedMl: 0,
            targetMl: 2000,
            onAdd: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('كمية مخصصة'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '9000');
    await tester.tap(find.text('إضافة ماء'));
    await tester.pump();
    expect(find.text('أدخل كمية ماء من 1 إلى 5000 مل.'), findsOneWidget);
  });
}
