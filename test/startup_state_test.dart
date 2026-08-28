import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/startup/startup_page.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('startup failure is safe, localized, and retryable', (
    tester,
  ) async {
    int profileBuildCount = 0;
    final userProfileOverride = userProfileProvider.overrideWith((ref) {
      profileBuildCount++;
      if (profileBuildCount == 1) {
        return Stream.error(StateError('private database detail'));
      } else {
        return Stream.value(null);
      }
    });

    await tester.pumpWidget(
      _app(
        overrides: [
          userProfileOverride,
          dailyCheckInDueProvider.overrideWith((ref) async => false),
          forceOnboardingProvider.overrideWith((ref) async => false),
          accountGatewayReviewedProvider.overrideWith((ref) async => false),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تعذّر فتح بياناتك المحلية'), findsOneWidget);
    expect(find.text('حاول مرة أخرى'), findsOneWidget);
    expect(find.textContaining('private database detail'), findsNothing);
    expect(find.byIcon(Icons.refresh), findsOneWidget);

    // Tap retry and verify transition back to loading screen
    await tester.tap(find.text('حاول مرة أخرى'));
    await tester.pump();

    // Verify error message is replaced by loading screen
    expect(find.text('تعذّر فتح بياناتك المحلية'), findsNothing);
    expect(find.bySemanticsLabel('BODY INTELLIGENCE LOG'), findsOneWidget);

    // Let the second stream load successfully and redirect to the gateway.
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();
    expect(profileBuildCount, 2);
    expect(find.text('Account Gateway Page'), findsOneWidget);
  });

  testWidgets('Arabic startup exposes locale-neutral brand semantics', (
    tester,
  ) async {
    final pending = Completer<bool>();
    await tester.pumpWidget(
      _app(
        overrides: [
          userProfileProvider.overrideWith((ref) => const Stream.empty()),
          dailyCheckInDueProvider.overrideWith((ref) => pending.future),
          forceOnboardingProvider.overrideWith((ref) async => false),
          accountGatewayReviewedProvider.overrideWith((ref) async => false),
        ],
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('BODY INTELLIGENCE LOG'), findsOneWidget);
  });

  testWidgets('reduced motion keeps the static identity without a player', (
    tester,
  ) async {
    final pending = Completer<bool>();
    await tester.pumpWidget(
      _app(
        overrides: [
          userProfileProvider.overrideWith((ref) => const Stream.empty()),
          dailyCheckInDueProvider.overrideWith((ref) => pending.future),
          forceOnboardingProvider.overrideWith((ref) async => false),
          accountGatewayReviewedProvider.overrideWith((ref) async => false),
        ],
        disableAnimations: true,
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('premium-splash-wordmark')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('premium-splash-video')), findsNothing);
    expect(
      find.byKey(const ValueKey('premium-splash-progress')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('premium-splash-spinner')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('startup success redirects to dashboard', (tester) async {
    await tester.pumpWidget(
      _app(
        overrides: [
          userProfileProvider.overrideWith(
            (ref) => Stream.value(
              UserProfileData(
                id: 1,
                uuid: '123',
                age: 30,
                gender: 'male',
                height: 175,
                currentWeight: 75,
                targetWeight: 70,
                activityLevel: 'moderate',
                exercises: false,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                revision: 1,
                syncStatus: 'local',
              ),
            ),
          ),
          dailyCheckInDueProvider.overrideWith((ref) async => false),
          forceOnboardingProvider.overrideWith((ref) async => false),
          accountGatewayReviewedProvider.overrideWith((ref) async => true),
        ],
      ),
    );
    await tester.pump();
    // Even when every provider is already ready (and the video plugin is not
    // registered in this widget test), routing retains the complete 2.3 s
    // identity window and does not wait for a playback callback.
    await tester.pump(const Duration(milliseconds: 2299));
    expect(find.text('Dashboard Page'), findsNothing);
    expect(find.byType(StartupPage), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard Page'), findsOneWidget);
  });

  testWidgets('legacy profile under 18 returns to date-of-birth onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        overrides: [
          userProfileProvider.overrideWith(
            (ref) => Stream.value(
              UserProfileData(
                id: 2,
                uuid: 'under-18',
                age: 17,
                gender: 'female',
                height: 165,
                currentWeight: 65,
                targetWeight: 62,
                activityLevel: 'moderate',
                exercises: true,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                revision: 1,
                syncStatus: 'local',
              ),
            ),
          ),
          dailyCheckInDueProvider.overrideWith((ref) async => false),
          forceOnboardingProvider.overrideWith((ref) async => false),
          accountGatewayReviewedProvider.overrideWith((ref) async => true),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();

    expect(find.text('Onboarding Page'), findsOneWidget);
    expect(find.text('Dashboard Page'), findsNothing);
  });
}

Widget _app({required dynamic overrides, bool disableAnimations = false}) {
  final router = GoRouter(
    initialLocation: '/startup',
    routes: [
      GoRoute(
        path: '/startup',
        builder: (context, state) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: const StartupPage(),
        ),
      ),
      GoRoute(
        path: '/account-gateway',
        builder: (_, _) => const Scaffold(body: Text('Account Gateway Page')),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const Scaffold(body: Text('Onboarding Page')),
      ),
      GoRoute(
        path: '/daily-check-in',
        builder: (_, _) => const Scaffold(body: Text('Daily Check-in Page')),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const Scaffold(body: Text('Dashboard Page')),
      ),
    ],
  );

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      locale: const Locale('ar'),
      routerConfig: router,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
}
