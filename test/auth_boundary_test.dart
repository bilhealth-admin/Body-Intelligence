import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/auth/login_page.dart';
import 'package:body_intelligence_log/features/auth/register_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('store reviewer password path accepts only its dedicated account', () {
    expect(
      StoreReviewerLoginPage.acceptsReviewerEmail(
        ' PLAY-REVIEW@BILHEALTH.COM ',
      ),
      isTrue,
    );
    expect(
      StoreReviewerLoginPage.acceptsReviewerEmail('person@example.com'),
      isFalse,
    );
  });

  testWidgets('production passwordless login is enabled by default', (
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
    expect(fields, hasLength(1));
    expect(fields.single.enabled, isTrue);

    final editableFields = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList();
    expect(editableFields, hasLength(1));
    expect(editableFields.single.autofillHints, contains(AutofillHints.email));
    expect(editableFields.single.obscureText, isFalse);

    final verify = tester.widget<FilledButton>(
      find.byKey(const Key('login-submit')),
    );
    expect(verify.onPressed, isNotNull);
    expect(find.byKey(const Key('login-password')), findsNothing);
    expect(find.byKey(const Key('forgot-password')), findsNothing);
    expect(find.byKey(const Key('open-register')), findsNothing);
    expect(
      find.text('Cloud account is not enabled on this build.'),
      findsNothing,
    );
  });

  testWidgets('registration remains a separate legacy-compatible screen', (
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

  testWidgets('store reviewer has dedicated password access without bypass', (
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
          home: StoreReviewerLoginPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Store reviewer access'), findsOneWidget);
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(find.byKey(const Key('login-password')), findsOneWidget);
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    expect(find.byKey(const Key('reviewer-login-back')), findsOneWidget);
    expect(find.byKey(const Key('forgot-password')), findsNothing);
    expect(find.byKey(const Key('open-register')), findsNothing);
    expect(find.text('Continue privately on this device'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('login-email')),
      'person@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'not-a-reviewer-password',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();

    expect(
      find.text(
        'Use only the dedicated credentials supplied in the store review notes.',
      ),
      findsAtLeastNWidgets(1),
    );
  });
}
