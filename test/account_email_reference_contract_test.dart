import 'dart:io';
import 'dart:async';

import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/features/settings/account_email_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile account email uses authenticated Supabase update route', () {
    final page = File(
      'lib/features/settings/account_email_page.dart',
    ).readAsStringSync();
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final profile = File(
      'lib/features/profile/premium_profile_page.dart',
    ).readAsStringSync();

    expect(page, contains('UserAttributes(email: value)'));
    expect(page, contains("key: const Key('account-email-field')"));
    expect(router, contains("path: '/settings/account-email'"));
    expect(profile, contains("'/settings/account-email'"));
  });

  testWidgets('email update is single-flight and locks the form', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AccountEmailPage(
          initialEmail: 'old@bil.test',
          emailUpdater: (email) {
            calls += 1;
            expect(email, 'new@bil.test');
            return pending.future;
          },
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('account-email-field')),
      'new@bil.test',
    );
    await tester.tap(find.byKey(const Key('save-account-email')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-account-email')));
    expect(calls, 1);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('account-email-field')))
          .enabled,
      isFalse,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete();
    await tester.pump();
    expect(
      find.text('Check both email addresses to confirm the change.'),
      findsOneWidget,
    );
  });

  testWidgets('email failure preserves the draft and unlocks retry', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AccountEmailPage(
          initialEmail: 'old@bil.test',
          emailUpdater: (email) async {
            calls += 1;
            throw StateError('injected');
          },
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('account-email-field')),
      'retry@bil.test',
    );
    await tester.tap(find.byKey(const Key('save-account-email')));
    await tester.pump();
    expect(calls, 1);
    expect(find.text('retry@bil.test'), findsOneWidget);
    expect(find.text('Email could not be changed. Try again.'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('account-email-field')))
          .enabled,
      isTrue,
    );
  });

  test('account email surface has direct extended-locale copy', () {
    const keys = <String>{
      'Account email',
      'This changes the address used to sign in. Supabase may require confirmation from both the old and new address.',
      'Email address',
      'Update email',
      'Enter a valid email address.',
      'Sign in to change your account email.',
      'Check both email addresses to confirm the change.',
      'Email could not be changed. Try again.',
    };
    for (final key in keys) {
      for (final locale in RuntimeCopy.supported.skip(5)) {
        final resolved = RuntimeCopy.resolve(key, locale);
        expect(resolved, isNotNull, reason: '$key / $locale');
        expect(resolved!.trim(), isNotEmpty, reason: '$key / $locale');
        expect(resolved, isNot(key), reason: 'English leak: $key / $locale');
      }
    }
  });
}
