import 'package:body_intelligence_log/app/services/app_switcher_privacy_shield.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('long background requests startup for an authenticated route', () {
    final resumedAt = DateTime(2026, 9, 9, 10, 30);
    expect(
      shouldReturnToStartupAfterBackground(
        backgroundedAt: DateTime(2026, 9, 9, 10),
        resumedAt: resumedAt,
        currentPath: '/dashboard',
      ),
      isTrue,
    );
    expect(
      shouldReturnToStartupAfterBackground(
        backgroundedAt: DateTime(2026, 9, 9, 10, 1),
        resumedAt: resumedAt,
        currentPath: '/dashboard',
      ),
      isFalse,
    );
  });

  test('startup and authentication routes are never interrupted', () {
    final backgroundedAt = DateTime(2026, 9, 9, 10);
    final resumedAt = DateTime(2026, 9, 9, 11);
    for (final path in <String>[
      '/startup',
      '/login',
      '/reviewer-login',
      '/auth-callback',
      '/reset-password',
      '/auth/return',
    ]) {
      expect(
        shouldReturnToStartupAfterBackground(
          backgroundedAt: backgroundedAt,
          resumedAt: resumedAt,
          currentPath: path,
        ),
        isFalse,
        reason: path,
      );
    }
  });

  testWidgets('privacy shield requests one startup navigation on re-entry', (
    tester,
  ) async {
    var navigations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AppSwitcherPrivacyShield(
          currentPath: () => '/dashboard',
          onLongBackgroundResume: () => navigations++,
          resumeStartupThreshold: Duration.zero,
          child: const Text('dashboard'),
        ),
      ),
    );
    final observer =
        tester.state(find.byType(AppSwitcherPrivacyShield))
            as WidgetsBindingObserver;
    observer.didChangeAppLifecycleState(AppLifecycleState.paused);
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(navigations, 1);

    // Repeated resume notifications without a new background must not loop.
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(navigations, 1);
  });
}
