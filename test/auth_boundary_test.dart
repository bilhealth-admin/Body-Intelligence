import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/auth/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('unconfigured account fields are disabled but autofill-ready', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: LoginPage(),
      ),
    );
    await tester.pumpAndSettle();

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields, hasLength(2));
    expect(fields.every((field) => field.enabled == false), isTrue);
    expect(fields.first.autofillHints, contains(AutofillHints.email));
    expect(fields.last.autofillHints, contains(AutofillHints.password));
    expect(fields.last.obscureText, isTrue);

    final signIn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Sign in'),
    );
    expect(signIn.onPressed, isNull);
    final localMode = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Continue in Local Mode'),
    );
    expect(localMode.onPressed, isNotNull);
    expect(
      find.text(
        'Cloud accounts are not configured in this build. No credentials will be accepted or stored.',
      ),
      findsOneWidget,
    );
  });
}
