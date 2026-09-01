import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/cloud_platform/providers/cloud_sync_providers.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_runtime_access_gate.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_runtime_preparation.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/local_data_account_boundary.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/startup/startup_page.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets(
    'cloud profile restore success routes signed-in users to dashboard',
    (tester) async {
      const ownerId = 'owner-restored-dashboard';

      await tester.pumpWidget(
        _app(
          authClient: _FakeGoTrueClient(_session(ownerId)),
          overrides: [
            userProfileProvider.overrideWith((ref) => Stream.value(null)),
            dailyCheckInDueProvider.overrideWith((ref) async => false),
            forceOnboardingProvider.overrideWith((ref) async => false),
            accountGatewayReviewedProvider.overrideWith((ref) async => false),
            localDataAccountBindingProvider.overrideWith(
              (ref) => Future.value(_cleanBinding),
            ),
            startupCloudProfileRestoreProvider.overrideWith((ref, owner) async {
              expect(owner, ownerId);
              return true;
            }),
            cloudRuntimePreparationProvider.overrideWith(
              (ref) async => const CloudRuntimePreparation(
                disposition: CloudRuntimeAccessDisposition.unavailable,
              ),
            ),
          ],
        ),
      );

      await tester.pump(const Duration(milliseconds: 2300));
      await _pumpUntilVisible(tester, find.text('Dashboard Page'));
      expect(find.text('Dashboard Page'), findsOneWidget);
      expect(find.text('Onboarding Page'), findsNothing);
    },
  );

  testWidgets(
    'recover errors keep startup retryable and do not route to onboarding',
    (tester) async {
      const ownerId = 'owner-restored-network-error';

      await tester.pumpWidget(
        _app(
          authClient: _FakeGoTrueClient(_session(ownerId)),
          overrides: [
            userProfileProvider.overrideWith((ref) => Stream.value(null)),
            dailyCheckInDueProvider.overrideWith((ref) async => false),
            forceOnboardingProvider.overrideWith((ref) async => false),
            accountGatewayReviewedProvider.overrideWith((ref) async => false),
            localDataAccountBindingProvider.overrideWith(
              (ref) => Future.value(_cleanBinding),
            ),
            startupCloudProfileRestoreProvider.overrideWith((ref, owner) async {
              expect(owner, ownerId);
              throw const SocketException('network lost');
            }),
            cloudRuntimePreparationProvider.overrideWith(
              (ref) async => const CloudRuntimePreparation(
                disposition: CloudRuntimeAccessDisposition.unavailable,
              ),
            ),
          ],
        ),
      );

      await tester.pump(const Duration(milliseconds: 2300));
      await _pumpUntilVisible(tester, find.text('تعذّر فتح بياناتك المحلية'));

      expect(find.text('تعذّر فتح بياناتك المحلية'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.text('Onboarding Page'), findsNothing);
    },
  );

  testWidgets('true new account without cloud restore routes to onboarding', (
    tester,
  ) async {
    const ownerId = 'owner-new-account';

    await tester.pumpWidget(
      _app(
        authClient: _FakeGoTrueClient(_session(ownerId)),
        overrides: [
          userProfileProvider.overrideWith((ref) => Stream.value(null)),
          dailyCheckInDueProvider.overrideWith((ref) async => false),
          forceOnboardingProvider.overrideWith((ref) async => false),
          accountGatewayReviewedProvider.overrideWith((ref) async => false),
          localDataAccountBindingProvider.overrideWith(
            (ref) => Future.value(_cleanBinding),
          ),
          startupCloudProfileRestoreProvider.overrideWith((ref, owner) async {
            expect(owner, ownerId);
            return false;
          }),
          cloudRuntimePreparationProvider.overrideWith(
            (ref) async => const CloudRuntimePreparation(
              disposition: CloudRuntimeAccessDisposition.unavailable,
            ),
          ),
        ],
      ),
    );

    await tester.pump(const Duration(milliseconds: 2300));
    await _pumpUntilVisible(tester, find.text('Onboarding Page'));

    expect(find.text('Onboarding Page'), findsOneWidget);
    expect(find.text('Dashboard Page'), findsNothing);
  });
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 50,
}) async {
  for (var index = 0; index < maxPumps; index++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  final visibleText = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data)
      .whereType<String>()
      .toList(growable: false);
  throw TestFailure(
    'Expected widget did not appear within the bounded wait. '
    'Visible text: $visibleText',
  );
}

Widget _app({required dynamic overrides, required GoTrueClient authClient}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        locale: const Locale('ar'),
        routerConfig: _router(authClient),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );

GoRouter _router(GoTrueClient authClient) => GoRouter(
  routes: [
    GoRoute(
      path: '/startup',
      builder: (context, state) => MediaQuery(
        data: const MediaQueryData(),
        child: StartupPage(authClient: authClient),
      ),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (_, _) => const Scaffold(body: Text('Onboarding Page')),
    ),
    GoRoute(
      path: '/account-gateway',
      builder: (_, _) => const Scaffold(body: Text('Account Gateway Page')),
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
  initialLocation: '/startup',
);

final _cleanBinding = LocalDataAccountBinding(
  disposition: LocalDataAccountBindingDisposition.matchedExistingOwner,
  hasSubstantiveLocalData: false,
);

User _fakeUser(String id) => User(
  id: id,
  appMetadata: const {},
  userMetadata: null,
  aud: 'authenticated',
  createdAt: DateTime.now().toIso8601String(),
);

Session _session(String ownerId) => Session(
  accessToken: 'test-access-token',
  expiresIn: 3600,
  refreshToken: 'refresh-$ownerId',
  tokenType: 'bearer',
  user: _fakeUser(ownerId),
);

final class _FakeGoTrueClient extends Fake implements GoTrueClient {
  _FakeGoTrueClient(this.currentSession);

  @override
  final Session? currentSession;

  @override
  Stream<AuthState> get onAuthStateChange => const Stream<AuthState>.empty();
}
