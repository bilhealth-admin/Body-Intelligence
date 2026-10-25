import 'package:body_intelligence_log/app/router/bil_safe_return_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('LTR warm Goals Back preserves the caller after rapid taps', (
    tester,
  ) async {
    final router = await _pumpRoutes(tester, initialLocation: '/dashboard');
    await tester.tap(find.byKey(const Key('fixture-open-goals')));
    await tester.pumpAndSettle();
    expect(router.canPop(), isTrue);
    final back = tester.widget<BackButton>(
      find.byKey(const Key('bil-safe-return')),
    );
    back.onPressed!();
    back.onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('Open goals'), findsOneWidget);
    expect(find.text('Goals content'), findsNothing);
    expect(router.canPop(), isFalse);
  });

  testWidgets('LTR cold Goals Back returns to a fixed safe destination', (
    tester,
  ) async {
    final router = await _pumpRoutes(tester, initialLocation: '/goals');
    expect(find.text('Goals content'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bil-safe-return')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/dashboard');
    expect(find.text('Open goals'), findsOneWidget);
    expect(find.text('Goals content'), findsNothing);
  });

  testWidgets('RTL cold Goals rejects an untrusted return query', (
    tester,
  ) async {
    final router = await _pumpRoutes(
      tester,
      initialLocation: '/goals?next=https%3A%2F%2Foutside.example%2Fpath',
      locale: const Locale('ar'),
    );
    expect(
      Directionality.of(tester.element(find.byType(BilSafeReturnButton))),
      TextDirection.rtl,
    );
    await tester.tap(find.byKey(const Key('bil-safe-return')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/dashboard');
    expect(find.text('Open goals'), findsOneWidget);
    expect(find.text('Goals content'), findsNothing);
  });
}

Future<GoRouter> _pumpRoutes(
  WidgetTester tester, {
  required String initialLocation,
  Locale locale = const Locale('en'),
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Dashboard fixture')),
          body: Center(
            child: FilledButton(
              key: const Key('fixture-open-goals'),
              onPressed: () => context.push('/goals'),
              child: const Text('Open goals'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/goals',
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            leading: const BilSafeReturnButton(
              fallbackLocation: '/dashboard',
            ),
            title: const Text('Goals fixture'),
          ),
          body: const Center(child: Text('Goals content')),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      locale: locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
    ),
  );
  await tester.pumpAndSettle();
  return router;
}
