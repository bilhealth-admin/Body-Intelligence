import 'dart:async';

import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/features/settings/account_password_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpForm(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AccountPasswordPage()));
  }

  testWidgets('password form disables submit for a short password', (
    tester,
  ) async {
    await pumpForm(tester);
    await tester.enterText(
      find.byKey(const Key('new-account-password')),
      'short',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-account-password')),
      'short',
    );
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('save-account-password')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('password form disables submit for mismatched passwords', (
    tester,
  ) async {
    await pumpForm(tester);
    await tester.enterText(
      find.byKey(const Key('new-account-password')),
      'long-enough-one',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-account-password')),
      'long-enough-two',
    );
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('save-account-password')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('password form fails closed while signed out', (tester) async {
    await pumpForm(tester);
    await tester.enterText(
      find.byKey(const Key('new-account-password')),
      'long-enough-one',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-account-password')),
      'long-enough-one',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('save-account-password')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('save-account-password')));
    await tester.pump();
    expect(find.text('Sign in before changing your password.'), findsOneWidget);
  });

  testWidgets('password update is single-flight and clears after success', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AccountPasswordPage(
          passwordUpdater: (password) {
            calls += 1;
            expect(password, 'long-enough-one');
            return pending.future;
          },
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('new-account-password')),
      'long-enough-one',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-account-password')),
      'long-enough-one',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-account-password')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-account-password')));
    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete();
    await tester.pump();
    expect(find.text('Password updated securely.'), findsOneWidget);
    expect(find.text('long-enough-one'), findsNothing);
  });

  testWidgets('password failure retains values and unlocks retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AccountPasswordPage(
          passwordUpdater: (_) async => throw StateError('injected'),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('new-account-password')),
      'long-enough-one',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-account-password')),
      'long-enough-one',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-account-password')));
    await tester.pump();
    expect(
      find.text('Password could not be updated. Try again.'),
      findsOneWidget,
    );
    expect(find.text('long-enough-one'), findsNWidgets(2));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('save-account-password')))
          .onPressed,
      isNotNull,
    );
  });

  test('password surface has direct copy in all extended locales', () {
    const keys = <String>{
      'Change password',
      'Choose a unique password for your BIL account.',
      'New password',
      'Confirm password',
      'Update password',
      'Use at least 8 characters.',
      'The passwords do not match.',
      'Sign in before changing your password.',
      'Password updated securely.',
      'Password could not be updated. Try again.',
    };
    for (final key in keys) {
      for (final locale in RuntimeCopy.supported.skip(5)) {
        final resolved = RuntimeCopy.resolve(key, locale);
        expect(resolved, isNotNull, reason: '$key / $locale');
        expect(resolved!.trim(), isNotEmpty, reason: '$key / $locale');
      }
    }
  });
}
