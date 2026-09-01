import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/app/environment/app_environment.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/cloud_platform/providers/cloud_sync_providers.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_runtime_access_gate.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_runtime_preparation.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/local_data_account_boundary.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/startup/startup_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gotrue/gotrue.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets(
    'cloud profile restore success routes signed-in users to dashboard',
    (tester) async {
      const ownerId = 'owner-restored-dashboard';
      await _seedSignedInSession(ownerId);

      await tester.pumpWidget(
        _app(
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
      await tester.pumpAndSettle();
      expect(find.text('Dashboard Page'), findsOneWidget);
      expect(find.text('Onboarding Page'), findsNothing);
    },
  );

  testWidgets(
    'recover errors keep startup retryable and do not route to onboarding',
    (tester) async {
      const ownerId = 'owner-restored-network-error';
      await _seedSignedInSession(ownerId);

      await tester.pumpWidget(
        _app(
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
      await tester.pumpAndSettle();

      expect(find.text('تعذّر فتح بياناتك المحلية'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.text('Onboarding Page'), findsNothing);
    },
  );

  testWidgets('true new account without cloud restore routes to onboarding', (
    tester,
  ) async {
    const ownerId = 'owner-new-account';
    await _seedSignedInSession(ownerId);

    await tester.pumpWidget(
      _app(
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
    await tester.pumpAndSettle();

    expect(find.text('Onboarding Page'), findsOneWidget);
    expect(find.text('Dashboard Page'), findsNothing);
  });
}

Widget _app({required List<Override> overrides}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp.router(
    locale: const Locale('ar'),
    routerConfig: _router(),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  ),
);

GoRouter _router() => GoRouter(
  routes: [
    GoRoute(
      path: '/startup',
      builder: (context, state) =>
          const MediaQuery(data: MediaQueryData(), child: StartupPage()),
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

String _fakeJwt(String userId) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final header = base64Url
      .encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'))
      .replaceAll('=', '');
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'iss': 'test',
            'aud': 'authenticated',
            'sub': userId,
            'exp': now + 3600,
            'iat': now,
          }),
        ),
      )
      .replaceAll('=', '');
  return '$header.$payload.';
}

User _fakeUser(String id) => User(
  id: id,
  appMetadata: const {},
  userMetadata: null,
  aud: 'authenticated',
  createdAt: DateTime.now().toIso8601String(),
);

Future<void> _seedSignedInSession(String ownerId) async {
  if (!Supabase.instance.isInitialized) {
    await Supabase.initialize(
      url: AppEnvironment.supabaseUrl,
      anonKey: AppEnvironment.supabaseAnonKey,
    );
  }

  final session = Session(
    accessToken: _fakeJwt(ownerId),
    expiresIn: 3600,
    refreshToken: 'refresh-$ownerId',
    tokenType: 'bearer',
    user: _fakeUser(ownerId),
  );
  await Supabase.instance.client.auth.recoverSession(
    jsonEncode(session.toJson()),
  );
}
