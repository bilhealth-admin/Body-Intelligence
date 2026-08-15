import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/auth/account_gateway_page.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_top_bar.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('first-time gateway is honest and continues to onboarding', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final router = GoRouter(
      initialLocation: '/gateway',
      routes: [
        GoRoute(
          path: '/gateway',
          builder: (_, _) => const AccountGatewayPage(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const Scaffold(body: Text('ONBOARDING')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          validRecoverySnapshotProvider.overrideWith((_) async => false),
          userProfileProvider.overrideWith((_) => Stream.value(null)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(TextField), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('gateway-account-action')))
          .onPressed,
      isNull,
    );

    final continueLocally = find.byKey(const Key('gateway-continue-locally'));
    await tester.ensureVisible(continueLocally);
    await tester.pumpAndSettle();
    await tester.tap(continueLocally);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('ONBOARDING'), findsOneWidget);

    // Dispose Riverpod's database-backed streams before closing Drift so its
    // zero-duration stream-query cleanup timer is allowed to complete.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    router.dispose();
    await database.close();
    await tester.pump();
  });

  testWidgets('Dashboard greeting uses name and neutral fallback', (
    tester,
  ) async {
    Future<String> greeting(String? name) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardTopBar(
              arabic: false,
              displayName: name,
              onProfile: () {},
            ),
          ),
        ),
      );
      return tester
          .widget<Text>(find.byKey(const Key('dashboard-greeting')))
          .data!;
    }

    expect(await greeting('Kadem'), 'Welcome, Kadem');
    expect(await greeting(null), 'Welcome');
  });
}
