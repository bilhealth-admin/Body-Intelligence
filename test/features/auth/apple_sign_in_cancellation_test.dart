import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/auth/apple_sign_in_cancellation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

void main() {
  test(
    'only the native canceled code is classified as neutral cancellation',
    () {
      expect(
        isAppleSignInCancellation(
          const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.canceled,
            message: 'canceled',
          ),
        ),
        isTrue,
      );
      expect(
        isAppleSignInCancellation(
          const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.failed,
            message: 'failed',
          ),
        ),
        isFalse,
      );
    },
  );

  test('neutral cancellation copy covers every supported locale', () {
    for (final locale in AppLocalizations.supportedLocales) {
      expect(
        appleSignInCanceledText(locale).trim(),
        isNotEmpty,
        reason: locale.toLanguageTag(),
      );
    }
    expect(
      appleSignInCanceledText(const Locale('ar')),
      'تم إلغاء تسجيل الدخول.',
    );
    expect(
      appleSignInCanceledText(const Locale('en')),
      'Sign-in was canceled.',
    );
  });

  testWidgets('cancellation banner is neutral and dismissible', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppleSignInCanceledBanner(onDismiss: () => dismissed = true),
        ),
      ),
    );

    final container = tester.widget<Container>(
      find.byKey(const Key('apple-sign-in-canceled-banner')),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, isNot(Colors.red));
    expect(find.text('Sign-in was canceled.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('apple-sign-in-canceled-dismiss')));
    expect(dismissed, isTrue);
  });
}
