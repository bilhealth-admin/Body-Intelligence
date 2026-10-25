import 'package:body_intelligence_log/app/router/bil_safe_return_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('BIL-05 warm Goals Back respects a pending save veto', (
    tester,
  ) async {
    final router = await _mount(tester, '/dashboard');
    await tester.tap(find.byKey(const Key('fixture-enter-goals')));
    await tester.pumpAndSettle();
    expect(router.canPop(), isTrue);
    expect(find.byKey(const Key('fixture-goals-editor')), findsOneWidget);

    await tester.tap(find.byKey(const Key('bil-safe-return')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fixture-goals-editor')), findsOneWidget);
    expect(find.byKey(const Key('fixture-enter-goals')), findsNothing);

    await tester.tap(find.byKey(const Key('fixture-save-finished')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bil-safe-return')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fixture-enter-goals')), findsOneWidget);
    expect(find.byKey(const Key('fixture-goals-editor')), findsNothing);
    expect(router.canPop(), isFalse);
  });

  testWidgets('BIL-20 cold Goals cannot bypass an unsaved route guard', (
    tester,
  ) async {
    final router = await _mount(tester, '/goals');
    expect(router.canPop(), isFalse);
    await tester.tap(find.byKey(const Key('bil-safe-return')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/goals');
    expect(find.byKey(const Key('fixture-goals-editor')), findsOneWidget);

    await tester.tap(find.byKey(const Key('fixture-save-finished')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bil-safe-return')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/dashboard');
    expect(find.byKey(const Key('fixture-enter-goals')), findsOneWidget);
  });
}

Future<GoRouter> _mount(WidgetTester tester, String initialLocation) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => Scaffold(
          body: Center(
            child: FilledButton(
              key: const Key('fixture-enter-goals'),
              onPressed: () => context.push('/goals'),
              child: const Text('Open goals'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/goals',
        builder: (context, state) => const _GuardedGoals(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

class _GuardedGoals extends StatefulWidget {
  const _GuardedGoals();

  @override
  State<_GuardedGoals> createState() => _GuardedGoalsState();
}

class _GuardedGoalsState extends State<_GuardedGoals> {
  bool _saved = false;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _saved,
    child: Scaffold(
      appBar: AppBar(
        leading: const BilSafeReturnButton(fallbackLocation: '/dashboard'),
        title: const Text('Goals editor'),
      ),
      body: Center(
        child: FilledButton(
          key: const Key('fixture-save-finished'),
          onPressed: () => setState(() => _saved = true),
          child: const Text('Finish save'),
        ),
      ),
      key: const Key('fixture-goals-editor'),
    ),
  );
}
