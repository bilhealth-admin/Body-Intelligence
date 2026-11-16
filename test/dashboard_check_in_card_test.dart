import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_check_in_card.dart';
import 'package:body_intelligence_log/shared/widgets/bil_splash_capsule_progress.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final skip in [false, true]) {
    testWidgets(
      'pending check-in ${skip ? 'skip' : 'save'} is a neutral wait and cannot repeat',
      (tester) async {
        final held = Completer<void>();
        var calls = 0;
        Future<void> operation() {
          calls++;
          return held.future;
        }

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
                  onSave: (_) => operation(),
                  onSkip: operation,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(skip ? 'Skip today' : 'Save check-in'));
        await tester.pump(const Duration(milliseconds: 80));
        expect(calls, 1);
        final wait = find.byType(CupertinoActivityIndicator);
        expect(wait, findsOneWidget);
        expect(
          tester.widget<CupertinoActivityIndicator>(wait).color,
          const Color(0xFF697178),
        );
        expect(find.byType(BilSplashCapsuleProgress), findsNothing);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save check-in'),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Skip today'))
              .onPressed,
          isNull,
        );
        held.complete();
        await tester.pumpAndSettle();
        expect(wait, findsNothing);
        expect(calls, 1);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save check-in'),
              )
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

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
