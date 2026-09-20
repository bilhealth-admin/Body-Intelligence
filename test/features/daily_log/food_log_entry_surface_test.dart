import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/food_log_entry_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Food Log landing surface exposes the reference actions', (
    tester,
  ) async {
    var logFoodTaps = 0;
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
          body: FoodLogEntrySurface(
            onLogFood: () => logFoodTaps++,
            onBarcode: () {},
            onVoice: () {},
            onPhoto: () {},
            onExercise: () {},
            onNotes: () {},
            onSearch: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('food-log-entry-surface')), findsOneWidget);
    expect(find.text('Log food'), findsNWidgets(2));
    expect(find.text('Scan barcode'), findsOneWidget);
    expect(find.text('Log food by voice'), findsOneWidget);
    expect(find.text('Analyze meal photo'), findsOneWidget);
    expect(find.byKey(const Key('food-log-primary-0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('food-log-primary-0')));
    expect(logFoodTaps, 1);
  });
}
