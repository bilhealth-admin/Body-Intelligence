import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/dashboard/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('first value handoff is honest and has one action in Arabic', (
    tester,
  ) async {
    var continued = false;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
          body: FirstValueHandoffCard(onContinue: () => continued = true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('نقطة بدايتك الخاصة جاهزة'), findsOneWidget);
    expect(find.textContaining('لن يدّعي وجود اتجاه'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    await tester.tap(find.text('سجّل أول قياس يومي'));
    expect(continued, isTrue);
    expect(tester.takeException(), isNull);
  });
}
