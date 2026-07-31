import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/auth/account_gateway_page.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_top_bar.dart';
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
    addTearDown(database.close);
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
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('Email sign-in'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.ancestor(
              of: find.textContaining('Email sign-in'),
              matching: find.byType(OutlinedButton),
            ),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('gateway-continue-locally')));
    await tester.pumpAndSettle();
    expect(find.text('ONBOARDING'), findsOneWidget);
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
