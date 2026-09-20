import 'package:body_intelligence_log/features/auth/auth_callback_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Try again invokes the failed OAuth exchange callback', (
    tester,
  ) async {
    var retryCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthCallbackPage(
          initiallyFailed: true,
          onRetry: () async {
            retryCalls += 1;
            return false;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('auth-callback-retry')));
    await tester.pumpAndSettle();

    expect(retryCalls, 1);
    expect(find.byKey(const Key('auth-callback-retry')), findsOneWidget);
  });
}
