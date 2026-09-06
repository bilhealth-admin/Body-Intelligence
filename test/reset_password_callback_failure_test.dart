import 'package:body_intelligence_log/features/auth/reset_password_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'verified route enables recovery when the auth event arrived before mount',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ResetPasswordPage(
            initiallyVerified: true,
            cloudConfiguredOverride: true,
            // This models getSessionFromUrl having emitted its one-shot event
            // before GoRouter mounted the reset page.
            recoverySessionEvents: Stream<bool>.empty(),
            recoveryTimeout: Duration(milliseconds: 20),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 21));

      expect(
        find.byKey(const Key('reset-password-callback-failed')),
        findsNothing,
      );
      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save password'),
      );
      expect(save.onPressed, isNotNull);
    },
  );

  testWidgets('verified route update closes an active recovery wait', (
    tester,
  ) async {
    Widget page({required bool verified}) => MaterialApp(
      home: ResetPasswordPage(
        initiallyVerified: verified,
        cloudConfiguredOverride: true,
        recoverySessionEvents: const Stream<bool>.empty(),
        recoveryTimeout: const Duration(milliseconds: 20),
      ),
    );

    await tester.pumpWidget(page(verified: false));
    await tester.pumpWidget(page(verified: true));
    await tester.pump(const Duration(milliseconds: 21));

    expect(
      find.byKey(const Key('reset-password-callback-failed')),
      findsNothing,
    );
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save password'),
    );
    expect(save.onPressed, isNotNull);
  });

  testWidgets('silent recovery exchange times out into a terminal state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ResetPasswordPage(
          cloudConfiguredOverride: true,
          recoverySessionEvents: Stream<bool>.empty(),
          recoveryTimeout: Duration(milliseconds: 20),
        ),
      ),
    );

    expect(
      find.byKey(const Key('reset-password-callback-failed')),
      findsNothing,
    );
    await tester.pump(const Duration(milliseconds: 21));

    expect(
      find.byKey(const Key('reset-password-callback-failed')),
      findsOneWidget,
    );
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save password'),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('failed recovery callback offers an explicit retry', (
    tester,
  ) async {
    var retryCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ResetPasswordPage(
          initiallyFailed: true,
          cloudConfiguredOverride: true,
          recoverySessionEvents: const Stream<bool>.empty(),
          onRetry: () async {
            retryCalls += 1;
            return false;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('reset-password-callback-retry')));
    await tester.pumpAndSettle();

    expect(retryCalls, 1);
    expect(
      find.byKey(const Key('reset-password-callback-failed')),
      findsOneWidget,
    );
  });
}
