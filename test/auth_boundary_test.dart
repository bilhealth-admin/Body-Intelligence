import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/auth/login_page.dart';
import 'package:body_intelligence_log/features/auth/register_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('unconfigured account fields are disabled but autofill-ready', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
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
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final fields = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .toList();
    expect(fields, hasLength(2));
    expect(fields.every((field) => field.enabled == false), isTrue);
    final editableFields = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList();
    expect(editableFields, hasLength(2));
    expect(editableFields.first.autofillHints, contains(AutofillHints.email));
    expect(editableFields.last.autofillHints, contains(AutofillHints.password));
    expect(editableFields.last.obscureText, isTrue);

    final signIn = tester.widget<FilledButton>(
      find.byKey(const Key('login-submit')),
    );
    expect(signIn.onPressed, isNull);
    final localMode = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Continue privately on this device'),
    );
    expect(localMode.onPressed, isNotNull);
    expect(
      find.text('Cloud account configuration is not enabled in this build.'),
      findsOneWidget,
    );
  });

  testWidgets('registration is a separate complete account screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: RegisterPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(TextFormField), findsNWidgets(5));
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(
      find.text('I agree to the Terms and Privacy Policy.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('register-submit')), findsOneWidget);
  });
}
