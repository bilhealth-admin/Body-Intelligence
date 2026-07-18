import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/onboarding/widgets/welcome_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget buildWelcomeApp(Locale locale) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: WelcomeStep(onContinue: () {})),
  );
}

void main() {
  testWidgets('Arabic default locale shows RTL onboarding text', (
    tester,
  ) async {
    await tester.pumpWidget(buildWelcomeApp(const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('مرحبًا بك في BIL'), findsOneWidget);
    expect(find.text('ابدأ'), findsOneWidget);
    final direction = Directionality.of(
      tester.element(find.text('مرحبًا بك في BIL')),
    );
    expect(direction, TextDirection.rtl);
  });

  testWidgets('English locale shows LTR onboarding text', (tester) async {
    await tester.pumpWidget(buildWelcomeApp(const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to BIL'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    final direction = Directionality.of(
      tester.element(find.text('Welcome to BIL')),
    );
    expect(direction, TextDirection.ltr);
  });
}
