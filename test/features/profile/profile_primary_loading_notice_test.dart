import 'package:body_intelligence_log/features/profile/profile_summary_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget notice({required bool failed, required VoidCallback onRetry}) {
    return MaterialApp(
      home: Scaffold(
        body: ProfilePrimaryLoadNotice(
          failed: failed,
          onRetry: onRetry,
          loadingText: 'Loading profile…',
          slowText: 'Loading is taking longer than expected.',
          errorText: 'Profile data could not be loaded.',
          retryText: 'Retry',
        ),
      ),
    );
  }

  testWidgets('slow profile stays visible and becomes retryable after 12s', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(notice(failed: false, onRetry: () => retries++));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.byKey(const ValueKey('bil-profile-primary-retry')),
      findsNothing,
    );

    await tester.pump(const Duration(seconds: 13));
    expect(
      find.text('Loading is taking longer than expected.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('bil-profile-primary-retry')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('bil-profile-primary-retry')));
    await tester.pump();
    expect(retries, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading is taking longer than expected.'), findsNothing);
  });

  testWidgets('primary failure is recoverable and retry clears the state', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(notice(failed: true, onRetry: () => retries++));
    expect(find.text('Profile data could not be loaded.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('bil-profile-primary-retry')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('bil-profile-primary-retry')));
    expect(retries, 1);
    await tester.pumpWidget(notice(failed: false, onRetry: () => retries++));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 13));
    expect(
      find.byKey(const ValueKey('bil-profile-primary-retry')),
      findsOneWidget,
    );
  });
}
